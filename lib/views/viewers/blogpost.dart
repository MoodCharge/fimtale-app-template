import 'dart:convert';

import 'package:fimtale/elements/share_card.dart';
import 'package:fimtale/views/custom/editor.dart';
import 'package:fimtale/views/lists/blogpost.dart';
import 'package:fimtale/views/viewers/topic.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:fimtale/elements/ftemoji.dart';
import 'package:fimtale/elements/spoiler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/viewers/image_viewer.dart';
import 'package:sp_util/sp_util.dart';
import 'package:toast/toast.dart';

//博文的界面与作品的界面设计思路类似，可以参考/viewers/topic.dart中的注释。一旦你读懂它，你就能读懂这边的代码。

class BlogpostView extends StatefulWidget {
  final value;

  BlogpostView({Key key, @required this.value}) : super(key: key);

  @override
  _BlogpostViewState createState() => new _BlogpostViewState(value);
}

class _BlogpostViewState extends State<BlogpostView> {
  var value;
  String _pageTitle = "", _formHash = "";
  List _imageUrls = [];
  Map<String, dynamic> _blogpostInfo = {},
      _author = {},
      _relatedTopic = {}; //最后一个是相关作品。
  bool _isLoading = false,
      _isRefreshing = false,
      _isCommentShown = false,
      _commentSortbyRating = false,
      _commentOrderDesc = false;
  int _blogpostID = 0, _commentID = 0, _prevID = 0, _nextID = 0, _curIndex = 1;
  RequestHandler _rq;
  PageController _pc;
  ScrollController _sc = new ScrollController();
  GlobalKey _passage = GlobalKey();
  Map<int, GlobalKey> _comments = {};

  _BlogpostViewState(value) {
    this.value = value;
    this._blogpostID = this.value["BlogpostID"];
    if (value.containsKey("CommentID")) _commentID = value["CommentID"];
    _pc = new PageController(
      initialPage: _curIndex,
      viewportFraction: 1,
      keepPage: true,
    );
  }

  @override
  void initState() {
    super.initState();
    _pageTitle = "";
    _rq = new RequestHandler(context, listNames: ["Comments"]);
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getComments(0);
      }
    });
    _getBlogpost(_commentID);
  }

  @override
  void dispose() {
    _pc.dispose();
    _sc.dispose();
    super.dispose();
  }

  //刷新博文页面。
  Future<Null> _refresh() async {
    _rq.getListNames().forEach((element) {
      _rq.clearOrCreateList(element);
    });
    _blogpostInfo = {};
    _author = {};
    _relatedTopic = {};
    _getBlogpost(_commentID);
    return;
  }

  //获取博文信息。
  _getBlogpost(int commentID) async {
    if (_isLoading || !mounted) return;
    setState(() {
      _isLoading = true;
      if (commentID <= 0) _rq.setIsLoading("Comments", true);
    });
    var result = await this._rq.request("/api/v1/b/" + _blogpostID.toString());

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _isLoading = false;
        _blogpostInfo = result["BlogpostInfo"];
        _author = result["AuthorInfo"];
        _relatedTopic = result["RelatedTopic"] ?? Map<String, dynamic>();
        _pageTitle = result["BlogpostInfo"]["Title"];
        if (result["Prev"] != null) {
          _prevID = result["Prev"]["ID"];
        }
        if (result["Next"] != null) {
          _nextID = result["Next"]["ID"];
        }
        if (commentID <= 0) {
          _rq.setListByName("Comments", result["CommentsArray"]);
          _rq.setCurPage("Comments", result["Page"]);
          _rq.setTotalPage("Comments", result["TotalPage"]);
          _rq.setIsLoading("Comments", false);
        } else {
          _getComments(commentID);
        }
      });
    } else {
      _isLoading = false;
      if (commentID <= 0) _rq.setIsLoading("Comments", false);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
      print(result["ErrorMessage"]);
    }
  }

  //跳转到某篇博文。
  _goToBlogpost(int blogpostID) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
      var v = {"BlogpostID": blogpostID};
      return BlogpostView(
        value: v,
      );
    }));
  }

  //获取评论。
  _getComments(int commentID) {
    Map<String, dynamic> params = {};
    if (_commentOrderDesc) params["order"] = "d";
    if (_commentSortbyRating) {
      params["sortby"] = "starhonor";
      params["order"] = "d";
    }
    if (commentID > 0) {
      params["comment"] = commentID.toString();
      if (!mounted) return;
      setState(() {
        _commentID = commentID;
        _rq.clearOrCreateList("Comments");
      });
    }
    if (_commentOrderDesc) params["order"] = "d";
    if (_commentSortbyRating) params["sortby"] = "rating";
    _rq.updateListByName(
        "/api/v1/b/" + _blogpostID.toString(),
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
          if (!mounted) return;
          setState(() {});
        },
        afterUpdate: (list) {
          if (!mounted) return;
          setState(() {});
        },
        onError: (err) {
          Toast.show(err, context,
              duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
        });
  }

  //发表评论。
  _postComment({String initText}) {
    bool transfer = false;
    _rq.renderer.inputModal(
      draftKey: "comment_blogpost_" + _blogpostID.toString(),
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
      if (value != null && value.length > 0) {
        _rq.uploadPost("/new/comment", {
          "FormHash": _formHash,
          "Id": _blogpostID,
          "Target": "blog",
          "Content": markdownToHtml(value),
          "IsForward": transfer
        }, onSubmit: () {
          Toast.show(FlutterI18n.translate(context, "posting"), context);
        }, onSuccess: (link) async {
          SpUtil.remove("draft_comment_blogpost_" + _blogpostID.toString());
          _rq.launchURL(link, returnWhenCommentIDFounds: true).then((value) {
            if (value != null) {
              Map<String, dynamic> res =
                  Map<String, dynamic>.from(jsonDecode(value));
              if (res["IsCommentFound"]) {
                if (res["Type"] == "blogpost" && res["MainID"] == _blogpostID) {
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
    });
  }

  //打开图像查看器。
  _openImageViewer(int index) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return ImageViewer(
        value: {"UrlList": _imageUrls, "CurIndex": index},
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    List<String> allowedOptions = List<String>.from(_rq.renderer
            .extractFromTree(_blogpostInfo, ["AllowedOptions"], [])),
        authorAllowedOptions = List<String>.from(
            _rq.renderer.extractFromTree(_author, ["AllowedOptions"], []));

    List<PopupMenuItem<String>> actionMenu = [];
    if (allowedOptions.contains("edit"))
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "edit")),
        value: "edit",
      ));
    if (allowedOptions.contains("delete"))
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "delete")),
        value: "delete",
      ));
    if (allowedOptions.contains("report"))
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "report")),
        value: "report",
      ));

    List<Widget> appBarActions = [], pageBody = [];

    if (actionMenu.length > 0)
      appBarActions.add(PopupMenuButton(
        itemBuilder: (BuildContext context) => actionMenu,
        onSelected: (String action) {
          switch (action) {
            case "edit":
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return Editor(
                  value: {
                    "Type": "blog",
                    "Action": "edit",
                    "MainID": _blogpostID
                  },
                );
              })).then((value) {
                if (value != null) _refresh();
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
                    _rq.manage(_blogpostID, 9, "Blog", (message) {
                      Toast.show("successfully_deleted", context);
                      Navigator.pop(context);
                    }, params: {"Subaction": "delete"});
                    break;
                }
              });
              break;
            case "report":
              _rq.renderer.reportWindow("blog", _blogpostID);
              break;
          }
        },
      ));

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
              _nextID > 0 ? Icons.arrow_back : Icons.close,
              size: 20.0,
              color: Colors.grey.withAlpha(127),
            ),
            Text(
              _nextID > 0
                  ? FlutterI18n.translate(
                      context, "swipe_right_to", translationParams: {
                      "Object": FlutterI18n.translate(context, "next_blogpost")
                    })
                  : FlutterI18n.translate(
                      context, "it_is_already", translationParams: {
                      "Object": FlutterI18n.translate(context, "the_latest_one")
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
    if (_isLoading) {
      pageBody.add(Center(
        child: _rq.renderer.preloader(),
      ));
    } else {
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
          ),
          SliverToBoxAdapter(
            child: Column(
              children: <Widget>[
                ListTile(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_context) {
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
                                  _author["IsFavorite"] =
                                      !_author["IsFavorite"];
                                });
                              });
                            },
                          )
                        : null),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _rq.renderer
                            .extractFromTree(_blogpostInfo, ["Title"], ""),
                        textScaleFactor: 2.4,
                      ),
                      Wrap(
                        spacing: 8,
                        children: _rq.renderer.tags2Chips(
                          List.from(_rq.renderer
                              .extractFromTree(_blogpostInfo, ["Tags"], [])),
                          colored: false,
                          onTap: (tag) {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (context) {
                              return BlogpostList(value: {"Q": "#" + tag});
                            }));
                          },
                        ),
                      ),
                      Wrap(
                        children: <Widget>[
                          Chip(
                            label: Text(_rq.renderer
                                .extractFromTree(
                                    _blogpostInfo, ["WordCount"], 0)
                                .toString()),
                            labelStyle: TextStyle(
                              color: Theme.of(context).disabledColor,
                            ),
                            avatar: Icon(
                              Icons.chrome_reader_mode,
                              color: Colors.brown,
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                          Chip(
                            label: Text(_rq.renderer.formatTime(_rq.renderer
                                .extractFromTree(
                                    _blogpostInfo, ["DateCreated"], 0))),
                            labelStyle: TextStyle(
                              color: Theme.of(context).disabledColor,
                            ),
                            avatar: Icon(
                              Icons.event,
                              color: Colors.blue[600],
                            ),
                            backgroundColor: Colors.transparent,
                          ),
                        ],
                        alignment: WrapAlignment.end,
                      ),
                      Divider(),
                      _showBlogpostContent(),
                      _showAppendix(),
                      Divider()
                    ],
                  ),
                ),
                _showComments(),
              ],
            ),
          )
        ],
      ));
    }
    pageBody.add(Container(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 20.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(
              _prevID > 0 ? Icons.arrow_forward : Icons.close,
              size: 20.0,
              color: Colors.grey.withAlpha(127),
            ),
            Text(
              _prevID > 0
                  ? FlutterI18n.translate(
                      context, "swipe_left_to", translationParams: {
                      "Object":
                          FlutterI18n.translate(context, "previous_blogpost")
                    })
                  : FlutterI18n.translate(context, "it_is_already",
                      translationParams: {
                          "Object":
                              FlutterI18n.translate(context, "the_earliest_one")
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

    List<Widget> bottomBarItems = [];
    if (allowedOptions.contains("favorite"))
      bottomBarItems.add(IconButton(
        icon: Icon(
          _rq.renderer.extractFromTree(_blogpostInfo, ["IsFavorite"], false)
              ? Icons.bookmark
              : Icons.bookmark_border,
          color:
              _rq.renderer.extractFromTree(_blogpostInfo, ["IsFavorite"], false)
                  ? Colors.lightBlue
                  : Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.manage(
              _rq.renderer.extractFromTree(_blogpostInfo, ["ID"], 0), 4, "5",
              (res) {
            setState(() {
              _blogpostInfo["IsFavorite"] = !_blogpostInfo["IsFavorite"];
              if (_blogpostInfo["IsFavorite"]) {
                _blogpostInfo["Followers"]++;
              } else {
                _blogpostInfo["Followers"]--;
              }
            });
          });
        },
      ));
    if (allowedOptions.contains("share"))
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.share,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: () {
          _rq.share(
              "clipboard", "https://fimtale.com/b/" + _blogpostID.toString());
        },
      ));
    if (allowedOptions.contains("comment"))
      bottomBarItems.add(IconButton(
        icon: Icon(
          Icons.comment,
          color: Colors.black.withAlpha(137),
        ),
        onPressed: _postComment,
      ));

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

    return new Scaffold(
      body: PageView(
        scrollDirection: Axis.horizontal,
        reverse: false,
        controller: _pc,
        physics: BouncingScrollPhysics(),
        pageSnapping: true,
        onPageChanged: (index) {
          switch (index - _curIndex) {
            case 1:
              if (_prevID > 0) {
                _goToBlogpost(_prevID);
              } else {
                _pc.animateToPage(
                  _curIndex,
                  duration: Duration(microseconds: 300),
                  curve: Curves.easeInSine,
                );
              }
              break;
            case -1:
              if (_nextID > 0) {
                _goToBlogpost(_nextID);
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

  //渲染博文内容。
  Widget _showBlogpostContent() {
    return GestureDetector(
      child: Column(
        key: _passage,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: MarkdownGenerator(
          data: _rq.renderer.emojiUtil(
              _rq.renderer.extractFromTree(_blogpostInfo, ["Content"], "")),
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
            titleConfig: TitleConfig(),
            pConfig: PConfig(
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
                                FlutterI18n.translate(context, "login_to_read"),
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
                    return ShareCard(
                        _rq, node.attributes["type"], node.attributes["code"]);
                    break;
                  case "spoiler":
                    return Spoiler(content: node.attributes["content"]);
                    break;
                  case "ftemoji":
                    return FTEmoji(node.attributes["code"]);
                    break;
                  default:
                    return SizedBox(
                      width: 0,
                      height: 0,
                    );
                }
              },
            ),
            blockQuoteConfig: BlockQuoteConfig(),
            tableConfig: TableConfig(),
            preConfig: PreConfig(),
            olConfig: OlConfig(),
            ulConfig: UlConfig(),
          ),
        ).widgets,
      ),
    );
  }

  //渲染相关作品。
  Widget _showAppendix() {
    List<Widget> appendix = [];

    if (_relatedTopic.isNotEmpty)
      appendix.addAll([
        SizedBox(
          height: 12,
        ),
        _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "related_topic"),
          textColor: Theme.of(context).accentColor,
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return TopicView(value: {"TopicID": _relatedTopic["ID"]});
            }));
          },
          child: Card(
            child: Row(
              children: <Widget>[
                (_relatedTopic.containsKey("Cover") &&
                        _relatedTopic["Cover"] != null)
                    ? Flexible(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.network(
                            _relatedTopic["Cover"],
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
                        _relatedTopic["Title"],
                        textScaleFactor: 1.1,
                        maxLines: 2,
                      ),
                      subtitle: Text(_relatedTopic["UserName"]),
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

  //渲染评论列表。
  Widget _showComments() {
    List<Widget> comments = [];
    int curIndex = 0;

    comments.add(Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(FlutterI18n.translate(context, "sort_by") + ":"),
          FlatButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              _commentSortbyRating = !_commentSortbyRating;
              _rq.clearOrCreateList("Comments");
              _getComments(_commentID);
            },
            child: Text(
              FlutterI18n.translate(
                  context, _commentSortbyRating ? "rating" : "post_time"),
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
          ),
        ],
      ),
    ));

    _rq.getListByName("Comments").forEach((element) {
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
                    _rq.renderer.extractFromTree(element, ["ID"], 0), 6, "7",
                    (res) {
                  if (!mounted) return;
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
      ]);
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
                    _rq.renderer.extractFromTree(element, ["ID"], 0), 7, "7",
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
      ]);

      if (allowedOptions.contains("favorite"))
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
              }, params: {"Category": "comment"});
            }));

      if (allowedOptions.contains("reply"))
        actionBarItems.add(IconButton(
            icon: Icon(
              Icons.reply,
              color: Colors.black.withAlpha(137),
            ),
            onPressed: () {
              _postComment(
                  initText: "回复[" +
                      element["ID"].toString() +
                      "](/b/" +
                      _blogpostID.toString() +
                      "?comment=" +
                      element["ID"].toString() +
                      ") @" +
                      element["UserName"] +
                      " :\n");
            }));

      List<Widget> extendedActions = [];

      if (allowedOptions.contains("report"))
        extendedActions.add(ListTile(
          title: Text(FlutterI18n.translate(context, "report")),
          onTap: () {
            _rq.renderer.reportWindow("comment", element["ID"]);
          },
        ));

      if (allowedOptions.contains("delete"))
        extendedActions.add(
          ListTile(
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
                            _rq.manage(element["ID"], 9, "Comment", (res) {
                              Toast.show(
                                  FlutterI18n.translate(
                                      context, "successfully_deleted"),
                                  context);
                            }, params: {"Subaction": "delete", "Content": "0"});
                            Navigator.of(context).pop(this);
                          },
                          child:
                              Text(FlutterI18n.translate(context, "confirm")),
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
          ),
        );

      if (allowedOptions.contains("share"))
        extendedActions.addAll([
          ListTile(
            title: Text(FlutterI18n.translate(context, "copy_link")),
            onTap: () {
              Navigator.pop(context);
              _rq.share(
                  "clipboard",
                  "https://fimtale.com/b/" +
                      _blogpostID.toString() +
                      "?comment=" +
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
                  "https://fimtale.com/b/" +
                      _blogpostID.toString() +
                      "?comment=" +
                      element["ID"].toString(),
                  info: {
                    "title": _blogpostInfo["Title"],
                    "subtitle": _author["UserName"],
                    "content": markdownToHtml(element["Content"]) +
                        '<p style="text-align:right;">——' +
                        element["UserName"] +
                        '</p>'
                  });
            },
          )
        ]);

      if (extendedActions.length > 0)
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
        child: _rq.renderer.commentCard(
          element,
          (url) {
            _rq.launchURL(url, returnWhenCommentIDFounds: true).then((value) {
              if (value != null) {
                Map<String, dynamic> res =
                    Map<String, dynamic>.from(jsonDecode(value));
                if (res["IsCommentFound"]) {
                  if (res["Type"] == "blogpost" &&
                      res["MainID"] == _blogpostID) {
                    _isCommentShown = false;
                    _getComments(res["CommentID"]);
                  } else {
                    _rq.launchURL(url);
                  }
                }
              }
            });
          },
          actionBarItems: actionBarItems,
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: comments,
    );
  }
}
