import 'dart:convert';
import 'package:fimtale/views/lists/channel_folder.dart';
import 'package:fimtale/views/lists/channel_hash_topic.dart';
import 'package:fimtale/views/lists/user.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:sp_util/sp_util.dart';
import 'package:toast/toast.dart';

//标签、频道、用户三个页面的原理大同小异。仅在这里进行详细注释，就不在其它两个页面做多余注释了。

class ChannelView extends StatefulWidget {
  final value;

  ChannelView({Key key, @required this.value}) : super(key: key); //传入所必须的值。

  @override
  _ChannelViewState createState() => new _ChannelViewState(value); //再传给state。
}

class _ChannelViewState extends State<ChannelView>
    with TickerProviderStateMixin {
  var value;
  int _channelID = 0, //频道的ID。
      _commentID = 0, //需要跳转到的评论的ID。
      _curIndex = 0, //当前页面的index。页面要依靠index加载，因此这玩意还是挺重要的。
      _relatedChannelsLoadingStatus = 0; //相关频道是否已加载。
  String _curFolder = "", //当前所打开的文件夹。
      _curHashTopic = "", //当前所处于的话题。
      _topicQueryString = "", //作品的搜索关键词。
      _topicSortBy = "", //作品按照什么来排序。这两个都是由搜索页面返回来的值确定的。
      _formHash = ""; //这个东西与评论的发表有关。
  bool _isOperator = false, //是否是这个频道的管理。
      _commentSortbyRating = false, //评论是否按照评分进行排序。
      _commentOrderAsc = false, //评论是否升序排序。
      _commentBroadcastOnly = false, //是否只显示广播。
      _isCommentShown = false; //是否要高亮并且跳转到对应评论。
  List _collaborators = [], //协作者。
      _relatedChannels = []; //官方频道。
  Map<String, dynamic> _channelInfo = {}, //频道信息。
      _folders = {}; //文件夹。
  Map<int, GlobalKey> _comments = {}; //评论的key所存储的地方。
  TabController _tc; //页面控制器。
  ScrollController _sc = new ScrollController(); //滚动控制器。
  RequestHandler _rq; //请求处理器。

  //在构造函数里初始化整个类。
  _ChannelViewState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    _channelID = value["ChannelID"]; //赋值频道ID。
    if (value.containsKey("CommentID")) {
      _commentID = value["CommentID"];
      _curIndex = 1;
    }
    if (value.containsKey("Interface")) {
      switch (value["Interface"]) {
        case "comments":
          _curIndex = 1;
          break;
        case "followers":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return UserList(value: {
              "PageTitle": FlutterI18n.translate(context, "subscribers") +
                  " - " +
                  _rq.renderer.extractFromTree(_channelInfo, ["Name"], 0),
              "Url": "/api/v1/channel/" + _channelID.toString() + "/followers"
            });
          }));
          break;
      }
    } //通过传入的Interface值变换当前索引。
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: ["Topics", "Comments"]);
    _tc = new TabController(length: 3, initialIndex: _curIndex, vsync: this);
    _initPage();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        switch (_curIndex) {
          case 0:
            _getTopics();
            break;
          case 1:
            _getComments(0);
            break;
        }
      }
    }); //判断滚动时需要加载哪些内容。
    _tc.addListener(() {
      if (_tc.index.toDouble() == _tc.animation.value) {
        if (!mounted) return;
        setState(() {
          _curIndex = _tc.index;
          _commentID = 0;
        });
        _initPage();
      }
    }); //给TabController一个监听器，当页面改变的时候更新页面内容。
  }

  @override
  void dispose() {
    _tc.dispose();
    _sc.dispose();
    super.dispose();
  }

  //刷新页面。
  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Topics");
    _rq.clearOrCreateList("Comments");
    _initPage();
    return;
  }

  //初始化整个页面，包括加载必要的东西。
  _initPage() {
    switch (_curIndex) {
      case 0:
        if (_rq.getCurPage("Topics") <= 0) _getTopics();
        break;
      case 1:
        if (_rq.getCurPage("Comments") <= 0) _getComments(_commentID);
        break;
      case 2:
        if (_relatedChannels.isEmpty) _getRelatedChannels();
    }
  }

  //加载作品。
  _getTopics() async {
    Map<String, dynamic> params = {};
    if (_topicQueryString.length > 0) params["q"] = _topicQueryString;
    if (_topicSortBy.length > 0) params["sortby"] = _topicSortBy;
    _rq.updateListByName(
        "/api/v1/channel/" + _channelID.toString(),
        "Topics",
        (data) {
          _channelInfo = Map<String, dynamic>.from(data["ChannelInfo"]);
          var folders =
              _rq.renderer.extractFromTree(_channelInfo, ["Folders"], {});
          if (folders.isEmpty) folders = {};
          _folders = Map.from(folders);
          if (data["Collaborators"] != null)
            _collaborators = List.from(data["Collaborators"]);
          if (data["CurrentUser"].containsKey("FormHash"))
            _formHash = data["CurrentUser"]["FormHash"];
          _isOperator = (_channelInfo.containsKey("CreatorID") &&
                  _channelInfo["CreatorID"] == _rq.provider.UserID) ||
              _collaborators
                  .any((element) => element["ID"] == _rq.provider.UserID);
          return {
            "List": data["TopicsArray"],
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

  //加载评论。
  _getComments(int commentID) async {
    Map<String, dynamic> params = {};
    if (_curHashTopic.length > 0) params["hash_topic"] = _curHashTopic;
    if (_commentBroadcastOnly) params["broadcastonly"] = "1";
    if (_commentOrderAsc) params["order"] = "a";
    if (_commentSortbyRating) params["sortby"] = "rating";
    if (commentID > 0) {
      params["comment"] = commentID.toString();
      if (!mounted) return;
      setState(() {
        _commentID = commentID;
      });
    }
    _rq.updateListByName(
        "/api/v1/channel/" + _channelID.toString() + "/comments",
        "Comments",
        (data) {
          _channelInfo = Map<String, dynamic>.from(data["ChannelInfo"]);
          var folders =
              _rq.renderer.extractFromTree(_channelInfo, ["Folders"], {});
          if (folders.isEmpty) folders = {};
          _folders = Map.from(folders);
          if (data["Collaborators"] != null)
            _collaborators = List.from(data["Collaborators"]);
          if (data["CurrentUser"].containsKey("FormHash"))
            _formHash = data["CurrentUser"]["FormHash"];
          _isOperator = (_channelInfo.containsKey("CreatorID") &&
                  _channelInfo["CreatorID"] == _rq.provider.UserID) ||
              _collaborators
                  .any((element) => element["ID"] == _rq.provider.UserID);
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

  //加载相关频道。
  _getRelatedChannels() async {
    if (_relatedChannelsLoadingStatus == 1 || !mounted) return;
    setState(() {
      _relatedChannelsLoadingStatus = 1;
    });

    var result = await this
        ._rq
        .request("/api/v1/channel/" + _channelID.toString() + "/discover");

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _channelInfo = Map<String, dynamic>.from(result["ChannelInfo"]);
        if (result["Collaborators"] != null)
          _collaborators = List.from(result["Collaborators"]);
        _relatedChannels = result["ChannelsArray"];
        _relatedChannelsLoadingStatus = 2;
      });
    } else {
      print(result["ErrorMessage"]);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
      _relatedChannelsLoadingStatus = 0;
    }
  }

  //发表评论。
  _postComment({String initText}) {
    bool broadcast = false;
    _rq.renderer
        .inputModal(
      draftKey: "comment_channel_" + _channelID.toString(),
      hint: FlutterI18n.translate(context, "post_comment") +
          "(" +
          FlutterI18n.translate(context, "use_markdown") +
          ")",
      text: initText,
      options: ["emoji", "image", "at", "spoiler"],
      checkBoxConfig: _isOperator
          ? {
              "Label": FlutterI18n.translate(context, "broadcast"),
              "Value": broadcast,
              "OnCheck": (isChecked) {
                broadcast = isChecked;
              }
            }
          : null,
    )
        .then((value) async {
      if (value != null && value.length > 0) {
        _rq.uploadPost("/new/comment", {
          "FormHash": _formHash,
          "Id": _channelID,
          "Target": "channel",
          "Content": markdownToHtml(value),
          "IsBroadcast": broadcast
        }, onSubmit: () {
          Toast.show(FlutterI18n.translate(context, "posting"), context);
        }, onSuccess: (link) async {
          SpUtil.remove("draft_comment_channel_" + _channelID.toString());
          _rq.launchURL(link, returnWhenCommentIDFounds: true).then((value) {
            if (value != null) {
              Map<String, dynamic> res =
                  Map<String, dynamic>.from(jsonDecode(value));
              if (res["IsCommentFound"]) {
                if (res["Type"] == "channel" && res["MainID"] == _channelID) {
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

  //在搜索页面得到搜索相关信息后回传给这个函数，来处理搜索文本。
  _processSearchText(var searchInfoStr) {
    Map<String, dynamic> searchInfo =
        Map<String, dynamic>.from(jsonDecode(searchInfoStr));
    if (searchInfo["Search"]) {
      _topicQueryString = searchInfo["Q"];
      _topicSortBy = searchInfo["SortBy"];
      _rq.clearOrCreateList("Topics");
      _getTopics();
    }
  }

  //构造整个页面。
  @override
  Widget build(BuildContext context) {
    String background =
            _rq.renderer.extractFromTree(_channelInfo, ["Background"], ""),
        prefix = "";
    switch (_curIndex) {
      case 0:
        if (_curFolder.length > 0) prefix = _curFolder + " - ";
        break;
      case 1:
        if (_curHashTopic.length > 0) prefix = _curHashTopic + " - ";
        break;
    } //页面标题。
    List<Widget> collabChips = [];
    if (_collaborators.length > 0) {
      collabChips.add(Icon(
        Icons.people_outline,
        color: Colors.indigo,
      ));
      _collaborators.forEach((element) {
        collabChips.add(GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return UserView(value: {"UserName": element["UserName"]});
            }));
          },
          child: Chip(
            label:
                Text(_rq.renderer.extractFromTree(element, ["UserName"], "")),
            avatar: _rq.renderer.userAvatar(
                _rq.renderer.extractFromTree(element, ["UserID"], 0)),
            padding: EdgeInsets.zero,
          ),
        ));
      });
    } //给协作者的小片渲染好。

    List<String> allowedOptions = List<String>.from(
        _rq.renderer.extractFromTree(_channelInfo, ["AllowedOptions"], []));

    List<Widget> appBarActions = [];
    if (_curIndex == 0) {
      if (_folders.isNotEmpty)
        appBarActions.add(IconButton(
          icon: Icon(Icons.folder_open),
          onPressed: () async {
            String curFolder = await Navigator.push(context,
                MaterialPageRoute(builder: (context) {
              return ChannelFolder(value: {
                "ChannelName":
                    _rq.renderer.extractFromTree(_channelInfo, ["Name"], ""),
                "Folders": Map.from(_folders),
              });
            }));
            if (curFolder != null && curFolder.length > 0) {
              if (!mounted) return;
              setState(() {
                _curFolder = curFolder;
                _rq.clearOrCreateList("Topics");
                _getTopics();
              });
            }
          },
        )); //频道文件夹。
      appBarActions.add(IconButton(
        icon: Icon(Icons.search),
        onPressed: () async {
          String searchInfo = await showSearch(
              context: context,
              delegate: SearchPage(
                  currentSearchTarget: "topic",
                  template: "topic",
                  queryString: _topicQueryString,
                  currentSortBy: _topicSortBy,
                  openNewPage: false));
          _processSearchText(searchInfo);
        },
      )); //频道的搜索功能。
    }
    if (allowedOptions.contains("favorite"))
      appBarActions.add(IconButton(
        icon: Icon(_channelInfo["IsFavorite"]
            ? Icons.favorite
            : Icons.favorite_border),
        onPressed: () {
          _rq.manage(
              _rq.renderer.extractFromTree(_channelInfo, ["ID"], 0), 4, "6",
              (res) {
            if (!mounted) return;
            setState(() {
              if (_channelInfo["IsFavorite"])
                _channelInfo["Followers"]--;
              else
                _channelInfo["Followers"]++;
              _channelInfo["IsFavorite"] = !_channelInfo["IsFavorite"];
            });
          });
        },
      )); //收藏这个频道。

    List<PopupMenuItem<String>> actionMenu = [];

    if (allowedOptions.contains("edit"))
      actionMenu.addAll([
        PopupMenuItem<String>(
          child: Text(FlutterI18n.translate(context, "edit_channel_name")),
          value: "edit_name",
        ),
        PopupMenuItem<String>(
          child:
              Text(FlutterI18n.translate(context, "edit_channel_description")),
          value: "edit_desc",
        ),
        PopupMenuItem<String>(
          child: Text(FlutterI18n.translate(context, "upload_cover")),
          value: "edit_cover",
        ),
        PopupMenuItem<String>(
          child: Text(FlutterI18n.translate(context, "reset_cover")),
          value: "reset_cover",
        ),
      ]); //编辑四联：编辑频道名、编辑频道简介、上传频道封面、重置频道封面。
    if (allowedOptions.contains("delete"))
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "delete")),
        value: "delete",
      )); //删除。
    if (allowedOptions.contains("report"))
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "report")),
        value: "report",
      )); //举报。

    if (actionMenu.length > 0) //如果这里面真有一个被渲染的话，那就直接上右上角省略号。
      appBarActions.add(PopupMenuButton(
        itemBuilder: (BuildContext context) => actionMenu,
        onSelected: (String action) {
          switch (action) { //根据用户所选择的不同的action执行不同的部分。
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
                    _rq.manage(_channelID, 9, "Channel", (message) {
                      Toast.show("successfully_deleted", context);
                      Navigator.pop(context);
                    }, params: {"Subaction": "delete"});
                    break;
                }
              });
              break;
            case "report":
              _rq.renderer.reportWindow("channel", _channelID);
              break;
            case "edit_name":
              _rq.renderer
                  .inputModal(
                hint: FlutterI18n.translate(context, "edit_channel_name"),
                buttonText: FlutterI18n.translate(context, "submit"),
                text: _channelInfo["Name"],
                maxLength: 20,
              )
                  .then((value) {
                if (value != null &&
                    value.length > 0 &&
                    value != _channelInfo["Name"])
                  _rq.manage(_channelID, 9, "Channel", (res) {
                    if (!mounted) return;
                    setState(() {
                      _channelInfo["Name"] = res["Message"];
                    });
                  }, params: {"Subaction": "editName", "Content": value});
              });
              break;
            case "edit_desc":
              _rq.renderer
                  .inputModal(
                hint:
                    FlutterI18n.translate(context, "edit_channel_description"),
                buttonText: FlutterI18n.translate(context, "submit"),
                text: _channelInfo["Intro"],
                maxLength: 20,
              )
                  .then((value) {
                if (value != null &&
                    value.length > 0 &&
                    value != _channelInfo["Intro"])
                  _rq.manage(_channelID, 9, "Channel", (res) {
                    if (!mounted) return;
                    setState(() {
                      _channelInfo["Intro"] = res["Message"];
                    });
                  }, params: {
                    "Subaction": "editDescription",
                    "Content": value
                  });
              });
              break;
            case "edit_cover":
              ImagePicker.pickImage(source: ImageSource.gallery)
                  .then((image) => image != null
                      ? _rq.uploadImage2ImgBox(image).then((value) {
                          if (value != null)
                            _rq.manage(_channelID, 9, "Channel", (res) {
                              if (!mounted) return;
                              setState(() {
                                _channelInfo["Background"] = value;
                              });
                            }, params: {
                              "Subaction": "uploadCover",
                              "Content": value
                            });
                        })
                      : null);
              break;
            case "reset_cover":
              _rq.manage(_channelID, 9, "Channel", (res) {
                if (!mounted) return;
                setState(() {
                  _channelInfo["Background"] = null;
                });
              }, params: {"Subaction": "uploadCover", "Content": ""});
              break;
          }
        },
      ));

    //这个函数在build函数执行之后会再执行一遍。
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
        _sc.jumpTo(target - 150);
        _isCommentShown = true;
      }
    });

    //返回所渲染好的组件。
    return new Scaffold(
      body: Container(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _sc,
            slivers: <Widget>[
              SliverAppBar( //SilverAppBar可以随着页面的滚动而慢慢变窄最后回归到正常的AppBar大小。用这个可以做一个类似于网x云音乐的界面。
                expandedHeight: collabChips.length > 0 ? 480.0 : 430.0,
                floating: false,
                pinned: true,
                title: Text(prefix +
                    _rq.renderer.extractFromTree(_channelInfo, ["Name"],
                        FlutterI18n.translate(context, "channels")) +
                    (_curIndex == 0 && _topicQueryString.length > 0
                        ? "(" +
                            FlutterI18n.translate(context, "search") +
                            ":" +
                            _topicQueryString +
                            ")"
                        : "")), //页面的标题。
                actions: appBarActions, //页面右上角那栏。
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.asset(
                        "assets/images/channel_cover.jpg",
                        fit: BoxFit.cover,
                      ),
                      (background != null && background.length > 0)
                          ? Image.network(
                              background,
                              fit: BoxFit.cover,
                            )
                          : SizedBox(
                              height: 0,
                            ),
                      Container(
                        color: Colors.black.withAlpha(127),
                      ), //背景三连：默认背景、用户背景、黑色遮罩。
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              _rq.renderer
                                  .extractFromTree(_channelInfo, ["Name"], ""),
                              textScaleFactor: 2,
                              style: TextStyle(color: Colors.white),
                            ), //频道名。
                            Text(
                              _rq.renderer
                                  .extractFromTree(_channelInfo, ["Intro"], ""),
                              style: TextStyle(color: Colors.white),
                            ), //频道简介。
                            SizedBox(
                              height: 10,
                            ),
                            Wrap(
                              spacing: 5,
                              runSpacing: 0,
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.perm_identity,
                                  color: Colors.indigo,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(context,
                                        MaterialPageRoute(builder: (_context) {
                                      return UserView(value: {
                                        "UserName": _channelInfo["CreatorName"]
                                      });
                                    }));
                                  },
                                  child: Chip(
                                    label: Text(_rq.renderer.extractFromTree(
                                        _channelInfo, ["CreatorName"], "")),
                                    avatar: _rq.renderer.userAvatar(_rq.renderer
                                        .extractFromTree(
                                            _channelInfo, ["CreatorID"], 0)),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ), //频道创建者。
                            collabChips.length > 0
                                ? Wrap(
                                    spacing: 5,
                                    runSpacing: 0,
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: collabChips,
                                  )
                                : SizedBox(
                                    height: 0,
                                  ), //如果有频道协作者，显示上去；没有就算了。
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 0,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.schedule,
                                    color: Colors.blue[600],
                                  ),
                                  Text(
                                    _rq.renderer.formatTime(_rq.renderer
                                        .extractFromTree(
                                            _channelInfo, ["LastTime"], 0)),
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (_channelInfo.isNotEmpty) {
                                        Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (_context) {
                                          return UserList(value: {
                                            "PageTitle": FlutterI18n.translate(
                                                    context, "subscribers") +
                                                " - " +
                                                _rq.renderer.extractFromTree(
                                                    _channelInfo, ["Name"], ""),
                                            "Url": "/api/v1/channel/" +
                                                _channelID.toString() +
                                                "/followers"
                                          });
                                        }));
                                      }
                                    },
                                    child: Wrap(
                                      spacing: 3,
                                      runSpacing: 0,
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: <Widget>[
                                        Icon(
                                          Icons.favorite,
                                          color: Colors.red[300],
                                        ),
                                        Text(
                                          _rq.renderer
                                              .extractFromTree(_channelInfo,
                                                  ["Followers"], 0)
                                              .toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      if (_curIndex == 1) {
                                        String res = await Navigator.push(
                                            context, MaterialPageRoute(
                                                builder: (context) {
                                          return ChannelHashTopic(
                                              value: {"ChannelID": _channelID});
                                        }));
                                        if (res != null && res.length > 0) {
                                          _curHashTopic = res;
                                          _rq.clearOrCreateList("Comments");
                                          _getComments(0);
                                        }
                                      }
                                    },
                                    child: Wrap(
                                      spacing: 3,
                                      runSpacing: 0,
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: <Widget>[
                                        Icon(
                                          Icons.local_offer,
                                          color: Colors.deepPurple[400],
                                        ),
                                        Text(
                                          _rq.renderer
                                              .extractFromTree(_channelInfo,
                                                  ["HashTopics"], 0)
                                              .toString(),
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ), //频道相关信息，可以点击。
                            allowedOptions.contains("upvote") ||
                                    allowedOptions.contains("downvote")
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      FlatButton(
                                        onPressed: () {
                                          _rq.manage(
                                              _rq.renderer.extractFromTree(
                                                  _channelInfo, ["ID"], 0),
                                              6,
                                              "6", (res) {
                                            if (!mounted) return;
                                            setState(() {
                                              if (_channelInfo["MyVote"] !=
                                                  "upvote") {
                                                if (_channelInfo["MyVote"] ==
                                                    "downvote")
                                                  _channelInfo["Downvotes"]--;
                                                _channelInfo["MyVote"] =
                                                    "upvote";
                                                _channelInfo["Upvotes"]++;
                                              } else {
                                                _channelInfo["MyVote"] = null;
                                                _channelInfo["Upvotes"]--;
                                              }
                                            });
                                          });
                                        },
                                        child: Wrap(
                                          spacing: 3,
                                          runSpacing: 0,
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: <Widget>[
                                            Icon(
                                              Icons.thumb_up,
                                              color: _rq.renderer
                                                          .extractFromTree(
                                                              _channelInfo,
                                                              ["MyVote"],
                                                              "") ==
                                                      "upvote"
                                                  ? Colors.green
                                                  : Colors.white,
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Text(
                                              _rq.renderer
                                                  .extractFromTree(_channelInfo,
                                                      ["Upvotes"], 0)
                                                  .toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            )
                                          ],
                                        ),
                                      ), //点赞按钮。
                                      FlatButton(
                                        onPressed: () {
                                          _rq.manage(
                                              _rq.renderer.extractFromTree(
                                                  _channelInfo, ["ID"], 0),
                                              7,
                                              "6", (res) {
                                            if (!mounted) return;
                                            setState(() {
                                              if (_channelInfo["MyVote"] !=
                                                  "downvote") {
                                                if (_channelInfo["MyVote"] ==
                                                    "upvote")
                                                  _channelInfo["Upvotes"]--;
                                                _channelInfo["MyVote"] =
                                                    "downvote";
                                                _channelInfo["Downvotes"]++;
                                              } else {
                                                _channelInfo["MyVote"] = null;
                                                _channelInfo["Downvotes"]--;
                                              }
                                            });
                                          });
                                        },
                                        child: Wrap(
                                          spacing: 3,
                                          runSpacing: 0,
                                          alignment: WrapAlignment.center,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: <Widget>[
                                            Icon(
                                              Icons.thumb_down,
                                              color: _rq.renderer
                                                          .extractFromTree(
                                                              _channelInfo,
                                                              ["MyVote"],
                                                              "") ==
                                                      "downvote"
                                                  ? Colors.red
                                                  : Colors.white,
                                            ),
                                            SizedBox(
                                              width: 10,
                                            ),
                                            Text(
                                              _rq.renderer
                                                  .extractFromTree(_channelInfo,
                                                      ["Downvotes"], 0)
                                                  .toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            )
                                          ],
                                        ),
                                      ) //点踩按钮。
                                    ],
                                  )
                                : SizedBox(height: 0),
                            SizedBox(
                              height: 32,
                            ) //这个东西是撑住防止信息和下面的tab叠一起的。
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: TabBar(
                  controller: _tc,
                  isScrollable: true,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white,
                  indicatorWeight: 2,
                  //设置所有的tab
                  tabs: <Widget>[
                    Tab(
                        text: FlutterI18n.translate(context, "topics") +
                            " " +
                            _rq.renderer
                                .extractFromTree(
                                    _channelInfo, ["Collections"], 0)
                                .toString()),
                    Tab(
                        text: FlutterI18n.translate(context, "comments") +
                            " " +
                            _rq.renderer
                                .extractFromTree(_channelInfo, ["Comments"], 0)
                                .toString()),
                    Tab(text: FlutterI18n.translate(context, "discover")),
                  ],
                ),
              ), //页面导航。
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _showContent(context),
                ),
              ), //页面内容。
            ],
          ),
        ),
      ),
      floatingActionButton: _curIndex == 1 && allowedOptions.contains("comment")
          ? FloatingActionButton(
              child: Icon(Icons.comment),
              onPressed: _postComment,
            )
          : null, //如果在评论页面，得渲染一个评论按钮。
    );
  }

  //根据不同的页面展示不同的内容。
  List<Widget> _showContent(BuildContext context) {
    List<Widget> contentList = [];
    switch (_curIndex) {
      case 0: //作品界面。
        if (_curFolder.length > 0) {
          Map curFolderInfo = Map.from(
              _rq.renderer.extractFromTree(_folders, [_curFolder], {}));
          contentList.add(ListTile(
            title: Text(_curFolder),
            subtitle: Text(curFolderInfo["Collections"].toString() +
                FlutterI18n.translate(context, "topics") +
                " " +
                (curFolderInfo["IsPublic"]
                    ? (FlutterI18n.translate(context, "shared_folder"))
                    : "") +
                (curFolderInfo.containsKey("BallotInfo")
                    ? ("," +
                        FlutterI18n.translate(context, "holding_ballot") +
                        " " +
                        FlutterI18n.translate(
                            context, "bits_each_time", translationParams: {
                          "Bits": curFolderInfo["BallotInfo"]["Bits"].toString()
                        }) +
                        "," +
                        FlutterI18n.translate(context, "times_limit",
                            translationParams: {
                              "Times": curFolderInfo["BallotInfo"]
                                      ["MaxBallotPerPerson"]
                                  .toString()
                            }))
                    : "")),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _curFolder = "";
                  _rq.clearOrCreateList("Topics");
                  _getTopics();
                });
              },
            ),
          ));
        }
        contentList.addAll(_rq.renderer.topicList(_rq.getListByName("Topics")));
        if (_rq.isLoading("Topics"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 1: //评论界面。
        int curIndex = 0;

        if (_curHashTopic.length > 0) {
          contentList.add(ListTile(
            title: Text(_curHashTopic),
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                _curHashTopic = "";
                _rq.clearOrCreateList("Comments");
                _getComments(0);
              },
            ),
          ));
        }

        contentList.add(Container(
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
                  _commentOrderAsc = !_commentOrderAsc;
                  _rq.clearOrCreateList("Comments");
                  _getComments(_commentID);
                },
                child: Text(
                  FlutterI18n.translate(
                      context, _commentOrderAsc ? "ascending" : "descending"),
                  style: TextStyle(color: Colors.green[700]),
                ),
              ),
              SizedBox(
                width: 5,
              ),
              Text(FlutterI18n.translate(context, "view") + ":"),
              FlatButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _commentBroadcastOnly = !_commentBroadcastOnly;
                  _rq.clearOrCreateList("Comments");
                  _getComments(_commentID);
                },
                child: Text(
                  _commentBroadcastOnly
                      ? FlutterI18n.translate(context, "broadcast_only")
                      : FlutterI18n.translate(context, "all_content"),
                  style: TextStyle(color: Colors.amber[700]),
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
                  color:
                      _rq.renderer.extractFromTree(element, ["MyVote"], null) ==
                              "upvote"
                          ? Colors.green
                          : Colors.black.withAlpha(137),
                ),
                onPressed: () {
                  if (allowedOptions.contains("upvote"))
                    _rq.manage(_rq.renderer.extractFromTree(element, ["ID"], 0),
                        6, "7", (res) {
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
                        _rq.setListItemByNameAndIndex(
                            "Comment", index, element);
                      });
                    });
                }),
            Text(_rq.renderer
                .extractFromTree(element, ["Upvotes"], 0)
                .toString()),
            SizedBox(
              width: 5,
            )
          ]);
          actionBarItems.addAll([
            IconButton(
                icon: Icon(
                  Icons.thumb_down,
                  color:
                      _rq.renderer.extractFromTree(element, ["MyVote"], null) ==
                              "downvote"
                          ? Colors.red
                          : Colors.black.withAlpha(137),
                ),
                onPressed: () {
                  if (allowedOptions.contains("downvote"))
                    _rq.manage(_rq.renderer.extractFromTree(element, ["ID"], 0),
                        7, "7", (res) {
                      if (!mounted) return;
                      setState(() {
                        if (element["MyVote"] != "downvote") {
                          if (element["MyVote"] == "upvote")
                            element["Upvotes"]--;
                          element["MyVote"] = "downvote";
                          element["Downvotes"]++;
                        } else {
                          element["MyVote"] = null;
                          element["Downvotes"]--;
                        }
                        _rq.setListItemByNameAndIndex(
                            "Comment", index, element);
                      });
                    });
                }),
            Text(_rq.renderer
                .extractFromTree(element, ["Downvotes"], 0)
                .toString()),
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
                  color: _rq.renderer
                          .extractFromTree(element, ["IsFavorite"], false)
                      ? Colors.lightBlue
                      : Colors.black.withAlpha(137),
                ),
                onPressed: () {
                  _rq.manage(
                      _rq.renderer.extractFromTree(element, ["ID"], 0), 4, "4",
                      (res) {
                    if (!mounted) return;
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
                          "](/channel/" +
                          _channelID.toString().toString() +
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
                _rq.renderer.reportWindow("post", element["ID"]);
              },
            ));

          if (allowedOptions.contains("delete"))
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
                              _rq.manage(element["ID"], 9, "Comment", (res) {
                                Toast.show(
                                    FlutterI18n.translate(
                                        context, "successfully_deleted"),
                                    context);
                              }, params: {
                                "Subaction": "delete",
                                "Content": "0"
                              });
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
                            borderRadius:
                                BorderRadius.all(Radius.circular(10))),
                      );
                    });
              },
            ));

          if (allowedOptions.contains("share"))
            extendedActions.addAll([
              ListTile(
                title: Text(FlutterI18n.translate(context, "copy_link")),
                onTap: () {
                  Navigator.pop(context);
                  _rq.share(
                      "clipboard",
                      "https://fimtale.com/channel/" +
                          _channelID.toString() +
                          "?comment=" +
                          element["ID"].toString());
                },
              ),
              ListTile(
                title: Text(
                    FlutterI18n.translate(context, "generate_share_ticket")),
                onTap: () {
                  Navigator.pop(context);
                  _rq.share(
                      "share_ticket",
                      "https://fimtale.com/b/" +
                          _channelID.toString() +
                          "?comment=" +
                          element["ID"].toString(),
                      info: {
                        "title": _channelInfo["Title"],
                        "subtitle": _channelInfo["CreatorName"],
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

          contentList.add(Container(
            key: temp,
            child: _rq.renderer.commentCard(
              element,
              (url) {
                _rq
                    .launchURL(url, returnWhenCommentIDFounds: true)
                    .then((value) {
                  if (value != null) {
                    Map<String, dynamic> res =
                        Map<String, dynamic>.from(jsonDecode(value));
                    if (res["IsCommentFound"]) {
                      if (res["Type"] == "channel" &&
                          res["MainID"] == _channelID) {
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
              color: _commentID == element["ID"]
                  ? Colors.yellow.withAlpha(31)
                  : null,
            ),
          ));
          _comments[element["ID"]] = temp;
          curIndex++;
        });

        if (_rq.isLoading("Comments"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Comments") >= _rq.getTotalPage("Comments"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 2: //相关频道界面。
        _relatedChannels.forEach((element) {
          contentList.add(ListTile(
            leading: CircleAvatar(
              backgroundImage: element["Background"] != null
                  ? NetworkImage(element["Background"])
                  : AssetImage("assets/images/channel_cover_square.jpg"),
            ),
            title: Text(
              _rq.renderer.extractFromTree(element, ["Name"], ""),
              maxLines: 1,
            ),
            subtitle: Text(
              _rq.renderer.extractFromTree(element, ["CreatorName"], ""),
              maxLines: 1,
            ),
          ));
        });
        break;
    }
    return contentList;
  }
}
