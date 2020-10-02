import 'dart:async';
import 'dart:ui';
import 'package:badges/badges.dart';
import 'package:fimtale/views/custom/create_channel.dart';
import 'package:fimtale/views/custom/editor.dart';
import 'package:fimtale/views/custom/settings.dart';
import 'package:fimtale/views/lists/examination.dart';
import 'package:fimtale/views/lists/favorite.dart';
import 'package:fimtale/views/lists/history.dart';
import 'package:fimtale/views/lists/notification.dart';
import 'package:fimtale/views/others/about_page.dart';
import 'package:fimtale/views/viewers/channel.dart';
import 'package:fimtale/views/viewers/tag.dart';
import 'package:fimtale/views/viewers/topic.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:fimtale/views/lists/tag.dart';
import 'package:flutter/material.dart';
import 'package:fimtale/views/custom/login.dart';
import 'package:fimtale/views/lists/blogpost.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';
import 'channel.dart';

//主页视图，在列表视图中算是比较复杂的一块，因此这里单独拉出来做注释。
class HomePage extends StatefulWidget {
  final value;

  //在实例化HomePage类的时候就传入value做参数，同时再在构造状态时将value作参数传进去。
  HomePage({Key key, this.value}) : super(key: key);

  @override
  _HomePageState createState() => new _HomePageState(value);
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  var value;
  int _curIndex = 0, _newUpdatesNum = 0, _newNotificationNumInactive = 0;
  List _recommendArr = [], //编辑精选
      _announcementArr = [], //公告
      _hotBlogPostsArr = [], //热门博文
      _hotChannelsArr = []; //热门频道
  Map<String, dynamic> _tempBadgeNums = {}; //这些数值决定是否显示小红点
  bool _isActive = true, //应用是否在最前
      _isLoading1 = false, //主页内容（1/2）正在加载
      _isRefreshing1 = false, //主页内容（1/2）正在刷新
      _isLoading2 = false, //主页内容（2/2）正在加载
      _isRefreshing2 = false; //主页内容（2/2）正在刷新
  ScrollController _sc1 = new ScrollController(),
      _sc2 = new ScrollController(),
      _sc3 = new ScrollController(),
      _sc4 = new ScrollController(),
      _sc5 = new ScrollController(); //每个页面的滚动控制器。
  TabController _tc1, _tc2; //“作品”、“发现”两个页面的tab控制器。
  Timer _rqt; //用来请求新消息的定时器。
  RequestHandler _rq; //请求处理器。

  _HomePageState(value) {
    this.value = value;
  }

  //初始化整个首页的状态。
  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: [
      "NewlyPost",
      "NewlyUpdate",
      "ForumPosts",
      "RecommendTopics",
      "Updates"
    ]); //初始化请求处理器
    _tc1 = new TabController(length: 2, vsync: this);
    _tc2 = new TabController(length: 2, vsync: this);
    _getHomepageInfo1();
    _getHomepageInfo2(); //加载首页内容（总共两个方法）
    if (_curIndex == 3 && _rq.provider.UserID > 0) _getUpdates(); //获取更新
    _sc1.addListener(() {
      if (_sc1.position.pixels >= _sc1.position.maxScrollExtent - 400)
        _justUpdateRecommendTopics();
    });
    _sc2.addListener(() {
      if (_sc2.position.pixels >= _sc2.position.maxScrollExtent - 400)
        _justUpdateTopicsArray(true);
    });
    _sc3.addListener(() {
      if (_sc3.position.pixels >= _sc3.position.maxScrollExtent - 400)
        _justUpdateTopicsArray(false);
    });
    _sc4.addListener(() {
      if (_sc4.position.pixels >= _sc4.position.maxScrollExtent - 400)
        _justUpdateForumPostsArray();
    });
    _sc5.addListener(() {
      if (_sc5.position.pixels >= _sc5.position.maxScrollExtent - 400)
        _getUpdates();
    }); //这上面5段相似的代码都是分情况分页面加载不同的内容（近日热门、最近更新、帖子等）
    WidgetsBinding.instance.addObserver(this); //这个可以用来检测APP的状态。
    _requestNewNotifications();
    _setNewNotificationRequestInterval(true); //获取新消息的数目，并且设置隔一段时间就获取一次。
  }

  //清除掉首页时所执行的代码。
  @override
  void dispose() {
    _tc1.dispose();
    _tc2.dispose();
    _sc1.dispose();
    _sc2.dispose();
    _sc3.dispose();
    _sc4.dispose();
    _sc5.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  //当APP状态改变的时候所执行的代码（到后台或者从后台回到前台等）
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print(state.toString());
    switch (state) {
      case AppLifecycleState.inactive:
        _setNewNotificationRequestInterval(false);
        break;
      case AppLifecycleState.resumed:
        _requestNewNotifications();
        _setNewNotificationRequestInterval(true);
        break;
      case AppLifecycleState.paused:
        _setNewNotificationRequestInterval(false);
        break;
    }
  }

  //设置获取新消息数目的周期。
  _setNewNotificationRequestInterval(bool isActive) {
    if (_rqt != null) {
      _rqt.cancel();
      _rqt = null;
    }
    _isActive = isActive;
    if (isActive) {
      _rqt = Timer.periodic(Duration(minutes: 5), (timer) {
        _requestNewNotifications();
      });
    } else {
      _rqt = Timer.periodic(Duration(minutes: 15), (timer) {
        _requestNewNotifications();
      });
    }
  }

  //获取新消息数目。
  _requestNewNotifications() async {
    if (_rq.provider.UserID <= 0) return;
    var result = await this._rq.request("/api/v1/json/getMyInfo");
    if (result["Status"] == 1) {
      if (!mounted) return;
      final Map<String, dynamic> tempMap = Map<String, dynamic>.from(result);
      int oldNotificationsNum = _getNotificationNum(_tempBadgeNums),
          newNotificationNum = _getNotificationNum(tempMap);
      if (!_isActive && newNotificationNum > oldNotificationsNum) {
        _newNotificationNumInactive = newNotificationNum;
        //在这里应该添加一个能够在通知栏显示气泡提示有新消息的东西。
      }
      setState(() {
        _tempBadgeNums = tempMap;
      });
    } else {
      print(result["ErrorMessage"]);
    }
  }

  //从新消息数目中获取到总的新消息数（评论+提到+消息+举报+互动），并返回。
  int _getNotificationNum(Map<String, dynamic> numMap) {
    return _rq.renderer.extractFromTree(numMap, ["NewReply"], 0) +
        _rq.renderer.extractFromTree(numMap, ["NewMention"], 0) +
        _rq.renderer.extractFromTree(numMap, ["NewMessage"], 0) +
        _rq.renderer.extractFromTree(numMap, ["NewReport"], 0) +
        _rq.renderer.extractFromTree(numMap, ["NewInteraction"], 0);
  }

  //清除所有消息数。
  _clearNotificationNum({List<String> keys, bool clearUnreadNum = false}) {
    setState(() {
      if (clearUnreadNum) _newNotificationNumInactive = 0;
      keys.forEach((element) {
        if (_tempBadgeNums != null && _tempBadgeNums[element] != null)
          _tempBadgeNums[element] = 0;
      });
    });
  }

  //刷新页面。
  Future<Null> _refresh() async {
    _rq.getListNames().forEach((element) {
      _rq.clearOrCreateList(element);
    });
    _getHomepageInfo1();
    _getHomepageInfo2();
    if (_curIndex == 3 && _rq.provider.UserID > 0) _getUpdates();
    return;
  }

  //获取基础的主页信息。
  _getHomepageInfo1() async {
    if (_isLoading1 || !mounted) return;
    setState(() {
      _isLoading1 = true;
      _rq.setIsLoading("NewlyPost", true);
      _rq.setIsLoading("NewlyUpdate", true);
    });

    var result = await this._rq.request("/api/v1/");

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _recommendArr = result["EditorRecommendTopicsArray"];
        _announcementArr = result["AnnouncementsArray"];
        _rq.setListByName("NewlyPost", result["NewlyPostTopicsArray"]);
        _rq.setCurPage("NewlyPost", 1);
        _rq.setTotalPage("NewlyPost", 2);
        _rq.setIsLoading("NewlyPost", false);
        _rq.setListByName("NewlyUpdate", result["NewlyUpdateTopicsArray"]);
        _rq.setCurPage("NewlyUpdate", 1);
        _rq.setTotalPage("NewlyUpdate", 2);
        _rq.setIsLoading("NewlyUpdate", false);
        _isLoading1 = false;
        _isRefreshing1 = false;
      });
    } else {
      print(result["ErrorMessage"]);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
      _rq.setIsLoading("NewlyPost", false);
      _rq.setIsLoading("NewlyUpdate", false);
      _isLoading1 = false;
      _isRefreshing1 = false;
    }
  }

  //获取附加的主页信息。
  _getHomepageInfo2() async {
    if (_isLoading2 || !mounted) return;
    setState(() {
      _rq.setIsLoading("ForumPosts", true);
      _rq.setIsLoading("RecommendTopics", true);
      _isLoading2 = true;
    });

    var result = await this._rq.request("/api/v1/json/completeHomepage");

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _hotBlogPostsArr.addAll(result["HotBlogPostsArray"]);
        _hotChannelsArr.addAll(result["HotChannelsArray"]);
        _newUpdatesNum = result["NewUpdatesNum"];
        _rq.setListByName("ForumPosts", result["ForumPostsArray"]);
        _rq.setCurPage("ForumPosts", 1);
        _rq.setTotalPage("ForumPosts", 2);
        _rq.setIsLoading("ForumPosts", false);
        _rq.setListByName("RecommendTopics", result["RecommendTopicsArray"]);
        _rq.setIsLoading("RecommendTopics", false);
        _isLoading2 = false;
        _isRefreshing2 = false;
      });
    } else {
      print(result["ErrorMessage"]);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
      _rq.setIsLoading("ForumPosts", false);
      _rq.setIsLoading("RecommendTopics", false);
      _isLoading2 = false;
      _isRefreshing2 = false;
    }
  }

  //只更新作品栏（有一个isNewlyPost参数，为true则更新“近日热门”，否则更新“最近更新”）。
  _justUpdateTopicsArray(bool isNewlyPost) async {
    if (_isLoading1) return;
    var listName = isNewlyPost ? "NewlyPost" : "NewlyUpdate",
        params = {"sortby": isNewlyPost ? "default" : "update"};
    _rq.updateListByName(
        "/api/v1/topics",
        listName,
        (data) {
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

  //只更新帖子区。
  _justUpdateForumPostsArray() async {
    if (_isLoading2) return;
    _rq.updateListByName("/api/v1/tag/%E5%B8%96%E5%AD%90", "ForumPosts",
        (data) {
      return {
        "List": data["TopicsArray"],
        "CurPage": data["Page"],
        "TotalPage": data["TotalPage"]
      };
    }, beforeRequest: () {
      if (!mounted) return;
      setState(() {});
    }, afterUpdate: (list) {
      if (!mounted) return;
      setState(() {});
    }, onError: (err) {
      Toast.show(err, context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
    });
  }

  //只更新推荐作品。
  _justUpdateRecommendTopics() async {
    if (_isLoading2) return;
    _rq.updateListByName("/api/v1/json/refreshRecommendList", "RecommendTopics",
        (data) {
      return {
        "List": data["RecommendTopicsArray"],
        "CurPage": 0,
        "TotalPage": 1
      };
    }, beforeRequest: () {
      if (!mounted) return;
      setState(() {});
    }, afterUpdate: (list) {
      if (!mounted) return;
      setState(() {});
    }, onError: (err) {
      Toast.show(err, context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
    });
  }

  //获取动态消息。
  _getUpdates() async {
    _rq.updateListByName("/api/v1/notifications/updates", "Updates", (data) {
      return {
        "List": data["UpdatesArray"],
        "CurPage": data["Page"],
        "TotalPage": data["TotalPage"]
      };
    }, beforeRequest: () {
      if (!mounted) return;
      setState(() {
        _newUpdatesNum = 0;
      });
    }, afterUpdate: (list) {
      if (!mounted) return;
      setState(() {});
    }, onError: (err) {
      Toast.show(err, context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
    });
  }

  //根据不同的index显示主页的内容。
  Widget _showTab() {
    switch (_curIndex) {
      case 0:
        List<Widget> listChildren = [
          Stack(
            children: <Widget>[
              _recommendArr.length > 0
                  ? CarouselSlider(
                      options: CarouselOptions(
                        aspectRatio: 4 / 3,
                        autoPlay: true,
                        enlargeCenterPage: false,
                        viewportFraction: 1,
                      ),
                      items: _recommendArr.map((i) {
                        return Builder(
                          builder: (BuildContext context) {
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context,
                                    MaterialPageRoute(builder: (context) {
                                  return TopicView(value: {"TopicID": i["ID"]});
                                }));
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  (i["Background"] != null &&
                                          i["Background"] != "NONE")
                                      ? Image.network(
                                          i["Background"],
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          "assets/images/recommend_background.jpg",
                                          fit: BoxFit.cover,
                                        ),
                                  Container(
                                    color: Colors.black.withAlpha(127),
                                  ),
                                  ListView(
                                    children: <Widget>[
                                      Container(
                                        padding:
                                            EdgeInsets.fromLTRB(4, 12, 4, 0),
                                        alignment: Alignment.centerRight,
                                        child: _rq.renderer.mainTagSet(
                                            _rq.renderer.extractFromTree(
                                                i, ["Tags"], {}),
                                            false,
                                            ""),
                                      ),
                                      ListTile(
                                        leading: _rq.renderer.userAvatar(
                                            _rq.renderer.extractFromTree(
                                                i, ["AuthorID"], 0)),
                                        title: Text(
                                          _rq.renderer.extractFromTree(
                                              i, ["Title"], ""),
                                          textScaleFactor: 1.2,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(2, 2),
                                                  blurRadius: 4)
                                            ],
                                          ),
                                        ),
                                        subtitle: Text(
                                          _rq.renderer.extractFromTree(
                                              i, ["AuthorName"], ""),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(2, 2),
                                                  blurRadius: 4)
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            EdgeInsets.fromLTRB(16, 0, 16, 20),
                                        child: Column(
                                          children: <Widget>[
                                            Text(
                                              _rq.renderer.extractFromTree(
                                                  i, ["RecommendWord"], ""),
                                              style: TextStyle(
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                      color: Colors.black,
                                                      offset: Offset(2, 2),
                                                      blurRadius: 4)
                                                ],
                                              ),
                                            ),
                                            Text(
                                              "——" +
                                                  _rq.renderer.extractFromTree(
                                                      i,
                                                      ["RecommenderName"],
                                                      ""),
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: Colors.white,
                                                shadows: [
                                                  Shadow(
                                                      color: Colors.black,
                                                      offset: Offset(2, 2),
                                                      blurRadius: 4)
                                                ],
                                              ),
                                            ),
                                          ],
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    )
                  : AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Container(
                        color: Colors.grey,
                        child: Center(
                          child: _rq.renderer.preloader(),
                        ),
                      ),
                    ),
              Container(
                margin: EdgeInsets.fromLTRB(20, 0, 0, 0),
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(0),
                    bottom: Radius.circular(3),
                  ),
                  color: Colors.red,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(127),
                        offset: Offset(2, 2),
                        blurRadius: 4)
                  ],
                ),
                child: Text(
                  FlutterI18n.translate(context, "editor_recommendation"),
                  style: TextStyle(color: Colors.white),
                ),
              )
            ],
          )
        ]; //编辑精选。

        listChildren.add(Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                children: <Widget>[
                  IconButton(
                      icon: Icon(
                        Icons.book,
                        color: Colors.blue[500],
                      ),
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return TagView(value: {"TagName": "文楼"});
                        }));
                      }),
                  Text(
                    FlutterI18n.translate(context, "fiction"),
                    textScaleFactor: 6 / 7,
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  IconButton(
                      icon: Icon(
                        Icons.photo_library,
                        color: Colors.amber[600],
                      ),
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return TagView(value: {"TagName": "图楼"});
                        }));
                      }),
                  Text(
                    FlutterI18n.translate(context, "gallery"),
                    textScaleFactor: 6 / 7,
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  IconButton(
                      icon: Icon(
                        Icons.forum,
                        color: Colors.teal[300],
                      ),
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return TagView(value: {"TagName": "帖子"});
                        }));
                      }),
                  Text(
                    FlutterI18n.translate(context, "forum"),
                    textScaleFactor: 6 / 7,
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  IconButton(
                      icon: Icon(
                        Icons.local_offer,
                        color: Colors.green[600],
                      ),
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return TagList();
                        }));
                      }),
                  Text(
                    FlutterI18n.translate(context, "tags"),
                    textScaleFactor: 6 / 7,
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
              Column(
                children: <Widget>[
                  IconButton(
                      icon: Icon(
                        Icons.leak_add,
                        color: Colors.blue[700],
                      ),
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return ChannelList();
                        }));
                      }),
                  Text(
                    FlutterI18n.translate(context, "channels"),
                    textScaleFactor: 6 / 7,
                    style: TextStyle(color: Theme.of(context).disabledColor),
                  ),
                ],
              ),
            ],
          ),
        )); //首页导航栏。

        listChildren.addAll(
            _rq.renderer.topicList(_rq.getListByName("RecommendTopics")));
        if (_rq.isLoading("RecommendTopics"))
          listChildren.add(_rq.renderer.preloader()); //为您推荐。

        return ListView(
          children: listChildren,
          controller: _sc1,
        );
        break;
      case 1:
        List<Widget> leftLine =
                _rq.renderer.topicList(_rq.getListByName("NewlyPost")), //左边这一栏为近日热门。
            rightLine =
                _rq.renderer.topicList(_rq.getListByName("NewlyUpdate")); //右边这一栏为最近更新。
        if (_rq.isLoading("NewlyPost"))
          leftLine.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("NewlyPost") >= _rq.getTotalPage("NewlyPost"))
          leftLine.add(_rq.renderer.endNotice());
        if (_rq.isLoading("NewlyUpdate"))
          rightLine.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("NewlyUpdate") >=
            _rq.getTotalPage("NewlyUpdate"))
          rightLine.add(_rq.renderer.endNotice());
        return DefaultTabController(
          length: 2,
          child: Column(
            children: <Widget>[
              Container(
                child: Material(
                  child: TabBar(
                    controller: _tc1,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 2.0,
                    tabs: <Widget>[
                      Tab(text: FlutterI18n.translate(context, "newly_post")),
                      Tab(text: FlutterI18n.translate(context, "newly_update")),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: TabBarView(
                  controller: _tc1,
                  children: <Widget>[
                    ListView(
                      children: leftLine,
                      controller: _sc2,
                    ),
                    ListView(
                      children: rightLine,
                      controller: _sc3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        break;
      case 2:
        List<Widget> forumPostList =
                _rq.renderer.topicList(_rq.getListByName("ForumPosts")), //左边这一栏为帖子。
            findMoreList = []; //右边这一栏就有趣得多了。
        if (_rq.isLoading("ForumPosts"))
          forumPostList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("ForumPosts") >= _rq.getTotalPage("ForumPosts"))
          forumPostList.add(_rq.renderer.endNotice());
        findMoreList.add(ListTile(
          title: _rq.renderer.pageSubtitle(
              FlutterI18n.translate(context, "hot_channels"),
              textColor: Theme.of(context).accentColor),
          trailing: FlatButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return ChannelList();
              }));
            },
            child: Text(FlutterI18n.translate(context, "channel_list")),
          ),
        ));
        _hotChannelsArr.forEach((element) {
          findMoreList.add(ListTile(
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
        }); //热门频道。
        findMoreList.add(ListTile(
          title: _rq.renderer.pageSubtitle(
              FlutterI18n.translate(context, "hot_blogposts"),
              textColor: Theme.of(context).accentColor),
          trailing: FlatButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return BlogpostList();
              }));
            },
            child: Text(FlutterI18n.translate(context, "blogpost_list")),
          ),
        ));
        List<Widget> rowItem = [];
        _hotBlogPostsArr.forEach((element) {
          rowItem.add(GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return UserView(value: {
                  "UserName": element["UserName"],
                  "Interface": "blogposts"
                });
              }));
            },
            child: _rq.renderer.userAvatar(
                _rq.renderer.extractFromTree(element, ["UserID"], 0)),
          ));
        }); //热门博文。
        findMoreList.add(Container(
          padding: EdgeInsets.all(12),
          child: Row(
            children: rowItem,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
          ),
        ));
        return DefaultTabController(
          length: 2,
          child: Column(
            children: <Widget>[
              Container(
                child: Material(
                  child: TabBar(
                    controller: _tc2,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 2.0,
                    tabs: <Widget>[
                      Tab(text: FlutterI18n.translate(context, "forum_post")),
                      Tab(text: FlutterI18n.translate(context, "find_more")),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: TabBarView(
                  controller: _tc2,
                  children: <Widget>[
                    ListView(
                      children: forumPostList,
                      controller: _sc4,
                    ),
                    ListView(
                      children: findMoreList,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        break;
      case 3:
        List<Widget> contentList = [];
        _rq.getListByName("Updates").forEach((element) {
          contentList.add(_rq.renderer.messageCard(element, useCard: true));
        }); //动态列表
        if (_rq.isLoading("Updates"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Updates") >= _rq.getTotalPage("Updates"))
          contentList.add(_rq.renderer.endNotice());
        return ListView(
          controller: _sc5,
          children: contentList,
        );
        break;
      default:
        return Text(_curIndex.toString());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool showDrawerBadge = false;

    List<BottomNavigationBarItem> bottomBar = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        title: Text(FlutterI18n.translate(context, "recommendation")),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.book),
        title: Text(FlutterI18n.translate(context, "topics")),
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.pages),
        title: Text(FlutterI18n.translate(context, "discover")),
      ),
    ]; //底栏，基础的3个按钮。

    if (_rq.provider.UserID > 0)
      bottomBar.add(BottomNavigationBarItem(
        icon: Badge(
          badgeContent: Text(
            _newUpdatesNum.toString(),
            style: TextStyle(color: Colors.white),
          ),
          child: Icon(Icons.group),
          borderRadius: 1.5,
          showBadge: _newUpdatesNum > 0,
        ),
        title: Text(FlutterI18n.translate(context, "updates")),
      )); //如果有登陆的话，显示最后一个按钮。

    Map<String, dynamic> userGrade = Map<String, dynamic>.from(
        _rq.provider.getUserInfo("GradeInfo", defValue: {}));

    List<Widget> appBarActions = [], drawer = [];
    if (_rq.provider.UserID > 0) {
      if (_curIndex == 3 &&
          _rq.provider.getUserInfo("BlogStatus", defValue: 0) == 1)
        appBarActions.add(IconButton(
          icon: Icon(Icons.edit),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return Editor(
                value: {"Type": "blog", "Action": "new", "MainID": 0},
              );
            }));
          },
        )); //如果有登陆的话，在动态页面显示写博文按钮。
      drawer.addAll([
        UserAccountsDrawerHeader(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(_rq.provider.getUserInfo(
                "Background",
                defValue: "https://fimtale.com/static/img/userbg.jpg",
              )),
              fit: BoxFit.cover,
            ),
            color: Theme.of(context).primaryColor,
          ),
          currentAccountPicture:
              _rq.renderer.userAvatar(_rq.provider.UserID, size: "large"),
          accountName: Text(
            _rq.provider.UserName,
            textScaleFactor: 1.25,
          ),
          accountEmail: _rq.renderer.userGradeLabel(userGrade),
          onDetailsPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_context) {
              return UserView(value: {"UserName": _rq.provider.UserName});
            }));
          },
        )
      ]); //如果有登陆的话，在侧边栏渲染该用户的卡片。
    } else {
      drawer.addAll([
        ListTile(
          title: Text(FlutterI18n.translate(context, "login")),
          leading: Icon(Icons.account_box),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return Login();
            })).then((value) {
              _refresh();
            });
          },
        ),
        Divider()
      ]); //登录按钮
    }

    if (_curIndex <= 2)
      appBarActions.add(IconButton(
        icon: Icon(Icons.search),
        onPressed: () {
          showSearch(context: context, delegate: SearchPage());
        },
      )); //搜索按钮。

    List<Widget> announcementTiles =
        List<Widget>.from(_announcementArr.map((e) => ListTile(
              title: Text(
                e["Title"],
                maxLines: 1,
              ),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return TopicView(value: {"TopicID": e["ID"]});
                }));
              },
            )));
    announcementTiles.add(ListTile(
      title: Text(FlutterI18n.translate(context, "watch_more")),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return TagView(value: {"TagName": "公告"});
        }));
      },
    ));

    drawer.addAll([
      ExpansionTile(
        title: Text(FlutterI18n.translate(context, "announcement")),
        leading: Icon(Icons.volume_up),
        children: announcementTiles,
      )
    ]); //公告栏。

    if (_rq.provider.UserID > 0) {
      int newNotificationsNum = _getNotificationNum(_tempBadgeNums),
          examinationTopicsNum = _rq.renderer
              .extractFromTree(_tempBadgeNums, ["NewExamination"], 0);

      showDrawerBadge = showDrawerBadge ||
          (newNotificationsNum > 0) ||
          (examinationTopicsNum > 0);

      drawer.addAll([
        ExpansionTile(
          title: Text(FlutterI18n.translate(context, "post_new")),
          leading: Icon(Icons.add),
          children: <Widget>[
            ListTile(
              title: Text(FlutterI18n.translate(context, "new_topic")),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return Editor(
                    value: {"Type": "topic", "Action": "new", "MainID": 0},
                  );
                }));
              },
            ),
            ListTile(
              title: Text(FlutterI18n.translate(context, "create_channel")),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return CreateChannel();
                }));
              },
            )
          ],
        ), //新建按钮。
        ListTile(
          title: Text(FlutterI18n.translate(context, "notifications")),
          leading: Badge(
            badgeContent: Text(
              newNotificationsNum.toString(),
              style: TextStyle(color: Colors.white),
            ),
            child: Icon(Icons.notifications),
            borderRadius: 1.5,
            showBadge: newNotificationsNum > 0,
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return NotificationList();
            })).then((value) {
              _clearNotificationNum(
                keys: [
                  "NewReply",
                  "NewMention",
                  "NewMessage",
                  "NewReport",
                  "NewInteraction"
                ],
                clearUnreadNum: true,
              );
              _requestNewNotifications();
              _setNewNotificationRequestInterval(_isActive);
            });
          },
        ), //通知按钮。
        ListTile(
          title: Text(FlutterI18n.translate(context, "examination_queue")),
          leading: Badge(
            badgeContent: Text(
              examinationTopicsNum.toString(),
              style: TextStyle(color: Colors.white),
            ),
            child: Icon(Icons.unarchive),
            borderRadius: 1.5,
            showBadge: examinationTopicsNum > 0,
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return ExaminationList();
            })).then((value) {
              _clearNotificationNum(keys: ["NewExamination"]);
              _requestNewNotifications();
              _setNewNotificationRequestInterval(_isActive);
            });
          },
        ), //审核页面按钮。
        ListTile(
          title: Text(FlutterI18n.translate(context, "settings")),
          leading: Icon(Icons.settings),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return Settings();
            })).then((value) => _refresh());
          },
        ), //设置按钮。
        ListTile(
          title: Text(FlutterI18n.translate(context, "favorites")),
          leading: Icon(Icons.folder_special),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return FavoriteList();
            }));
          },
        ), //收藏按钮。
        ListTile(
          title: Text(FlutterI18n.translate(context, "history")),
          leading: Icon(Icons.history),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) {
              return HistoryList();
            }));
          },
        ), //历史页面按钮。
        ListTile(
          title: Text(FlutterI18n.translate(context, "logout")),
          leading: Icon(Icons.assignment_late),
          onTap: () {
            _rq.request("/api/v1/token_receiver", params: {
              "action": "logout",
              "user_id": _rq.provider.UserID,
              "token": _rq.provider.getUserInfo("FormHash")
            }).then((value) {
              showModalBottomSheet(
                  context: context,
                  builder: (context) {
                    return SingleChildScrollView(
                      child: Text(value["Message"]),
                    );
                  });
              if (value["Status"] == 1) {
                _rq.provider.initUserInfo({"ID": 0, "UserName": ""});
                _refresh();
              } else {
                Toast.show(
                    FlutterI18n.translate(context, "logout_failed"), context);
              }
            });
          },
        ) //退出按钮。
      ]);
    }

    drawer.add(ListTile(
      leading: Icon(Icons.info),
      title: Text(FlutterI18n.translate(context, "about_app")),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) {
          return AboutPage();
        }));
      },
    )); //关于应用按钮。

    return new Scaffold( //Scaffold是整个页面的排版布局，就是常见的几个结构。
      appBar: new AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Badge(
              child: Icon(Icons.menu),
              borderRadius: 1.5,
              showBadge: showDrawerBadge,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: new Text(FlutterI18n.translate(context, "home_page")),
        actions: appBarActions,
      ), //appBar是顶端栏，leading是左上角的按钮，这里是侧边栏按钮；actions是包含所有右上角按钮的List。
      body: Container(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _showTab(),
        ),
      ), //body是页面的主体。
      bottomNavigationBar: BottomNavigationBar(
        items: bottomBar,
        currentIndex: _curIndex,
        onTap: (int index) {
          setState(() {
            _curIndex = index;
            if (_curIndex == 3 &&
                _rq.provider.UserID > 0 &&
                _rq.getCurPage("Updates") <= 0) _getUpdates();
          });
        },
        type: BottomNavigationBarType.fixed,
      ), //bottomNavigatorBar是底端栏，用来放置切换页面的按钮。
      drawer: Drawer(
        child: ListView(
          children: drawer,
        ),
      ), //drawer是侧边栏，平常收起，点击按钮时弹出。
    );
  }
}
