import 'package:fimtale/views/viewers/tag.dart';
import 'package:flutter/material.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class FavoriteList extends StatefulWidget {
  final value;

  FavoriteList({Key key, this.value}) : super(key: key);

  @override
  _FavoriteListState createState() => new _FavoriteListState(value);
}

class _FavoriteListState extends State<FavoriteList>
    with TickerProviderStateMixin {
  var value;
  int _curIndex = 0;
  ScrollController _sc1 = new ScrollController(),
      _sc2 = new ScrollController(),
      _sc3 = new ScrollController(),
      _sc4 = new ScrollController(),
      _sc5 = new ScrollController();
  List<String> _favTags = [];
  TabController _tc;
  RequestHandler _rq;

  _FavoriteListState(value) {
    this.value = value;
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: [
      "Topics",
      "Blogposts",
      "Comments",
      "TagTopics",
      "Channels"
    ]);
    _tc = new TabController(length: 5, vsync: this);
    _sc1.addListener(() {
      if (_sc1.position.pixels >= _sc1.position.maxScrollExtent - 400) {
        _getFavList(true);
      }
    });
    _sc2.addListener(() {
      if (_sc2.position.pixels >= _sc2.position.maxScrollExtent - 400) {
        _getFavList(true);
      }
    });
    _sc3.addListener(() {
      if (_sc3.position.pixels >= _sc3.position.maxScrollExtent - 400) {
        _getFavList(true);
      }
    });
    _sc4.addListener(() {
      if (_sc4.position.pixels >= _sc4.position.maxScrollExtent - 400) {
        _getFavList(true);
      }
    });
    _sc5.addListener(() {
      if (_sc5.position.pixels >= _sc5.position.maxScrollExtent - 400) {
        _getFavList(true);
      }
    });
    _tc.addListener(() {
      if (_tc.index.toDouble() == _tc.animation.value) {
        setState(() {
          _curIndex = _tc.index;
        });
        _getFavList(false);
      }
    });
    _getFavList(false);
  }

  @override
  void dispose() {
    _tc.dispose();
    _sc1.dispose();
    _sc2.dispose();
    _sc3.dispose();
    _sc4.dispose();
    _sc5.dispose();
    super.dispose();
  }

  //刷新页面
  Future<Null> _refresh() async {
    _rq.getListNames().forEach((element) {
      _rq.clearOrCreateList(element);
    });
    _favTags = [];
    _getFavList(false);
    return;
  }

  //根据现在的index获取当前页面的信息。
  _getFavList(bool withForce) {
    switch (_curIndex) {
      case 0:
        if (_rq.getCurPage("Topics") <= 0 || withForce)
          _getSingleFavList("topics", "Topics", "TopicsArray");
        break;
      case 1:
        if (_rq.getCurPage("Blogposts") <= 0 || withForce)
          _getSingleFavList("blogposts", "Blogposts", "BlogpostsArray");
        break;
      case 2:
        if (_rq.getCurPage("Comments") <= 0 || withForce)
          _getSingleFavList("comments", "Comments", "CommentsArray");
        break;
      case 3:
        if (_rq.getCurPage("TagTopics") <= 0 || withForce)
          _getSingleFavList("tags", "TagTopics", "TopicsArray");
        break;
      case 4:
        if (_rq.getCurPage("Channels") <= 0 || withForce)
          _getSingleFavList("channels", "Channels", "ChannelsArray");
        break;
    }
  }

  //从站点上获取收藏信息。
  _getSingleFavList(String path, String tableName, String arrayName) async {
    _rq.updateListByName("/api/v1/favorites/" + path, tableName, (data) {
      if (data.containsKey("FavTags"))
        _favTags = List<String>.from(data["FavTags"]);
      return {
        "List": data[arrayName],
        "CurPage": data["Page"],
        "TotalPage": data["TotalPage"]
      };
    }, beforeRequest: () {
      setState(() {});
    }, afterUpdate: (list) {
      setState(() {});
    }, onError: (err) {
      Toast.show(err, context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
    });
  }

  //显示收藏信息。
  List<Widget> _displayFavList(int index) {
    List<Widget> contentList = [];
    switch (index) {
      case 0:
        contentList.addAll(_rq.renderer.topicList(_rq.getListByName("Topics")));
        if (_rq.isLoading("Topics"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 1:
        contentList
            .addAll(_rq.renderer.blogpostList(_rq.getListByName("Blogposts")));
        if (_rq.isLoading("Blogposts"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Blogposts") >= _rq.getTotalPage("Blogposts"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 2:
        _rq.getListByName("Comments").forEach((element) {
          contentList.add(GestureDetector(
            onTap: () {
              String url = "";
              switch (element["Type"]) {
                case "blog":
                  url = "/b/" +
                      element["TargetID"].toString() +
                      "?comment=" +
                      element["ID"].toString();
                  break;
                case "channel":
                  url = "/channel/" +
                      element["TargetID"].toString() +
                      "?comment=" +
                      element["ID"].toString();
                  break;
                case "topic":
                  url = "/goto/" +
                      element["TargetID"].toString() +
                      "-" +
                      element["ID"].toString();
                  break;
              }
              _rq.launchURL(url);
            },
            child: AbsorbPointer(
              child: Container(
                padding: EdgeInsets.all(12),
                child: _rq.renderer.commentCard(element, (url) {}),
              ),
            ),
          ));
        });
        if (_rq.isLoading("Comments"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Comments") >= _rq.getTotalPage("Comments"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 3:
        contentList.add(Card(
          margin: EdgeInsets.all(12),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _rq.renderer.pageSubtitle(
                    FlutterI18n.translate(context, "favorite_tags"),
                    textColor: Theme.of(context).accentColor),
                Wrap(
                  spacing: 5,
                  children: _rq.renderer.tags2Chips(_favTags, onTap: (element) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return TagView(value: {"TagName": element["Name"]});
                    }));
                  }),
                ),
              ],
            ),
          ),
        ));
        contentList
            .addAll(_rq.renderer.topicList(_rq.getListByName("TagTopics")));
        if (_rq.isLoading("TagTopics"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("TagTopics") >= _rq.getTotalPage("TagTopics"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 4:
        contentList
            .addAll(_rq.renderer.channelList(_rq.getListByName("Channels")));
        if (_rq.isLoading("Channels"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Channels") >= _rq.getTotalPage("Channels"))
          contentList.add(_rq.renderer.endNotice());
        break;
    }
    return contentList;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "favorites")),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(context: context, delegate: SearchPage());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        child: Container(
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: <Widget>[
                Container(
                  child: Material(
                    child: TabBar(
                      controller: _tc,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 2.0,
                      tabs: <Widget>[
                        Tab(text: FlutterI18n.translate(context, "topics")),
                        Tab(text: FlutterI18n.translate(context, "blogposts")),
                        Tab(text: FlutterI18n.translate(context, "comments")),
                        Tab(text: FlutterI18n.translate(context, "tags")),
                        Tab(text: FlutterI18n.translate(context, "channels"))
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: TabBarView(
                    controller: _tc,
                    children: <Widget>[
                      ListView(
                        children: _displayFavList(0),
                        controller: _sc1,
                      ),
                      ListView(
                        children: _displayFavList(1),
                        controller: _sc2,
                      ),
                      ListView(
                        children: _displayFavList(2),
                        controller: _sc3,
                      ),
                      ListView(
                        children: _displayFavList(3),
                        controller: _sc4,
                      ),
                      ListView(
                        children: _displayFavList(4),
                        controller: _sc5,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        onRefresh: _refresh,
      ),
    );
  }
}
