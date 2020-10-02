import 'dart:convert';
import 'dart:math';
import 'package:fimtale/elements/share_card.dart';
import 'package:fimtale/views/custom/editor.dart';
import 'package:fimtale/views/viewers/tag.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/gestures.dart';
import 'package:fimtale/elements/ftemoji.dart';
import 'package:fimtale/elements/spoiler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/viewers/image_viewer.dart';
import 'package:fimtale/views/viewers/topic_menu.dart';
import 'package:toast/toast.dart';
import 'package:snack/snack.dart';

import 'channel.dart';

//博文的界面和作品的界面原理大同小异。仅在这里做一些讲解，就不在博文页面做详细注释了。

class TopicView extends StatefulWidget {
  final value;

  //首先在构造函数中传入value参数（value参数是从其它的地方传进来的，目的是为了完成作品阅览界面的初始化。）
  //可以看见我在这里加了一个@required，这个符号代表在构造时必须得传入这个参数。它又包裹在大括号中，因此传入参数时应当是TopicView(value: ...,)的形式。
  TopicView({Key key, @required this.value}) : super(key: key);

  //然后往State里面也传入这个参数。
  @override
  _TopicViewState createState() => new _TopicViewState(value);
}

class _TopicViewState extends State<TopicView> {
  var value;
  String _pageTitle = "", //页面的标题
      _formHash = ""; //这个FormHash是发表评论所需要的东西之一，对每个用户都不一样。
  List _menu = [], //目录
      _imageUrls = [], //图片链接，这个到时候传给ImageViewer进行大图预览。
      _from = [], //如果是多分支模式，这个存入走过的章节链接，供回溯所用。
      _sequels = [], //续作列表。
      _channelsInvolved = [], //收藏这部作品的频道。
      _recommendTopics = [], //推荐的作品。
      _relatedChannels = []; //与这部作品相关的频道（与上面的那个不一样，相当于网站的“发现频道”）。
  Map<String, dynamic> _topicInfo = {}, //该作品相关信息。
      _parent = {}, //该作品前言相关信息（这个也很重要）。
      _author = {}, //作者相关信息。
      _prequel = {}, //前作相关信息。
      _preloadInfo = {}; //预加载相关信息。详情请看下面有个预加载的函数。
  bool _isLoading = false, //是否在加载作品信息。
      _isRecommendLoading = false, //是否在加载推荐作品信息。
      _isRecommendLoaded = false, //是否已加载推荐作品信息。
      _isRefreshing = false, //是否在刷新。
      _isJumping = false, //是否在跳转。（有时候恢复阅读进度需要跳转，这个可以防止在跳转的时候继续发送跳转指令）
      _isCustomBranch = false, //是否为自定义分支模式。
      _commentSortbyStarHonor = false, //评论是否按照小黄星排序。
      _commentOrderDesc = false, //评论是否降序排序。
      _commentFirstPageOnly = false, //是否只显示本章的评论。
      _isCommentShown = false; //是否有特殊的评论需要高亮。
  int _topicID = 0, //文章的ID。
      _prevID = 0, //前一章的ID。
      _nextID = 0, //后一章的ID。
      _commentID = 0, //需要跳转到的评论ID。
      _curIndex = 1, //当前页面的索引，通过这个判断用户是左滑还是右滑，进而决定跳转到哪。
      _bottomIndex = 0, //底部的索引，0为评论页面，1为发现页面。
      _bgColor = 0x00ffffff; //阅读界面背景色。
  double _fontSize = 18, //阅读字体大小。
      _progress = 0, //阅读进度。
      _top = 0,
      _bottom = 0; //这两个参数与作品本身有关，一个是作品头部所在的位置。
  BuildContext _scaffordContext; //这个东西是用来展示SnackBar的。一般很难用得上。
  RequestHandler _rq; //RequestHandler，老朋友了。
  PageController _pc; //页面控制器。
  ScrollController _sc = new ScrollController(); //滚动控制器，用于监视进度和加载评论。
  GlobalKey _passage = GlobalKey(); //给作品内容部分一个key。
  Map<int, GlobalKey> _comments = {}; //所有评论的key。

  _TopicViewState(value) {
    this.value = value; //将传入的value参数赋值给这个类的value变量，方便之后的读取操作。
    this._topicID = this.value["TopicID"]; //读取作品ID。
    if (this.value.containsKey("PreloadInfo"))
      this._preloadInfo = this.value["PreloadInfo"]; //读取预加载信息。
    if (this.value.containsKey("From"))
      this._from = this.value["From"]; //读取回溯信息。
    if (value.containsKey("CommentID"))
      _commentID = value["CommentID"]; //读取需要跳转到的评论ID。
    _pc = new PageController(
      initialPage: _curIndex,
      viewportFraction: 1,
      keepPage: true,
    ); //初始化PageController。
  }

  //initState函数，当页面被初始化时调用的函数，在这里可以放入需要context的变量初始化。
  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context,
        listNames: ["Comments"]); //由于RequestHandler需要context作为参数，因此在这里进行初始化。
    _fontSize = _rq.provider
        .getUserPreference("ReadingFontSize", defValue: 18.0); //初始化字体大小。
    _bgColor = _rq.provider
        .getUserPreference("BackgroundColor", defValue: 0x00ffffff); //初始化背景颜色。
    _sc.addListener(() {
      RenderBox renderBox = _passage.currentContext.findRenderObject();
      double curr = _sc.position.pixels,
          top = renderBox.localToGlobal(Offset.zero).dy,
          bottom =
              renderBox.localToGlobal(Offset(0.0, renderBox.size.height)).dy,
          screenHeight = MediaQuery.of(context).size.height;
      //顶端：curr + top；底端：curr + bottom - screenHeight。
      _top = (_top + 0.5 * (curr + top)) / 1.5;
      _bottom = (_bottom + 0.5 * (curr + bottom - screenHeight)) / 1.5;
      if (bottom - screenHeight - top == 0) {
        _progress = 1;
      } else {
        _progress = (100 - top) / (bottom - screenHeight - top);
      }
      //以上是计算进度的函数，意思大约是看看自己滚动到了页面的哪里，再与作品的开头和结尾进行对比，最后确定进度。
      //其中这个计算函数包裹在了listener之中，当页面滚动时，这个函数就执行一次。因此最好别在这里放入太多的setState，以防卡爆。

      if (_bottomIndex == 0 && curr >= _sc.position.maxScrollExtent - 400) {
        _getComments(0);
      } //如果划到了最底部（现在的位置距离最下面只有不到400的距离），尝试着加载评论。
    });
    _getTopic(_commentID); //首先加载作品，将需要加载的评论ID也放进去。
  }

  //dispose函数，当页面被销毁时执行。因为有一部分controller是占用内存的，因此为了释放内存应当执行它的dispose函数；同时，在dispose部分也可以检查并使用cancel函数关闭Timer。
  @override
  void dispose() {
    if (_progress > 0) {
      Map<String, dynamic> params = {};
      params["PostID"] =
          _rq.renderer.extractFromTree(_topicInfo, ["PostID"], 0).toString();
      params["Progress"] = _progress.toString();
      if (_from.isNotEmpty) {
        params["PreviousRoute"] = _from.join(",");
      }
      _rq.request("/save-reading-progress", params: params);
      print("阅读进度已上传");
    } //读取并上传阅读进度。
    _pc.dispose(); //销毁PageController。
    _sc.dispose(); //销毁ScrollController。
    super.dispose();
  }

  //刷新页面相关内容，方法为重置页面上大多数变量，同时通过调用获取函数重新加载。
  Future<Null> _refresh() async {
    _rq.getListNames().forEach((element) {
      _rq.clearOrCreateList(element);
    });
    _topicInfo = {};
    _author = {};
    _menu.clear();
    _prequel = {};
    _sequels.clear();
    _channelsInvolved.clear();
    _preloadInfo = {};
    _getTopic(_commentID);
    _isRecommendLoaded = false;
    if (_bottomIndex == 1) _getRecommend();
  }

  //获取作品。commentID用来跳转。
  _getTopic(int commentID) async {
    if (_isLoading || !mounted) return;
    setState(() {
      _isLoading = true;
      if (commentID <= 0) _rq.setIsLoading("Comments", true);
    }); //先设置整个界面为加载中的状态。
    var result;
    bool preloaded = false;
    if (_preloadInfo.containsKey(_topicID.toString())) {
      preloaded = true;
      result = jsonDecode(_preloadInfo[_topicID.toString()]);
    } else {
      Map<String, String> params = {};
      if (_from.length > 0) params["from"] = _from.join(",");
      result = await this
          ._rq
          .request("/api/v1/t/" + _topicID.toString(), params: params);
    } //加载整个页面的信息。如果之前有预加载过，就调用预加载的内容；如果之前没有预加载过，那就从网站上获取新的内容。

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _isLoading = false;
        _topicInfo = result["TopicInfo"];
        _parent = result["ParentInfo"];
        _author = result["AuthorInfo"];
        _pageTitle = result["TopicInfo"]["Title"];
        _menu = result["Menu"];
        _prequel = result["PrequelInfo"] ?? Map<String, dynamic>();
        ["SequelInfo", "ChannelsInvolved"].forEach((element) {
          if (result[element] != null &&
              result[element] is List &&
              result[element].length > 0) {
            result[element].forEach((element2) {
              switch (element) {
                case "SequelInfo":
                  _sequels.add(Map<String, dynamic>.from(element2));
                  break;
                case "ChannelsInvolved":
                  _channelsInvolved.add(Map<String, dynamic>.from(element2));
                  break;
              }
            });
          }
        });
        if (result["CurrentUser"].containsKey("FormHash"))
          _formHash = result["CurrentUser"]["FormHash"];
        _isCustomBranch = _parent.containsKey("IsCustomBranch") &&
            _parent[
                "IsCustomBranch"]; //以上部分都在解析从网站上获取的内容。将获取下来的json解析并赋值给不同的部分。
        if (_isCustomBranch) _from.add(_topicID);
        for (int i = 0; i < _menu.length; i++) {
          if (_menu[i]["ID"] == _topicID) {
            if (i > 0) _prevID = _menu[i - 1]["ID"];
            if (i < _menu.length - 1 && !_isCustomBranch)
              _nextID = _menu[i + 1]["ID"];
          }
        } //在目录中搜索前一章与后一章的ID，并分别赋值。
        if (commentID <= 0) {
          _rq.setListByName("Comments", result["CommentsArray"]);
          _rq.setCurPage("Comments", result["Page"]);
          _rq.setTotalPage("Comments", result["TotalPage"]);
          _rq.setIsLoading("Comments", false);
        } else {
          _getComments(commentID);
        } //决定Comments要从哪里显示。如果并不需要高亮评论，就默认显示加载作品时自带的前20个评论；否则再次从服务器中获取。
        String _prevInfo = "", _nextInfo = "";
        if (_prevID > 0 && _preloadInfo.containsKey(_prevID.toString()))
          _prevInfo = _preloadInfo[_prevID.toString()];
        if (_preloadInfo.containsKey(_nextID.toString()))
          _nextInfo = _preloadInfo[_nextID.toString()];
        _preloadInfo = {};
        _preloadInfo[_topicID.toString()] = jsonEncode(result);
        if (_prevID > 0) {
          if (_prevInfo.length > 0) {
            _preloadInfo[_prevID.toString()] = _prevInfo;
          } else {
            _preloadTopic(_prevID);
          }
        }
        if (_nextID > 0) {
          if (_nextInfo.length > 0) {
            _preloadInfo[_nextID.toString()] = _nextInfo;
          } else {
            _preloadTopic(_nextID);
          }
        } //更新预加载的内容。如果有前一章与后一章，那么添加到预加载内容中；否则重新请求预加载内容。
      });

      double progress = double.parse(_rq.renderer
          .extractFromTree(_topicInfo, ["ReadingProgress"], 0)
          .toString());
      if (progress > 0 && progress <= 1) {
        SnackBar(
          content: new Text(
              FlutterI18n.translate(context, "reading_progress_found")),
          action: new SnackBarAction(
              label: FlutterI18n.translate(context, "tap_to_resume"),
              onPressed: () {
                _setProgress(progress);
              }),
        ).show(_scaffordContext);
      } //如果有阅读记录，则显示SnackBar提示阅读记录。
    } else {
      _isLoading = false;
      if (commentID <= 0) _rq.setIsLoading("Comments", false);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
      print(result["ErrorMessage"]); //加载失败时，通过Toast提示加载失败的原因。
    }
  }

  //通过作品ID预加载作品。
  _preloadTopic(int topicID) async {
    var result = await this._rq.request("/api/v1/t/" + topicID.toString());
    if (result["Status"] == 1) {
      _preloadInfo[topicID.toString()] = jsonEncode(result);
      print("作品" + topicID.toString() + "已预加载。");
    }
  }

  //获取推荐信息（推荐作品与相关频道）。
  _getRecommend() async {
    if (_isRecommendLoading) return;
    setState(() {
      _recommendTopics.clear();
      _relatedChannels.clear();
      _isRecommendLoading = true;
    });

    var result = await this._rq.request(
      "/api/v1/json/completeTopicPage",
      params: {"ID": _topicID.toString()},
    );

    if (!mounted) return;

    if (result["Status"] == 1) {
      _relatedChannels = result["RelatedChannelsArray"];
      _recommendTopics = result["RecommendTopicsArray"];
    }

    setState(() {
      _isRecommendLoading = false;
      _isRecommendLoaded = true;
    });
  }

  //跳转到某个作品中（会关闭当前作品的页面）。
  _goToTopic(int topicID) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
      var v = {"TopicID": topicID, "PreloadInfo": _preloadInfo};
      if (_from.length > 0) v["From"] = _from;
      return TopicView(
        value: v,
      );
    }));
  }

  //获取评论。
  _getComments(int commentID) {
    Map<String, dynamic> params = {};
    if (_commentFirstPageOnly) params["firstpageonly"] = "1";
    if (_commentOrderDesc) params["order"] = "d";
    if (_commentSortbyStarHonor) {
      params["sortby"] = "starhonor";
      params["order"] = "d";
    }
    if (commentID > 0) {
      params["comment"] = commentID.toString();
      setState(() {
        _commentID = commentID;
        _rq.clearOrCreateList("Comments");
      });
    } //配置评论的获取参数。
    _rq.updateListByName(
        "/api/v1/t/" + _topicID.toString(),
        "Comments",
        (data) {
          return {
            "List": data["CommentsArray"],
            "CurPage": data["Page"],
            "TotalPage": data["TotalPage"]
          };
        },
        params: params,
        beforeRequest: () {
          setState(() {});
        },
        afterUpdate: (list) {
          setState(() {});
        },
        onError: (err) {
          Toast.show(err, context,
              duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
        }); //通过参数来获取评论。
  }

  //从目录中选择一部作品，并跳转。
  _selectFromMenu() async {
    var data =
        await Navigator.push(context, MaterialPageRoute(builder: (context) {
      return TopicMenu(
        value: {"CurID": _topicID, "Menu": _menu},
      );
    }));
    if (data != null && data is int && data != _topicID) _goToTopic(data);
  }

  //打开图片预览器，传入的index参数为点击的图像位置。
  _openImageViewer(int index) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return ImageViewer(
        value: {"UrlList": _imageUrls, "CurIndex": index},
      );
    }));
  }

  //传入progress，跳转到对应的位置。
  _setProgress(double progress) {
    if (_isJumping) return;
    _isJumping = true;
    _progress = progress;
    RenderBox renderBox = _passage.currentContext.findRenderObject();
    double curr = _sc.position.pixels,
        top = renderBox.localToGlobal(Offset.zero).dy,
        bottom = renderBox.localToGlobal(Offset(0.0, renderBox.size.height)).dy,
        screenHeight = MediaQuery.of(context).size.height;
    _top = (_top + 0.5 * (curr + top)) / 1.5;
    _bottom = (_bottom + 0.5 * (curr + bottom - screenHeight)) / 1.5;
    double position = _top + progress * (_bottom - _top) - 100;
    if (position >= _top - 100 && position <= _bottom) _sc.jumpTo(position);
    _isJumping = false;
  }

  //设置字体大小。
  _setFontSize(double size) {
    _fontSize = size;
    _rq.provider.setUserPreference("ReadingFontSize", size);
    _rq.provider.saveUserPreference();
  }

  //获取背景颜色。
  Color _getBackground() {
    Color bgColor = Color(_bgColor);
    if (bgColor.alpha < 255 ||
        _rq.provider.getUserPreference("DarkMode", defValue: false)) {
      return Theme.of(context).scaffoldBackgroundColor;
    } else {
      return bgColor;
    }
  }

  //发表评论。
  _postComment({String initText}) {
    bool transfer = false;
    _rq.renderer.inputModal(
      draftKey: "comment_topic_" + _topicID.toString(),
      hint: FlutterI18n.translate(context, "post_comment") +
          "(" +
          FlutterI18n.translate(context, "use_markdown") +
          ")",
      text: initText,
      options: ["emoji", "image", "at", "spoiler"],
      checkBoxConfig: {
        "Label": FlutterI18n.translate(context, "transfer_to_updates"),
        "Value": transfer,
        "OnCheck": (isChecked) {
          transfer = isChecked;
        }
      },
    ).then((value) async {
      //首先先打开输入窗口，得到用户的输入值。
      if (value != null && value.length > 0) {
        _rq.uploadPost("/new/reply", {
          "FormHash": _formHash,
          "Id": _topicID,
          "Content": markdownToHtml(value),
          "IsForward": transfer
        }, onSubmit: () {
          Toast.show(FlutterI18n.translate(context, "posting"), context);
        }, onSuccess: (link) async {
          SpUtil.remove("draft_comment_topic_" + _topicID.toString());
          _rq.launchURL(link, returnWhenCommentIDFounds: true).then((value) {
            if (value != null) {
              Map<String, dynamic> res =
                  Map<String, dynamic>.from(jsonDecode(value));
              if (res["IsCommentFound"]) {
                if (res["Type"] == "topic" && res["MainID"] == _topicID) {
                  _isCommentShown = false;
                  _getComments(res["CommentID"]);
                } else {
                  _rq.launchURL(link);
                }
              }
            }
          });
        });
      }
    }); //如果值不为空，向服务器传值以发表。
  }

  //设置背景颜色。
  _setBackgroundColor(int color) {
    _bgColor = color;
    _rq.provider.setUserPreference("BackgroundColor", color);
    _rq.provider.saveUserPreference();
  }

  //build函数，每当状态改变时它就会被调用一次。需要根据页面的不同加载情况来决定加载build的哪一部分。
  @override
  Widget build(BuildContext context) {
    //首先获取到该名用户相对于作品所有的权限。
    List<String> allowedOptions = List<String>.from(
            _rq.renderer.extractFromTree(_topicInfo, ["AllowedOptions"], [])),
        parentAllowedOptions = List<String>.from(
            _rq.renderer.extractFromTree(_parent, ["AllowedOptions"], [])),
        authorAllowedOptions = List<String>.from(
            _rq.renderer.extractFromTree(_author, ["AllowedOptions"], []));

    //配置界面右上角操作（就是那个省略号）中所有的选项。
    List<PopupMenuItem<String>> actionMenu = [];
    if (allowedOptions.contains("edit")) //编辑作品。
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(
            context,
            "edit_" +
                (_topicInfo["ID"] == _parent["ID"]
                    ? "description"
                    : "this_chapter"))),
        value: "edit",
      ));
    if (allowedOptions.contains("add_chapter")) //添加章节。
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "add_chapter")),
        value: "add_chapter",
      ));
    if (allowedOptions.contains("delete")) //删除作品。
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(
            context,
            "delete_" +
                (_topicInfo["ID"] == _parent["ID"]
                    ? "all_book"
                    : "this_chapter"))),
        value: "delete",
      ));
    if (allowedOptions.contains("report")) //举报作品。
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "report")),
        value: "report",
      ));

    List<Widget> appBarActions = [],
        pageBody = []; //appBarActions是页面右上角的Actions栏所要展示的图标集合，而pageBody是页面主体。

    if (_menu.length > 1) //如果这部作品含有目录，那么在右上角加上目录按钮。
      appBarActions.add(IconButton(
          icon: Icon(Icons.import_contacts),
          onPressed: () {
            _selectFromMenu();
          }));

    if (actionMenu.length > 0) //如果之前那个actionMenu里面有东西，那么就显示这个省略号。
      appBarActions.add(PopupMenuButton(
        itemBuilder: (BuildContext context) => actionMenu,
        onSelected: (String action) {
          switch (action) {
            //这边用switch语句来判断选择的操作。
            case "edit":
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return Editor(
                  value: {
                    "Type": "topic",
                    "Action": "edit",
                    "MainID": _topicInfo["PostID"]
                  },
                );
              })).then((value) {
                if (value != null) _refresh();
              });
              break;
            case "add_chapter":
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return Editor(
                  value: {
                    "Type": "topic",
                    "Action": "new",
                    "MainID": _parent["ID"]
                  },
                );
              })).then((value) {
                if (value != null) {
                  _rq.clearOrCreateList("Comments");
                  _getTopic(_commentID);
                }
              });
              break;
            case "delete":
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                          FlutterI18n.translate(context, "confirm_deletion")),
                      actions: <Widget>[
                        FlatButton(
                          onPressed: () {
                            Navigator.of(context).pop("true");
                          },
                          child:
                              Text(FlutterI18n.translate(context, "confirm")),
                        ),
                        FlatButton(
                          onPressed: () {
                            Navigator.of(context).pop("false");
                          },
                          child: Text(FlutterI18n.translate(context, "quit")),
                        )
                      ],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                    );
                  }).then((value) {
                switch (value) {
                  case "true":
                    _rq.manage(_topicID, 1, "Delete", (message) {
                      Toast.show("successfully_deleted", context);
                      if (_topicID == _parent["ID"]) {
                        Navigator.pop(context);
                      } else {
                        _preloadInfo = {};
                        if (_nextID > 0) {
                          _goToTopic(_nextID);
                        } else {
                          _goToTopic(_prevID);
                        }
                      }
                    });
                    break;
                }
              });
              break;
            case "report":
              _rq.renderer.reportWindow("post", _topicInfo["PostID"]);
              break;
          }
        },
      ));

    //加载用户背景。
    String userBg = _rq.renderer.extractFromTree(_author, ["Background"], "");
    if (userBg.length == 0)
      userBg = "https://fimtale.com/static/img/userbg.jpg";
    pageBody.add(Container(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: 20.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Icon(
              _prevID > 0 ? Icons.arrow_back : Icons.close,
              size: 20.0,
              color: Colors.grey.withAlpha(127),
            ),
            Text(
              _prevID > 0
                  ? FlutterI18n.translate(
                      context, "swipe_right_to", translationParams: {
                      "Object": _isCustomBranch
                          ? FlutterI18n.translate(context, "trace_back")
                          : FlutterI18n.translate(context, "previous_chapter")
                    })
                  : FlutterI18n.translate(
                      context, "it_is_already", translationParams: {
                      "Object": FlutterI18n.translate(context, "the_top_one")
                    }),
              style: TextStyle(
                fontSize: 20.0,
                color: Colors.grey.withAlpha(127),
              ),
            )
          ],
        ),
      ),
    ));
    //前一页指示符。
    if (_isLoading) {
      pageBody.add(Center(
        child: _rq.renderer.preloader(),
      )); //如果信息正在加载中，那么显示加载中的那个圈圈。
    } else {
      //否则通过读取信息加载整个页面。以下就是一个通过读取获得的信息加载整个页面的过程。在这里它们加载的几乎都是组件，虽然代码看似比较长，但都是大同小异。
      int likes = _rq.renderer.extractFromTree(_topicInfo, ["Upvotes"], 0),
          dislikes = _rq.renderer.extractFromTree(_topicInfo, ["Downvotes"], 0);

      List<String> originalLinks = _rq.renderer
          .extractFromTree(_topicInfo, ["OriginalLink"], "")
          .split(" ");
      originalLinks.removeWhere((element) => element == "");
      List<TextSpan> originalLinkSpans = [];
      if (originalLinks.length > 0) {
        originalLinkSpans.add(TextSpan(
          text: FlutterI18n.translate(context, "original_link") + ":",
          style: TextStyle(
            color: Theme.of(context).disabledColor,
          ),
        ));
        int index = 0;
        originalLinks.forEach((element) {
          if (index > 0)
            originalLinkSpans.add(TextSpan(
              text: ",",
              style: TextStyle(
                color: Theme.of(context).disabledColor,
              ),
            ));
          originalLinkSpans.add(TextSpan(
            text: element,
            style: TextStyle(
              color: Colors.blue,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _rq.launchURL(element);
              },
          ));
          index++;
        });
      }
      //先初始化赞踩和源链接部分数据。

      List<Widget> secondInfoLine = [
        Chip(
          label: Text(_rq.renderer
              .extractFromTree(_topicInfo, ["Views"], 0)
              .toString()),
          labelStyle: TextStyle(
            color: Theme.of(context).disabledColor,
          ),
          avatar: Icon(
            Icons.visibility,
            color: Colors.teal,
          ),
          backgroundColor: _getBackground(),
        ),
        Chip(
          label: Text(_rq.renderer
              .extractFromTree(_topicInfo, ["Comments"], 0)
              .toString()),
          labelStyle: TextStyle(
            color: Theme.of(context).disabledColor,
          ),
          avatar: Icon(
            Icons.forum,
            color: Colors.deepPurple[400],
          ),
          backgroundColor: _getBackground(),
        )
      ];

      if (_topicInfo.containsKey("ID") &&
          _parent.containsKey("ID") &&
          _topicInfo["ID"] == _parent["ID"])
        secondInfoLine.addAll([
          Chip(
            label: Text(_rq.renderer
                .extractFromTree(_topicInfo, ["Followers"], 0)
                .toString()),
            labelStyle: TextStyle(
              color: Theme.of(context).disabledColor,
            ),
            avatar: Icon(
              Icons.collections_bookmark,
              color: Colors.lightBlue,
            ),
            backgroundColor: _getBackground(),
          ),
          Chip(
            label: Text(_rq.renderer
                .extractFromTree(_topicInfo, ["HighPraise"], 0)
                .toString()),
            labelStyle: TextStyle(
              color: Theme.of(context).disabledColor,
            ),
            avatar: Icon(
              Icons.star,
              color: Colors.orange,
            ),
            backgroundColor: _getBackground(),
          ),
          Chip(
            label: Text(_rq.renderer
                .extractFromTree(_topicInfo, ["Downloads"], 0)
                .toString()),
            labelStyle: TextStyle(
              color: Theme.of(context).disabledColor,
            ),
            avatar: Icon(
              Icons.file_download,
              color: Colors.green[600],
            ),
            backgroundColor: _getBackground(),
          ),
        ]);
      //这个是作品数据的第二行，有些数据（收藏量、下载量等）是只有前言页才有的，因此要与普通的数据隔开，通过一个条件判断是否加载。

      pageBody.add(CustomScrollView(
        controller: _sc,
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 150.0,
            floating: false,
            pinned: true,
            title: Text("${_pageTitle}"),
            actions: appBarActions,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.asset(
                    "assets/images/user_background.jpg",
                    fit: BoxFit.cover,
                  ),
                  (_author["Background"] != null &&
                          _author["Background"].length > 0)
                      ? Image.network(
                          _author["Background"],
                          fit: BoxFit.cover,
                        )
                      : SizedBox(
                          height: 0,
                        ),
                  Container(
                    color: Colors.black.withAlpha(127),
                  ),
                ],
              ),
            ),
          ), //这个是最上方的AppBar，显示的是作者的用户背景与之前加载的Actions。
          SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                ListTile(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return UserView(value: {
                        "UserName": _rq.renderer
                            .extractFromTree(_author, ["UserName"], "")
                      });
                    }));
                  },
                  leading: _rq.renderer.userAvatar(
                      _rq.renderer.extractFromTree(_author, ["ID"], 0)),
                  title: Text(
                    _rq.renderer.extractFromTree(_author, ["UserName"], ""),
                    textScaleFactor: 1.25,
                    maxLines: 1,
                  ),
                  subtitle: Text(
                    _rq.renderer.extractFromTree(_author, ["UserIntro"], ""),
                    maxLines: 1,
                  ),
                  trailing: authorAllowedOptions.contains("favorite")
                      ? IconButton(
                          icon: Icon(_author["IsFavorite"]
                              ? Icons.favorite
                              : Icons.favorite_border),
                          onPressed: () {
                            _rq.manage(
                                _rq.renderer
                                    .extractFromTree(_author, ["ID"], 0),
                                4,
                                "3", (res) {
                              setState(() {
                                if (_author["IsFavorite"])
                                  _author["Followers"]--;
                                else
                                  _author["Followers"]++;
                                _author["IsFavorite"] = !_author["IsFavorite"];
                              });
                            });
                          },
                        )
                      : null,
                ),
                //作者信息。
                Container(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: _prevID == 0
                      ? _rq.renderer.mainTagSet(
                          _rq.renderer
                              .extractFromTree(_topicInfo, ["Tags"], []),
                          _parent["IsDel"] > 0,
                          _parent["ExaminationStatus"])
                      : SizedBox(
                          height: 0,
                        ),
                ),
                //主标签组。
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _rq.renderer.extractFromTree(_parent, ["Title"], ""),
                        textScaleFactor: 2.4,
                      ), //作品标题。
                      originalLinkSpans.length > 0
                          ? RichText(
                              text: TextSpan(
                                children: originalLinkSpans,
                              ),
                            )
                          : SizedBox(
                              height: 0,
                            ), //如果有原文链接显示原文链接；没有的话就不显示。
                      _prevID == 0
                          ? Wrap(
                              spacing: 8,
                              children: _rq.renderer.tags2Chips(
                                List.from(_rq.renderer.extractFromTree(
                                    _topicInfo, ["Tags", "OtherTags"], [])),
                                onTap: (tag) {
                                  Navigator.push(context,
                                      MaterialPageRoute(builder: (context) {
                                    return TagView(value: {"TagName": tag});
                                  }));
                                },
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _rq.renderer
                                    .extractFromTree(_topicInfo, ["Title"], ""),
                                textScaleFactor: 1.6,
                              ),
                            ), //如果是前言页，显示其余的标签；如果是章节，显示章节标题。
                      Wrap(
                        children: <Widget>[
                          (_parent["Tags"]["Type"] == "图集")
                              ? Chip(
                                  label: Text(_rq.renderer
                                      .extractFromTree(
                                          _topicInfo, ["ImageCount"], 0)
                                      .toString()),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                  ),
                                  avatar: Icon(
                                    Icons.photo_library,
                                    color: Colors.brown,
                                  ),
                                  backgroundColor: _getBackground(),
                                )
                              : Chip(
                                  label: Text(_rq.renderer
                                      .extractFromTree(
                                          _topicInfo, ["WordCount"], 0)
                                      .toString()),
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                  ),
                                  avatar: Icon(
                                    Icons.chrome_reader_mode,
                                    color: Colors.brown,
                                  ),
                                  backgroundColor: _getBackground(),
                                ),
                          Chip(
                            label: Text(_rq.renderer.formatTime(_rq.renderer
                                .extractFromTree(
                                    _topicInfo, ["DateCreated"], 0))),
                            labelStyle: TextStyle(
                              color: Theme.of(context).disabledColor,
                            ),
                            avatar: Icon(
                              Icons.event,
                              color: Colors.blue[600],
                            ),
                            backgroundColor: _getBackground(),
                          ),
                          Chip(
                            label: Text(likes.toString()),
                            labelStyle: TextStyle(
                              color: Theme.of(context).disabledColor,
                            ),
                            avatar: Icon(
                              Icons.thumb_up,
                              color: Colors.green,
                            ),
                            backgroundColor: _getBackground(),
                          ),
                          Chip(
                            label: Text(dislikes.toString()),
                            labelStyle: TextStyle(
                              color: Theme.of(context).disabledColor,
                            ),
                            avatar: Icon(
                              Icons.thumb_down,
                              color: Colors.red,
                            ),
                            backgroundColor: _getBackground(),
                          )
                        ],
                        alignment: WrapAlignment.end,
                      ), //第一行作品数据。
                      Wrap(
                        children: secondInfoLine,
                        alignment: WrapAlignment.end,
                      ), //前面提到的第二行作品数据。
                      Divider(), //简单的分割线。
                      _showTopicContent(), //文章内容部分。显示的函数在下面。
                      _showAppendix(), //如果有前作的话，在这里显示前作。
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            LinearProgressIndicator(
                              backgroundColor: Colors.red,
                              value: likes + dislikes <= 0
                                  ? 1
                                  : (likes / (likes + dislikes)),
                              valueColor: new AlwaysStoppedAnimation<Color>(
                                  likes + dislikes <= 0
                                      ? Colors.grey
                                      : Colors.green),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Icon(
                                        Icons.thumb_up,
                                        color: Colors.green,
                                      ),
                                      SizedBox(
                                        width: 8,
                                      ),
                                      Text(likes.toString()),
                                    ],
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Text(dislikes.toString()),
                                      SizedBox(
                                        width: 8,
                                      ),
                                      Icon(
                                        Icons.thumb_down,
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ), //在作品与评论之间有一个赞踩信息组成的红绿条。
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 5,
                        children: <Widget>[
                          ChoiceChip(
                            label: Text(
                                FlutterI18n.translate(context, "comments")),
                            selectedColor: Theme.of(context).accentColor,
                            disabledColor: Theme.of(context).disabledColor,
                            onSelected: (bool selected) {
                              setState(() {
                                _bottomIndex = 0;
                              });
                              if (_sc.position.pixels >=
                                  _sc.position.maxScrollExtent - 400) {
                                _getComments(0);
                              }
                            },
                            selected: _bottomIndex == 0,
                            labelStyle: _bottomIndex == 0
                                ? TextStyle(color: Colors.white)
                                : null,
                          ),
                          ChoiceChip(
                            label: Text(
                                FlutterI18n.translate(context, "discover")),
                            selectedColor: Theme.of(context).accentColor,
                            disabledColor: Theme.of(context).disabledColor,
                            onSelected: (bool selected) {
                              setState(() {
                                _bottomIndex = 1;
                              });
                              if (!_isRecommendLoaded) _getRecommend();
                            },
                            selected: _bottomIndex == 1,
                            labelStyle: _bottomIndex == 1
                                ? TextStyle(color: Colors.white)
                                : null,
                          )
                        ],
                      ),
                    ],
                  ),
                ),
                //小片组，选择底部显示评论还是推荐内容。
                _bottomIndex == 1 ? _showDiscover() : _showComments(),
                //根据上面所选择的部分来显示下面的内容。
              ],
            ),
          )
        ],
      ));
    }
    if (_isCustomBranch && _topicInfo["Branches"].isNotEmpty) {
      List<Widget> branchTiles = [
        Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(12),
          child: _rq.renderer.pageSubtitle(
            FlutterI18n.translate(context, "please_select_a_branch"),
            textColor: Theme.of(context).accentColor,
          ),
        )
      ];
      _topicInfo["Branches"].forEach((k, v) {
        branchTiles.add(ListTile(
          title: Text(k),
          onTap: () {
            _goToTopic(v);
          },
        ));
      });
      pageBody.add(ListView(
        children: branchTiles,
      ));
    } else {
      pageBody.add(Container(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 20.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                _nextID > 0 ? Icons.arrow_forward : Icons.close,
                size: 20.0,
                color: Colors.grey.withAlpha(127),
              ),
              Text(
                _nextID > 0
                    ? FlutterI18n.translate(
                        context, "swipe_left_to", translationParams: {
                        "Object": FlutterI18n.translate(context, "next_chapter")
                      })
                    : FlutterI18n.translate(
                        context, "it_is_already", translationParams: {
                        "Object": FlutterI18n.translate(context, "the_rear_one")
                      }),
                style: TextStyle(
                  fontSize: 20.0,
                  color: Colors.grey.withAlpha(127),
                ),
              )
            ],
          ),
        ),
      ));
    }
    //后一页指示符。

    List<Widget> bottomBarItems = []; //这边是作品页面底端操作栏的所有按钮。
    if (allowedOptions.contains("upvote")) //点赞。
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.thumb_up,
          color: _rq.renderer.extractFromTree(_topicInfo, ["MyVote"], "") ==
                  "upvote"
              ? Colors.green
              : Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.manage(_rq.renderer.extractFromTree(_parent, ["ID"], 0), 6, "1",
              (res) {
            setState(() {
              if (_topicInfo["MyVote"] != "upvote") {
                if (_topicInfo["MyVote"] == "downvote")
                  _topicInfo["Downvotes"]--;
                _topicInfo["MyVote"] = "upvote";
                _topicInfo["Upvotes"]++;
              } else {
                _topicInfo["MyVote"] = null;
                _topicInfo["Upvotes"]--;
              }
            });
          });
        },
      ));
    if (allowedOptions.contains("downvote")) //点踩。
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.thumb_down,
          color: _rq.renderer.extractFromTree(_topicInfo, ["MyVote"], "") ==
                  "downvote"
              ? Colors.red
              : Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.manage(_rq.renderer.extractFromTree(_parent, ["ID"], 0), 7, "1",
              (res) {
            setState(() {
              if (_topicInfo["MyVote"] != "downvote") {
                if (_topicInfo["MyVote"] == "upvote") _topicInfo["Upvotes"]--;
                _topicInfo["MyVote"] = "downvote";
                _topicInfo["Downvotes"]++;
              } else {
                _topicInfo["MyVote"] = null;
                _topicInfo["Downvotes"]--;
              }
            });
          });
        },
      ));
    if (allowedOptions.contains("highpraise")) //HighPraise
      bottomBarItems.add(IconButton(
        icon: Icon(
          _rq.renderer.extractFromTree(_topicInfo, ["MyHighPraise"], 0) > 0
              ? Icons.star
              : Icons.star_border,
          color:
              _rq.renderer.extractFromTree(_topicInfo, ["MyHighPraise"], 0) > 0
                  ? Colors.orange
                  : Colors.black.withAlpha(137),
        ),
        onPressed: () {
          if (_rq.renderer.extractFromTree(_topicInfo, ["MyHighPraise"], 1) ==
              0) {
            showDialog(
                //弹出一个窗口，问用户要给几个HighPraise。原创和翻译可以给两个，转载只能给一个。
                context: context,
                builder: (BuildContext context) {
                  List<Widget> actions = [
                    FlatButton(
                      onPressed: () {
                        _rq.manage(
                            _rq.renderer.extractFromTree(_parent, ["ID"], 0),
                            1,
                            "HighPraise", (res) {
                          setState(() {
                            _topicInfo["HighPraise"] =
                                _topicInfo["HighPraise"] -
                                    _topicInfo["MyHighPraise"];
                            _topicInfo["MyHighPraise"] = 1;
                            _topicInfo["HighPraise"] =
                                _topicInfo["HighPraise"] +
                                    _topicInfo["MyHighPraise"];
                          });
                        });
                        Navigator.of(context).pop(this);
                      },
                      child: Text(FlutterI18n.translate(context, "give_one")),
                    )
                  ];
                  if (["原创", "翻译"].contains(_rq.renderer
                      .extractFromTree(_parent, ["Tags", "Source"], "")))
                    actions.add(FlatButton(
                      onPressed: () {
                        _rq.manage(
                            _rq.renderer.extractFromTree(_parent, ["ID"], 0),
                            1,
                            "DoubleHighPraise", (res) {
                          setState(() {
                            _topicInfo["HighPraise"] =
                                _topicInfo["HighPraise"] -
                                    _topicInfo["MyHighPraise"];
                            _topicInfo["MyHighPraise"] = 2;
                            _topicInfo["HighPraise"] =
                                _topicInfo["HighPraise"] +
                                    _topicInfo["MyHighPraise"];
                          });
                        });
                        Navigator.of(context).pop(this);
                      },
                      child: Text(FlutterI18n.translate(context, "give_two")),
                    )); //如果是原创或翻译，就把“给两个”的按钮也加进去。
                  actions.add(FlatButton(
                    onPressed: () {
                      Navigator.of(context).pop(this);
                    },
                    child: Text(FlutterI18n.translate(context, "quit")),
                  ));
                  return AlertDialog(
                    title: Text(
                        FlutterI18n.translate(context, "highpraise_title")),
                    content:
                        Text(FlutterI18n.translate(context, "highpraise_desc")),
                    actions: actions,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                  );
                });
          }
        },
      ));
    if (allowedOptions.contains("favorite")) //收藏
      bottomBarItems.add(IconButton(
        icon: Icon(
          _rq.renderer.extractFromTree(_topicInfo, ["IsFavorite"], false)
              ? Icons.bookmark
              : Icons.bookmark_border,
          color: _rq.renderer.extractFromTree(_topicInfo, ["IsFavorite"], false)
              ? Colors.lightBlue
              : Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.manage(_rq.renderer.extractFromTree(_parent, ["ID"], 0), 4, "1",
              (res) {
            setState(() {
              _topicInfo["IsFavorite"] = !_topicInfo["IsFavorite"];
              if (_topicInfo["IsFavorite"]) {
                _topicInfo["Followers"]++;
              } else {
                _topicInfo["Followers"]--;
              }
            });
          });
        },
      ));
    if (allowedOptions.contains("share")) //分享。
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.share,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.share(
              "clipboard", "https://fimtale.com/t/" + _topicID.toString());
        },
      ));
    if (allowedOptions.contains("download")) //下载。
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.file_download,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            builder: (BuildContext context) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ListTile(
                      title: Text(FlutterI18n.translate(
                          context, "download_with_format",
                          translationParams: {"Format": ".txt"})),
                      onTap: () {
                        _rq.launchURL("https://fimtale.com/export/txt/" +
                            _topicID.toString());
                      },
                    ),
                    ListTile(
                      title: Text(FlutterI18n.translate(
                          context, "download_with_format",
                          translationParams: {"Format": ".epub"})),
                      onTap: () {
                        _rq.launchURL("https://fimtale.com/export/epub/" +
                            _topicID.toString());
                      },
                    ),
                    ListTile(
                      title: Text(FlutterI18n.translate(
                          context, "download_with_format",
                          translationParams: {"Format": ".mobi"})),
                      onTap: () {
                        _rq.launchURL("https://fimtale.com/export/mobi/" +
                            _topicID.toString());
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ));
    if (allowedOptions.contains("comment")) //评论。
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.comment,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: _postComment,
      ));

    if (allowedOptions.contains("insert_into_examination_queue")) //加进审核队列
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.unarchive,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: () {
          showDialog(
              context: context,
              builder: (BuildContext context1) {
                return AlertDialog(
                  title: Text(FlutterI18n.translate(
                      context, "examination_queue_insertion_title")),
                  content: Text(FlutterI18n.translate(
                      context, "examination_queue_insertion_desc")),
                  actions: <Widget>[
                    FlatButton(
                      onPressed: () {
                        _rq.manage(
                            _rq.renderer.extractFromTree(_parent, ["ID"], 0),
                            1,
                            "InsertExaminationQueue", (res) {
                          Toast.show(res["Message"], context);
                          _refresh();
                        });
                        Navigator.of(context1).pop(this);
                      },
                      child: Text(FlutterI18n.translate(context, "confirm")),
                    ),
                    FlatButton(
                      onPressed: () {
                        Navigator.of(context1).pop(this);
                      },
                      child: Text(FlutterI18n.translate(context, "quit")),
                    )
                  ],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                );
              });
        },
      ));

    if (allowedOptions.contains("pass_examination")) //通过审核
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.check,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: () {
          showDialog(
              //弹出窗口确认是否过审。
              context: context,
              builder: (BuildContext context1) {
                return AlertDialog(
                  title: Text(FlutterI18n.translate(
                      context, "pass_examination_confirm_title")),
                  actions: <Widget>[
                    FlatButton(
                      onPressed: () {
                        _rq.manage(
                            _rq.renderer.extractFromTree(_parent, ["ID"], 0),
                            1,
                            "PassExamination", (res) {
                          Toast.show(res["Message"], context);
                          _refresh();
                        });
                        Navigator.of(context1).pop(this);
                      },
                      child: Text(FlutterI18n.translate(context, "confirm")),
                    ),
                    FlatButton(
                      onPressed: () {
                        Navigator.of(context1).pop(this);
                      },
                      child: Text(FlutterI18n.translate(context, "quit")),
                    )
                  ],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10))),
                );
              });
        },
      ));

    if (allowedOptions.contains("reject_examination")) //退回
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.clear,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.renderer
              .inputModal(
            //弹出窗口填写退回理由。
            hint: FlutterI18n.translate(context, "input_reject_reason"),
            buttonText: FlutterI18n.translate(context, "submit"),
          )
              .then((value) {
            if (value == null || value.length == 0) return;
            _rq.manage(_rq.renderer.extractFromTree(_parent, ["ID"], 0), 1,
                "FailExamination", (res) {
              Toast.show(res["Message"], context);
              Navigator.pop(context);
            }, params: {"Reason": value});
          });
        },
      ));

    //以下这个函数会在build函数执行完后执行，所以适合进行页面的跳转。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rq.updateShareCardInfo().then((value) {
        if (!mounted) return;
        setState(() {});
      });

      if (_comments.containsKey(_commentID) && !_isCommentShown) {
        RenderBox renderBox =
            _comments[_commentID].currentContext.findRenderObject();
        double target =
            _sc.position.pixels + renderBox.localToGlobal(Offset.zero).dy;
        _sc.jumpTo(target - 100);
        _isCommentShown = true;
      }
    });

    //返回渲染完成的页面。
    return new Scaffold(
      backgroundColor: _getBackground(),
      body: Builder(
        builder: (BuildContext context) {
          _scaffordContext = context;
          return PageView(
            scrollDirection: Axis.horizontal,
            reverse: false,
            controller: _pc,
            physics: BouncingScrollPhysics(),
            pageSnapping: true,
            onPageChanged: (index) {
              //如果页面变化，通过index来判断是左滑还是右滑。
              switch (index - _curIndex) {
                case 1: //左滑，代表需要前往下一章。
                  if (_nextID > 0) {
                    //如果有下一章，就跳过去。
                    _goToTopic(_nextID);
                  } else if (!_isCustomBranch ||
                      _topicInfo["Branches"].isEmpty) {
                    _pc.animateToPage(
                      _curIndex,
                      duration: Duration(microseconds: 300),
                      curve: Curves.easeInSine,
                    ); //如果没有的话，就弹回来。
                  }
                  break;
                case -1: //右滑，代表需要前往上一章。
                  if (_prevID > 0) {
                    if (_isCustomBranch &&
                        _from.length >= 2 &&
                        _from[_from.length - 1] == _topicID)
                      _from = List.from(_from.take(_from.length - 2));
                    _goToTopic(_prevID);
                  } else {
                    _pc.animateToPage(
                      _curIndex,
                      duration: Duration(microseconds: 300),
                      curve: Curves.easeInSine,
                    );
                  }
                  break;
              }
            },
            children: pageBody,
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          mainAxisSize: MainAxisSize.max,
          children: bottomBarItems,
        ),
      ),
    );
  }

  Widget _showTopicContent() {
    return GestureDetector(
        child: Column(
          //这整个下面都是作品内容的渲染。服务器端传回的作品是MarkDown格式，所以使用MarkDownGenerator组件来显示作品。
          key: _passage,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: MarkdownGenerator(
            data: _rq.renderer.emojiUtil(
                _rq.renderer.extractFromTree(_topicInfo, ["Content"], "")),
            styleConfig: StyleConfig(
              imgBuilder: (String url, attributes) {
                int index = _imageUrls.indexOf(url);
                if (index < 0) {
                  index = _imageUrls.length;
                  _imageUrls.add(url);
                }
                return GestureDetector(
                  onTap: () {
                    _openImageViewer(index);
                  },
                  child: Image.network(url),
                );
              },
              titleConfig: TitleConfig(
                h1: TextStyle(
                  fontSize: _fontSize * 2,
                ),
                h2: TextStyle(
                  fontSize: _fontSize * (11 / 6),
                ),
                h3: TextStyle(
                  fontSize: _fontSize * (5 / 3),
                ),
                h4: TextStyle(
                  fontSize: _fontSize * (3 / 2),
                ),
                h5: TextStyle(
                  fontSize: _fontSize * (4 / 3),
                ),
                h6: TextStyle(
                  fontSize: _fontSize * (7 / 6),
                ),
              ),
              pConfig: PConfig(
                textStyle: TextStyle(
                  fontSize: _fontSize,
                ),
                linkStyle: TextStyle(
                  fontSize: _fontSize,
                  color: Colors.blue,
                ),
                onLinkTap: (url) {
                  _rq.launchURL(url);
                },
                custom: (node) {
                  switch (node.tag) {
                    case "collapse":
                    case "reply":
                      return ExpansionTile(
                        title: new Text(FlutterI18n.translate(
                            context, "something_is_collapsed")),
                        children: <Widget>[Text(node.attributes["content"])],
                      );
                      break;
                    case "login":
                      if (node.attributes["available"] == "true") {
                        return Card(
                          child: Container(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  FlutterI18n.translate(
                                      context, "content_visible_when_login"),
                                  textScaleFactor: 1.25,
                                ),
                                Text(node.attributes["content"]),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return Card(
                          child: Container(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  FlutterI18n.translate(
                                      context, "login_to_read"),
                                  textScaleFactor: 1.25,
                                ),
                                Text(node.attributes["content"]),
                              ],
                            ),
                          ),
                        );
                      }
                      break;
                    case "share":
                      _rq.shareLinkBuffer.add("/" +
                          _rq.getTypeCode(node.attributes["type"]) +
                          "/" +
                          node.attributes["code"]);
                      return ShareCard(_rq, node.attributes["type"],
                          node.attributes["code"]);
                      break;
                    case "spoiler":
                      return Spoiler(
                        content: node.attributes["content"],
                        textStyle: TextStyle(
                          fontSize: _fontSize,
                        ),
                      );
                      break;
                    case "ftemoji":
                      return FTEmoji(
                        node.attributes["code"],
                        size: _fontSize,
                      );
                      break;
                    default:
                      return SizedBox(
                        width: 0,
                        height: 0,
                      );
                  }
                },
              ),
              blockQuoteConfig: BlockQuoteConfig(
                blockStyle: TextStyle(
                  fontSize: _fontSize,
                ),
              ),
              tableConfig: TableConfig(
                headerStyle: TextStyle(
                  fontSize: _fontSize,
                ),
                bodyStyle: TextStyle(
                  fontSize: _fontSize,
                ),
              ),
              preConfig: PreConfig(
                textStyle: TextStyle(
                  fontSize: _fontSize,
                ),
              ),
              olConfig: OlConfig(
                textStyle: TextStyle(
                  fontSize: _fontSize,
                ),
              ),
              ulConfig: UlConfig(
                textStyle: TextStyle(
                  fontSize: _fontSize,
                ),
              ),
            ),
          ).widgets,
        ),
        onDoubleTap: () {
          //当双击时，打开能够设置阅读进度、字体大小和背景颜色的界面。
          showModalBottomSheet(
            context: context,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (context1, setBottomSheetState) {
                  double progressValue = max(0, min(1, _progress));
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Text(
                            FlutterI18n.translate(context, "progress") +
                                ":" +
                                (progressValue * 100).toStringAsFixed(1) +
                                "%",
                            textScaleFactor: 1.25,
                          ),
                        ),
                        Slider(
                          value: progressValue,
                          onChanged: (v) {
                            setState(() => _setProgress(v));
                            setBottomSheetState(() {
                              _progress = v;
                            });
                          },
                          max: 1,
                          min: 0,
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Text(
                            FlutterI18n.translate(
                                context, "reading_interface_settings"),
                            textScaleFactor: 1.25,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Text(FlutterI18n.translate(context, "font_size")),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _setFontSize(14);
                                  });
                                  setBottomSheetState(() {});
                                },
                                child: Chip(
                                  label: Text(
                                      FlutterI18n.translate(context, "small")),
                                  avatar: Radio(
                                    value: 14,
                                    groupValue: _fontSize,
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _setFontSize(18);
                                  });
                                  setBottomSheetState(() {});
                                },
                                child: Chip(
                                  label: Text(
                                      FlutterI18n.translate(context, "medium")),
                                  avatar: Radio(
                                    value: 18,
                                    groupValue: _fontSize,
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _setFontSize(24);
                                  });
                                  setBottomSheetState(() {});
                                },
                                child: Chip(
                                  label: Text(
                                      FlutterI18n.translate(context, "large")),
                                  avatar: Radio(
                                    value: 24,
                                    groupValue: _fontSize,
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Text(FlutterI18n.translate(
                                  context, "background_color")),
                              Expanded(
                                child: RaisedButton(
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      width: _bgColor == 0x00ffffff ? 2 : 1,
                                      color: _bgColor == 0x00ffffff
                                          ? Theme.of(context).accentColor
                                          : Theme.of(context).disabledColor,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  color: Color(0xffeeeeee),
                                  onPressed: () {
                                    setState(() {
                                      _setBackgroundColor(0x00ffffff);
                                    });
                                    setBottomSheetState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RaisedButton(
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      width: _bgColor == 0xfffaf9de ? 2 : 1,
                                      color: _bgColor == 0xfffaf9de
                                          ? Theme.of(context).accentColor
                                          : Theme.of(context).disabledColor,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  color: Color(0xfffaf9de),
                                  onPressed: () {
                                    setState(() {
                                      _setBackgroundColor(0xfffaf9de);
                                    });
                                    setBottomSheetState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RaisedButton(
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      width: _bgColor == 0xffe3edcd ? 2 : 1,
                                      color: _bgColor == 0xffe3edcd
                                          ? Theme.of(context).accentColor
                                          : Theme.of(context).disabledColor,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  color: Color(0xffe3edcd),
                                  onPressed: () {
                                    setState(() {
                                      _setBackgroundColor(0xffe3edcd);
                                    });
                                    setBottomSheetState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              Expanded(
                                child: RaisedButton(
                                  shape: CircleBorder(
                                    side: BorderSide(
                                      width: _bgColor == 0xffdce2f1 ? 2 : 1,
                                      color: _bgColor == 0xffdce2f1
                                          ? Theme.of(context).accentColor
                                          : Theme.of(context).disabledColor,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  color: Color(0xffdce2f1),
                                  onPressed: () {
                                    setState(() {
                                      _setBackgroundColor(0xffdce2f1);
                                    });
                                    setBottomSheetState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        });
  }

  //显示前作信息。
  Widget _showAppendix() {
    List<Widget> appendix = [];

    if (_prequel.isNotEmpty)
      appendix.addAll([
        SizedBox(
          height: 12,
        ),
        _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "prequel"),
          textColor: Theme.of(context).accentColor,
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return TopicView(value: {"TopicID": _prequel["ID"]});
            }));
          },
          child: Card(
            child: Row(
              children: <Widget>[
                (_prequel.containsKey("Cover") && _prequel["Cover"] != null)
                    ? Flexible(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            _prequel["Cover"],
                            fit: BoxFit.cover,
                          ),
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
                        _prequel["Title"],
                        textScaleFactor: 1.1,
                        maxLines: 2,
                      ),
                      subtitle: Text(_prequel["UserName"]),
                    ),
                  ),
                  flex: 3,
                )
              ],
            ),
            elevation: 0,
            color: Colors.grey.withAlpha(31),
          ),
        )
      ]);

    return appendix.isNotEmpty
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: appendix,
          )
        : SizedBox(height: 0);
  }

  //显示评论信息。
  Widget _showComments() {
    List<Widget> commentSelectors = [],
        comments = []; //第一个是评论的选择器，第二个是评论列表，两个都是塞在容器中的内容集合。
    int curIndex = 0;

    commentSelectors.addAll([
      Text(FlutterI18n.translate(context, "sort_by") + ":"),
      FlatButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          _commentSortbyStarHonor = !_commentSortbyStarHonor;
          _rq.clearOrCreateList("Comments");
          _getComments(_commentID);
        },
        child: Text(
          FlutterI18n.translate(
              context, _commentSortbyStarHonor ? "starhonor" : "post_time"),
          style: TextStyle(color: Colors.blue[700]),
        ),
      ),
      FlatButton(
        padding: EdgeInsets.zero,
        onPressed: () {
          _commentOrderDesc = !_commentOrderDesc;
          _rq.clearOrCreateList("Comments");
          _getComments(_commentID);
        },
        child: Text(
          FlutterI18n.translate(
              context, _commentOrderDesc ? "ascending" : "descending"),
          style: TextStyle(color: Colors.green[700]),
        ),
      )
    ]);

    if (_topicID == _rq.renderer.extractFromTree(_parent, ["ID"], 0))
      commentSelectors.addAll([
        SizedBox(
          width: 5,
        ),
        Text(FlutterI18n.translate(context, "view") + ":"),
        FlatButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            _commentFirstPageOnly = !_commentFirstPageOnly;
            _rq.clearOrCreateList("Comments");
            _getComments(_commentID);
          },
          child: Text(
            _commentFirstPageOnly
                ? FlutterI18n.translate(context, "first_page_only")
                : (FlutterI18n.translate(context, "all_content")),
            style: TextStyle(color: Colors.amber[700]),
          ),
        ),
      ]);

    comments.add(Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: commentSelectors,
      ),
    ));

    _rq.getListByName("Comments").forEach((element) {
      //循环遍历评论列表。
      GlobalKey temp = new GlobalKey();
      int index = curIndex;
      List<String> allowedOptions = List<String>.from(
          _rq.renderer.extractFromTree(element, ["AllowedOptions"], []));
      List<Widget> actionBarItems = [];
      actionBarItems.addAll([
        IconButton(
            icon: Icon(
              Icons.thumb_up,
              color: _rq.renderer.extractFromTree(element, ["MyVote"], null) ==
                      "upvote"
                  ? Colors.green
                  : Colors.black.withAlpha(137),
            ),
            onPressed: () {
              if (allowedOptions.contains("upvote"))
                _rq.manage(
                    _rq.renderer.extractFromTree(element, ["ID"], 0), 6, "4",
                    (res) {
                  setState(() {
                    if (element["MyVote"] != "upvote") {
                      if (element["MyVote"] == "downvote")
                        element["Downvotes"]--;
                      element["MyVote"] = "upvote";
                      element["Upvotes"]++;
                    } else {
                      element["MyVote"] = null;
                      element["Upvotes"]--;
                    }
                    _rq.setListItemByNameAndIndex("Comment", index, element);
                  });
                });
            }),
        Text(_rq.renderer.extractFromTree(element, ["Upvotes"], 0).toString()),
        SizedBox(
          width: 5,
        )
      ]); //点赞按钮和赞数。
      actionBarItems.addAll([
        IconButton(
            icon: Icon(
              Icons.thumb_down,
              color: _rq.renderer.extractFromTree(element, ["MyVote"], null) ==
                      "downvote"
                  ? Colors.red
                  : Colors.black.withAlpha(137),
            ),
            onPressed: () {
              if (allowedOptions.contains("downvote"))
                _rq.manage(
                    _rq.renderer.extractFromTree(element, ["ID"], 0), 7, "4",
                    (res) {
                  setState(() {
                    if (element["MyVote"] != "downvote") {
                      if (element["MyVote"] == "upvote") element["Upvotes"]--;
                      element["MyVote"] = "downvote";
                      element["Downvotes"]++;
                    } else {
                      element["MyVote"] = null;
                      element["Downvotes"]--;
                    }
                    _rq.setListItemByNameAndIndex("Comment", index, element);
                  });
                });
            }),
        Text(
            _rq.renderer.extractFromTree(element, ["Downvotes"], 0).toString()),
        SizedBox(
          width: 5,
        )
      ]); //点踩按钮和踩数。

      if (_rq.renderer
          .extractFromTree(element, ["IsStarHonored"], false)) //给过StarHonor的
        actionBarItems.add(IconButton(
          icon: Icon(
            Icons.star,
            color: Colors.orange,
          ),
          onPressed: () {},
        ));
      else if (allowedOptions.contains("starhonor")) //StarHonor
        actionBarItems.add(IconButton(
            icon: Icon(
              Icons.star,
              color: Colors.black.withAlpha(137),
            ),
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                          FlutterI18n.translate(context, "starhonor_title")),
                      content: Text(
                          FlutterI18n.translate(context, "starhonor_desc")),
                      actions: <Widget>[
                        FlatButton(
                          onPressed: () {
                            _rq.manage(
                                _rq.renderer
                                    .extractFromTree(element, ["ID"], 0),
                                2,
                                "StarHonor", (res) {
                              setState(() {
                                element["IsStarHonored"] = true;
                                _rq.setListItemByNameAndIndex(
                                    "Comment", index, element);
                              });
                            });
                            Navigator.of(context).pop(this);
                          },
                          child: Text(FlutterI18n.translate(context, "give")),
                        ),
                        FlatButton(
                          onPressed: () {
                            Navigator.of(context).pop(this);
                          },
                          child: Text(FlutterI18n.translate(context, "quit")),
                        )
                      ],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                    );
                  });
            }));

      if (allowedOptions.contains("favorite")) //收藏。
        actionBarItems.add(IconButton(
            icon: Icon(
              _rq.renderer.extractFromTree(element, ["IsFavorite"], false)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color:
                  _rq.renderer.extractFromTree(element, ["IsFavorite"], false)
                      ? Colors.lightBlue
                      : Colors.black.withAlpha(137),
            ),
            onPressed: () {
              _rq.manage(
                  _rq.renderer.extractFromTree(element, ["ID"], 0), 4, "4",
                  (res) {
                setState(() {
                  element["IsFavorite"] = !element["IsFavorite"];
                  _rq.setListItemByNameAndIndex("Comment", index, element);
                });
              }, params: {"Category": "post"});
            }));

      if (allowedOptions.contains("reply")) //回复
        actionBarItems.add(IconButton(
            icon: Icon(
              Icons.reply,
              color: Colors.black.withAlpha(137),
            ),
            onPressed: () {
              _postComment(
                  initText: "回复[" +
                      element["ID"].toString() +
                      "](/goto/" +
                      _topicID.toString() +
                      "-" +
                      element["ID"].toString() +
                      ") @" +
                      element["UserName"] +
                      " :\n");
            }));

      List<Widget> extendedActions = [];

      if (allowedOptions.contains("report")) //举报
        extendedActions.add(ListTile(
          title: Text(FlutterI18n.translate(context, "report")),
          onTap: () {
            _rq.renderer.reportWindow("post", element["ID"]);
          },
        ));

      if (allowedOptions.contains("delete")) //删除
        extendedActions.add(ListTile(
          title: Text(FlutterI18n.translate(context, "delete")),
          onTap: () {
            showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text(
                        FlutterI18n.translate(context, "confirm_deletion")),
                    actions: <Widget>[
                      FlatButton(
                        onPressed: () {
                          _rq.manage(element["ID"], 2, "Delete", (res) {
                            Toast.show(
                                FlutterI18n.translate(
                                    context, "successfully_deleted"),
                                context);
                          });
                          Navigator.of(context).pop(this);
                        },
                        child: Text(FlutterI18n.translate(context, "confirm")),
                      ),
                      FlatButton(
                        onPressed: () {
                          Navigator.of(context).pop(this);
                        },
                        child: Text(FlutterI18n.translate(context, "quit")),
                      )
                    ],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                  );
                });
          },
        ));

      if (allowedOptions.contains("share")) //分享
        extendedActions.addAll([
          ListTile(
            title: Text(FlutterI18n.translate(context, "copy_link")),
            onTap: () {
              Navigator.pop(context);
              _rq.share(
                  "clipboard",
                  "https://fimtale.com/goto/" +
                      _topicID.toString() +
                      "-" +
                      element["ID"].toString());
            },
          ),
          ListTile(
            title:
                Text(FlutterI18n.translate(context, "generate_share_ticket")),
            onTap: () {
              Navigator.pop(context);
              _rq.share(
                  "share_ticket",
                  "https://fimtale.com/goto/" +
                      _topicID.toString() +
                      "-" +
                      element["ID"].toString(),
                  info: {
                    "title": _topicInfo["Title"] +
                        (_parent["ID"] != _topicInfo["ID"]
                            ? " - " + _parent["Title"]
                            : ""),
                    "subtitle": _author["UserName"],
                    "content": markdownToHtml(element["Content"]) +
                        '<p style="text-align:right;">——' +
                        element["UserName"] +
                        '</p>'
                  });
            },
          )
        ]);

      if (extendedActions.length > 0) //如果有其余操作，则增加这个省略号。
        actionBarItems.add(IconButton(
            icon: Icon(
              Icons.more_vert,
              color: Colors.black.withAlpha(137),
            ),
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(10)),
                  ),
                  builder: (BuildContext context) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: extendedActions,
                      ),
                    );
                  });
            }));

      comments.add(Container(
        key: temp,
        child: _rq.renderer.commentCard(element, (url) {
          _rq.launchURL(url, returnWhenCommentIDFounds: true).then((value) {
            if (value != null) {
              Map<String, dynamic> res =
                  Map<String, dynamic>.from(jsonDecode(value));
              if (res["IsCommentFound"]) {
                if (res["Type"] == "topic" && res["MainID"] == _topicID) {
                  _isCommentShown = false;
                  _getComments(res["CommentID"]);
                } else {
                  _rq.launchURL(url);
                }
              }
            }
          });
        }, actionBarItems: actionBarItems),
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(3)),
          color:
              _commentID == element["ID"] ? Colors.yellow.withAlpha(31) : null,
        ),
      ));
      _comments[element["ID"]] = temp;
      curIndex++;
    });
    if (_rq.isLoading("Comments"))
      comments.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Comments") >= _rq.getTotalPage("Comments"))
      comments.add(_rq.renderer.endNotice());

    //返回渲染过后的评论列表。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: comments,
    );
  }

  //展示推荐界面。
  Widget _showDiscover() {
    List<Widget> contentList = [];

    if (_sequels.length > 0) { //续作。
      contentList.add(Container(
        padding: EdgeInsets.all(12),
        child: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "sequel"),
          textColor: Theme.of(context).accentColor,
        ),
      ));
      contentList.addAll(_rq.renderer.topicList(_sequels));
    }

    if (_channelsInvolved.length > 0) { //包含这一作品的频道。
      contentList.add(Container(
        padding: EdgeInsets.all(12),
        child: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "channels_involved"),
          textColor: Theme.of(context).accentColor,
        ),
      ));
      _channelsInvolved.forEach((element) {
        contentList.add(ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              _rq.renderer.extractFromTree(element, ["Background"],
                  "https://i.loli.net/2020/04/09/NJI4nlBywjibo2X.jpg"),
            ),
          ),
          title: Text(
            _rq.renderer.extractFromTree(element, ["Name"], ""),
            maxLines: 1,
          ),
          subtitle: Text(
            _rq.renderer.extractFromTree(element, ["CreatorName"], ""),
            maxLines: 1,
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return ChannelView(value: {"ChannelID": element["ID"]});
            }));
          },
        ));
      });
    }

    if (_recommendTopics.length > 0) { //推荐的作品。
      contentList.add(Container(
        padding: EdgeInsets.all(12),
        child: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "related_topics"),
          textColor: Theme.of(context).accentColor,
        ),
      ));
      print(_recommendTopics);
      contentList.addAll(_rq.renderer.topicList(_recommendTopics));
    }

    if (_relatedChannels.length > 0) { //相关频道。
      contentList.add(Container(
        padding: EdgeInsets.all(12),
        child: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "related_channels"),
          textColor: Theme.of(context).accentColor,
        ),
      ));
      _relatedChannels.forEach((element) {
        contentList.add(ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              _rq.renderer.extractFromTree(element, ["Background"],
                  "https://i.loli.net/2020/04/09/NJI4nlBywjibo2X.jpg"),
            ),
          ),
          title: Text(
            _rq.renderer.extractFromTree(element, ["Name"], ""),
            maxLines: 1,
          ),
          subtitle: Text(
            _rq.renderer.extractFromTree(element, ["CreatorName"], ""),
            maxLines: 1,
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return ChannelView(value: {"ChannelID": element["ID"]});
            }));
          },
        ));
      });
    }

    if (_isRecommendLoading) contentList.add(_rq.renderer.preloader());

    //返回渲染过后的推荐列表。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: contentList,
    );
  }
}
