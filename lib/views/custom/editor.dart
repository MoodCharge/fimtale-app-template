import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:notustohtml/notustohtml.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:sp_util/sp_util.dart';
import 'package:toast/toast.dart';
import 'package:zefyr/zefyr.dart';

//编辑器。

class Editor extends StatefulWidget {
  final value;

  Editor({Key key, @required this.value}) : super(key: key);

  @override
  _EditorState createState() => new _EditorState(value);
}

class _EditorState extends State<Editor> {
  var value;
  String _type = "topic", _action = "new", _formHash = "", _pageTitle = "";
  int _mainID = 0, _relatedID = 0, _curIndex = 0;
  bool _isPrequelVerifying = false, //前作是否正在验证
      _isPrivate = false, //是否为私密博文
      _isPosting = false, //是否正在发表
      _draftLock = false; //草稿是否可用
  List<String> _tags = [];
  List _mainTags = [], _suggestedTags = [];
  Map<String, dynamic> _info = {}, _relatedInfo = {};
  RequestHandler _rq;
  Timer _rt;
  TextEditingController _tc = TextEditingController(), //标题
      _ic = TextEditingController(), //简介
      _oc = TextEditingController(), //原链接
      _rc = TextEditingController(), //前作 或 相关作品
      _cc = TextEditingController(); //新标签
  NotusHtmlCodec converter = NotusHtmlCodec();

  ZefyrController _controller;
  FocusNode _focusNode;

  _EditorState(value) {
    this.value = value;
    _type = value["Type"];
    _action = value["Action"];
    _mainID = value["MainID"];
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
    _focusNode = FocusNode();
    _rc.addListener(() {
      if (_rt != null) {
        _rt.cancel();
        _rt = null;
      }
      _rt = Timer(Duration(seconds: 1), () {
        int relatedTopic = int.parse(_rc.text);
        if (_relatedID != relatedTopic) {
          _relatedID = relatedTopic;
          _loadRelatedTopic();
        }
      });
    });
    _loadDocument();
  }

  @override
  void dispose() {
    if (_action == "new") _saveDraft();
    _tc.dispose();
    _ic.dispose();
    _rc.dispose();
    _cc.dispose();
    super.dispose();
  }

  //加载编辑相关信息（FormHash，文档等），初始化标签信息
  _loadDocument() async {
    var mainTagsRes =
        await _rq.request("/api/v1/json/getMainTags?interface=edit");

    if (mainTagsRes["Status"] == 1) {
      _mainTags = List.from(mainTagsRes["TagsArray"]);
      print(_mainTags);
    } else {
      print(mainTagsRes["ErrorMessage"]);
      Toast.show(
          FlutterI18n.translate(context, "tags_load_failed") +
              ":" +
              mainTagsRes["ErrorMessage"],
          context);
    }

    var tagsRes = await _rq.request("/api/v1/json/getTags");

    if (tagsRes["Status"] == 1) {
      _suggestedTags = List.from(tagsRes["TagsArray"]);
    } else {
      print(tagsRes["ErrorMessage"]);
      Toast.show(
          FlutterI18n.translate(context, "tags_load_failed") +
              ":" +
              tagsRes["ErrorMessage"],
          context);
    }

    Map<String, dynamic> params = {};
    if (_action == "edit") {
      params["id"] = _mainID.toString();
    } else if (_action == "new" && _type == "topic" && _mainID > 0) {
      params["storyid"] = _mainID.toString();
    }

    var result =
        await _rq.request("/api/v1/" + _action + "/" + _type, params: params);

    if (result["Status"] == 1) {
      _formHash = result["FormHash"];
      NotusDocument document = NotusDocument();

      switch (_action) {
        case "new":
          switch (_type) {
            case "topic":
              if (_mainID > 0) {
                _pageTitle = FlutterI18n.translate(context, "add_chapter_title",
                    translationParams: {"Title": result["Title"]});
              } else {
                _pageTitle =
                    _pageTitle + FlutterI18n.translate(context, "new_topic");
              }
              break;
            case "blog":
              _pageTitle =
                  _pageTitle + FlutterI18n.translate(context, "new_blogpost");
          }
          Map draft = jsonDecode(SpUtil.getString(
              "draft_" + _action + "_" + _type + "_" + _mainID.toString(),
              defValue: "{}"));
          if (draft.containsKey("Title")) _tc.text = draft["Title"];
          if (draft.containsKey("Content") && draft["Content"].length > 0)
            document =
                NotusDocument.fromDelta(converter.decode(draft["Content"]));
          if (draft.containsKey("Tags"))
            _addTags(List<String>.from(draft["Tags"]));
          break;
        case "edit":
          _pageTitle = FlutterI18n.translate(context, "edit_page_title",
              translationParams: {"Title": result["Title"]});
          _tc.text = result["Title"];
          if (result["Content"].length > 0) {
            print(result["Content"]);
            String content = result["Content"]
                .replaceAll(RegExp(r"<\/?(span)[^>]*>"), "")
                .replaceAll(RegExp(r"<(p|div)[^>]*>"), "")
                .replaceAll(RegExp(r"<\/(p|div)>"), "<br><br>");
            print(content);
            document = NotusDocument.fromDelta(converter.decode(content));
          }
          print(document.toJson());
          _addTags(List<String>.from(result["Tags"]));
          switch (_type) {
            case "topic":
              _ic.text = result["Intro"];
              _oc.text = result["OriginalLink"];
              if (result["Prequel"] > 0) {
                _rc.text = result["Prerquel"].toString();
                _relatedID = result["Prerquel"];
              }
              _isPrequelVerifying = result["PrequelVerifying"];
              break;
            case "blog":
              if (result["RelatedTopic"] > 0) {
                _rc.text = result["RelatedTopic"].toString();
                _relatedID = result["RelatedTopic"];
              }
              _isPrivate = result["IsPrivate"];
              break;
          }
      }

      if (!mounted) return;

      setState(() {
        _controller = ZefyrController(document);
      });
    } else {
      print(result["ErrorMessage"]);
      Toast.show(result["ErrorMessage"], context);
    }
  }

  //加载相关作品（如果相关作品/前作那一栏有被输入作品ID，把对应作品调出来）
  _loadRelatedTopic() async {
    if (_relatedID > 0) {
      var result = await _rq.request(
          "/api/v1/json/getTopicByID?TopicID=" + _relatedID.toString());

      if (result["Status"] == 1) {
        if (!mounted) return;

        setState(() {
          _relatedInfo = Map<String, dynamic>.from(result["Info"]);
          _relatedID = _relatedInfo["ID"];
          _rc.text = _relatedID.toString();
        });
      } else {
        print(result["ErrorMessage"]);
        Toast.show(result["ErrorMessage"], context);
      }
    } else {
      if (!mounted) return;

      setState(() {
        _relatedInfo = {};
        _rc.text = "";
      });
    }
  }

  //保存草稿
  _saveDraft() async {
    if (_draftLock) return;
    Map<String, dynamic> draft = {
      "Title": _tc.text,
      "Content": _controller != null
          ? converter.encode(_controller.document.toDelta())
          : "",
      "Tags": _tags
    };
    switch (_type) {
      case "topic":
        draft["Intro"] = _ic.text;
    }
    SpUtil.putString(
        "draft_" + _action + "_" + _type + "_" + _mainID.toString(),
        jsonEncode(draft));
  }

  //清除草稿
  _clearDraft() async {
    SpUtil.remove("draft_" + _action + "_" + _type + "_" + _mainID.toString());
  }

  //添加标签
  _addTag(String tag) {
    if (!_tags.contains(tag)) _tags.add(tag);
  }

  //添加一组标签
  _addTags(List<String> tags) {
    tags.forEach((element) {
      _addTag(element);
    });
  }

  //移除标签
  _removeTag(String tag) {
    if (_tags.contains(tag)) _tags.remove(tag);
  }

  //移除一组标签
  _removeTags(List<String> tags) {
    tags.forEach((element) {
      _removeTag(element);
    });
  }

  //发表
  _post() {
    String content = converter
        .encode(_controller.document.toDelta())
        .replaceAll(RegExp(r"(<br>){1,2}"), "</p><p>")
        .replaceAll(RegExp(r"<p>$"), "")
        .replaceAllMapped(RegExp(r"^([^<])"), (Match m) => "<p>${m[1]}")
        .replaceAllMapped(
            RegExp(r"<p><(h[123456]|p|div|blockquote|ul|ol|li|table)"),
            (Match m) => "<${m[1]}")
        .replaceAllMapped(
            RegExp(r"\/(h[123456]|p|div|blockquote|ul|ol|li|table)><\/p>"),
            (Match m) => "/${m[1]}>");
    Toast.show(FlutterI18n.translate(context, "posting"), context);
    Function onSubmit = () {
      if (!mounted) return;
      setState(() {
        _isPosting = true;
      });
    },
        openOnSuccess = (url) async {
      if (!mounted) return;
      setState(() {
        _isPosting = false;
        _draftLock = true;
      });
      await _clearDraft();
      _rq.launchURL(url, replaceCurrentPage: true);
    },
        popOnSuccess = (url) async {
      if (!mounted) return;
      setState(() {
        _isPosting = false;
        _draftLock = true;
      });
      await _clearDraft();
      Navigator.pop(context, url);
    },
        onError = (err) {
      print(err);
      setState(() {
        _isPosting = false;
      });
    };
    switch (_action) {
      case "new":
        switch (_type) {
          case "topic":
            _rq.uploadPost(
                "/new/topic",
                {
                  "FormHash": _formHash,
                  "Id": _mainID,
                  "Title": _tc.text,
                  "Content": content,
                  "Tag": jsonEncode(_tags),
                  "Intro": _ic.text,
                  "IntroImage": "",
                  "OriginalLink": _oc.text,
                  "Prequel": _rc.text
                },
                onSubmit: onSubmit,
                onSuccess: openOnSuccess,
                onError: onError);
            break;
          case "blog":
            _rq.uploadPost(
                "/new/blog",
                {
                  "FormHash": _formHash,
                  "Title": _tc.text,
                  "Content": content,
                  "Tag": jsonEncode(_tags),
                  "RelatedTopic": _rc.text,
                  "IsPrivate": _isPrivate
                },
                onSubmit: onSubmit,
                onSuccess: openOnSuccess,
                onError: onError);
        }
        break;
      case "edit":
        switch (_type) {
          case "topic":
            _rq.uploadPost(
                "/edit/topic",
                {
                  "FormHash": _formHash,
                  "Id": _mainID,
                  "Title": _tc.text,
                  "Content": content,
                  "Tag": jsonEncode(_tags),
                  "Intro": _ic.text,
                  "IntroImage": "",
                  "OriginalLink": _oc.text,
                  "Prequel": _rc.text
                },
                onSubmit: onSubmit,
                onSuccess: popOnSuccess,
                onError: onError);
            break;
          case "blog":
            _rq.uploadPost(
                "/edit/blog",
                {
                  "FormHash": _formHash,
                  "Id": _mainID,
                  "Title": _tc.text,
                  "Content": content,
                  "Tag": jsonEncode(_tags),
                  "RelatedTopic": _rc.text,
                  "IsPrivate": _isPrivate
                },
                onSubmit: onSubmit,
                onSuccess: popOnSuccess,
                onError: onError);
            break;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(12.0),
              child: TextField(
                controller: _tc,
                maxLines: 1,
                style: TextStyle(fontSize: 18.0),
                decoration: InputDecoration(
                    labelText: FlutterI18n.translate(context, "title")),
              ),
            ),
            Expanded(
              child: _controller != null
                  ? ZefyrScaffold(
                      child: ZefyrEditor(
                        padding: EdgeInsets.all(16),
                        controller: _controller,
                        focusNode: _focusNode,
                        imageDelegate: MyAppZefyrImageDelegate(_rq),
                      ),
                    )
                  : _rq.renderer.preloader(),
            ),
          ],
        ),
      )
    ]; //编辑器

    if (!(_type == "topic" &&
        ((_action == "new" && _mainID > 0) ||
            !_rq.renderer.extractFromTree(_info, ["IsChapter"], true))))
      pages.add(ListView(
        children: _showSecondPage(),
      )); //第二页。

    List<Widget> appBarActions = [];

    appBarActions.add(IconButton(
      icon: Icon(Icons.add),
      onPressed: () {
        showModalBottomSheet(
            context: context,
            builder: (context) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ListTile(
                      title:
                          Text(FlutterI18n.translate(context, "insert_emoji")),
                      onTap: () {
                        Navigator.pop(context);
                        _rq.renderer.emojiPicker().then((value) {
                          if (value != null)
                            _controller.document.insert(
                                _controller.selection.extent.offset, value);
                        });
                      },
                    ),
                    ListTile(
                      title:
                      Text(FlutterI18n.translate(context, "insert_login_shortcode")),
                      onTap: () {
                        _controller.document.insert(
                            _controller.selection.extent.offset, "[login][/login]");
                      },
                    ),
                    ListTile(
                      title:
                      Text(FlutterI18n.translate(context, "insert_collapse_shortcode")),
                      onTap: () {
                        _controller.document.insert(
                            _controller.selection.extent.offset, "[collapse][/collapse]");
                      },
                    ),
                    ListTile(
                      title:
                      Text(FlutterI18n.translate(context, "insert_markdown_shortcode")),
                      onTap: () {
                        _controller.document.insert(
                            _controller.selection.extent.offset, "[markdown][/markdown]");
                      },
                    ),
                    ListTile(
                      title:
                      Text(FlutterI18n.translate(context, "insert_spoiler_shortcode")),
                      onTap: () {
                        _controller.document.insert(
                            _controller.selection.extent.offset, "[spoiler][/spoiler]");
                      },
                    )
                  ],
                ),
              );
            });
      },
    ));

    appBarActions.add(IconButton(
      icon: Icon(_isPosting ? Icons.more_horiz : Icons.check),
      onPressed: () {
        if (!_isPosting) _post();
      },
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
        actions: appBarActions,
      ),
      body: PageView(
        children: pages,
        onPageChanged: (index) {
          setState(() {
            _curIndex = index;
          });
        },
      ),
    );
  }

  //显示第二页。
  List<Widget> _showSecondPage() {
    List<Widget> contentList = [];
    List<String> tagsSelected = [], tagsDisplayed = List<String>.from(_tags);
    if (_type == "topic") {
      contentList.add(Container(
        padding: EdgeInsets.all(12.0),
        child: TextField(
          controller: _ic,
          maxLines: 3,
          style: TextStyle(fontSize: 18.0),
          decoration: InputDecoration(
              labelText: FlutterI18n.translate(context, "introduction")),
        ),
      ));

      contentList.add(Container(
        padding: EdgeInsets.all(12.0),
        child: TextField(
          controller: _oc,
          maxLines: 1,
          style: TextStyle(fontSize: 18.0),
          decoration: InputDecoration(
              labelText: FlutterI18n.translate(context, "original_link")),
        ),
      ));

      print(_tags);

      _mainTags.forEach((element) {
        switch (element["Type"]) {
          case "single":
            List<DropdownMenuItem> tagMenu = [];
            String currentTag;
            element["Tags"].forEach((e) {
              if (_tags.contains(e)) {
                currentTag = e;
                tagsSelected.add(e);
              }
              tagMenu.add(DropdownMenuItem(
                child: new Text(e),
                value: e,
              ));
            });
            contentList.add(ListTile(
              title: Text(element["Name"]),
              trailing: DropdownButton(
                items: tagMenu,
                hint: new Text(FlutterI18n.translate(context, "please_select")),
                value: currentTag,
                onChanged: (tag) {
                  if (!mounted) return;
                  setState(() {
                    _removeTags(List<String>.from(element["Tags"]));
                    _addTag(tag);
                  });
                },
              ),
            ));
            break;
          case "multiple":
            List<Widget> selections = [];
            element["Tags"].forEach((e) {
              selections.add(GestureDetector(
                child: Chip(
                  label: Text(e),
                  avatar: Checkbox(
                    value: _tags.contains(e),
                  ),
                  backgroundColor: Colors.transparent,
                ),
                onTap: () {
                  if (!mounted) return;
                  setState(() {
                    if (_tags.contains(e))
                      _removeTag(e);
                    else
                      _addTag(e);
                  });
                },
              ));
              if (_tags.contains(e)) tagsSelected.add(e);
            });
            contentList.add(ListTile(
              title: Text(element["Name"]),
              subtitle: Wrap(
                spacing: 3,
                children: selections,
              ),
            ));
            break;
        }
      });

      tagsSelected.forEach((element) {
        tagsDisplayed.remove(element);
      });
    }

    List<Widget> tagChips = [];

    tagsDisplayed.forEach((element) {
      tagChips.add(Chip(
        label: Text(element),
        deleteIcon: Icon(Icons.close),
        onDeleted: () {
          if (!mounted) return;
          setState(() {
            _removeTag(element);
          });
        },
      ));
    });

    tagChips.add(TypeAheadField(
      textFieldConfiguration: TextFieldConfiguration(
          controller: _cc,
          autofocus: true,
          decoration: InputDecoration(
            hintText: FlutterI18n.translate(context, "add_tag"),
          ),
          onChanged: (text) {
            if (text.contains("\n")) {
              if (!mounted) return;
              setState(() {
                _addTag(text.replaceAll("\n", ""));
                _cc.text = "";
              });
            }
          },
          onEditingComplete: () {
            if (!mounted) return;
            setState(() {
              _addTag(_cc.text);
              _cc.text = "";
            });
          }),
      suggestionsCallback: (String query) {
        if (query.length != 0) {
          List<String> res = [], queryCharArr = query.split("");
          _suggestedTags.forEach((element) {
            res.add(element[0]);
          });
          res.sort((left, right) {
            int freqL = 0, freqR = 0;
            queryCharArr.forEach((element) {
              if (left.contains(element)) freqL++;
              if (right.contains(element)) freqR++;
            });
            return freqL - freqR;
          });
          return res;
        } else {
          return [];
        }
      },
      itemBuilder: (context, tag) {
        return ListTile(
          key: ObjectKey(tag),
          title: Text(tag),
        );
      },
      onSuggestionSelected: (suggestion) {
        if (!mounted) return;
        setState(() {
          _addTag(suggestion);
          _cc.text = "";
        });
      },
    ));

    contentList.add(ListTile(
      title: Text(FlutterI18n.translate(
          context, (_type == "topic" ? "characters" : "tags"))),
      subtitle: Wrap(
        spacing: 5,
        children: tagChips,
      ),
    )); //标签添加栏

    contentList.add(ListTile(
      title: TextField(
        controller: _rc,
        maxLines: 1,
        style: TextStyle(fontSize: 18.0),
        decoration: InputDecoration(
            labelText: FlutterI18n.translate(
                context, (_type == "topic" ? "prequel" : "related_topic"))),
      ),
      subtitle: _relatedInfo.isNotEmpty
          ? Card(
              margin: EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  (_relatedInfo.containsKey("Background") &&
                          _relatedInfo["Background"] != null)
                      ? Flexible(
                          child: Image.network(
                            _relatedInfo["Background"],
                            fit: BoxFit.cover,
                          ),
                          flex: 1,
                        )
                      : SizedBox(
                          width: 0,
                        ),
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(12),
                      child: ListTile(
                        title: Text(
                          _relatedInfo["Title"],
                          textScaleFactor: 1.1,
                        ),
                        subtitle: Text(_relatedInfo["UserName"]),
                      ),
                    ),
                    flex: 3,
                  )
                ],
              ),
            )
          : null,
    )); //相关作品/前作栏。

    if (_isPrequelVerifying)
      contentList.add(Container(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Text(
          FlutterI18n.translate(context, "prequel_verifying_please_wait"),
          style: TextStyle(color: Colors.red),
        ),
      )); //前作确认提示。

    if (_type == "blog") {
      contentList.add(CheckboxListTile(
        title: Text(FlutterI18n.translate(context, "set_blog_private")),
        value: _isPrivate,
        onChanged: (status) {
          if (!mounted) return;
          setState(() {
            _isPrivate = !_isPrivate;
          });
        },
      ));
    } //私密博文选项

    return contentList;
  }
}

//Editor使用的插件是Zefyr，这里是它的图片上传配置。
class MyAppZefyrImageDelegate implements ZefyrImageDelegate<ImageSource> {
  RequestHandler _rq;

  MyAppZefyrImageDelegate(requestHandler) {
    _rq = requestHandler;
  }

  @override
  Future<String> pickImage(ImageSource source) async {
    final file = await ImagePicker.pickImage(source: source);
    if (file == null) return null;
    return _rq.uploadImage2ImgBox(file);
  }

  @override
  Widget buildImage(BuildContext context, String url) {
    return Image.network(url);
  }

  @override
  ImageSource get cameraSource => ImageSource.camera;

  @override
  ImageSource get gallerySource => ImageSource.gallery;
}
