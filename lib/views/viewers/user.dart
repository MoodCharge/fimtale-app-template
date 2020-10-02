import 'dart:convert';
import 'dart:math';
import 'package:charts_flutter/flutter.dart' as chart;
import 'package:fimtale/views/lists/user.dart';
import 'package:fimtale/views/viewers/inbox.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';
import 'package:fimtale/library/app_provider.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:toast/toast.dart';

//标签、频道、用户三个页面的原理大同小异。仅在viewers/channel.dart进行详细注释，就不在其它两个页面做多余注释了。

class UserView extends StatefulWidget {
  final value;

  UserView({Key key, @required this.value}) : super(key: key);

  @override
  _UserViewState createState() => new _UserViewState(value);
}

class _UserViewState extends State<UserView> with TickerProviderStateMixin {
  var value;
  int _curIndex = 1, _statIndex = 0;
  String _userName = "",
      _topicQueryString = "",
      _topicSortBy = "",
      _blogpostQueryString = "",
      _blogpostSortBy = "",
      _channelQueryString = "",
      _channelSortBy = "";
  Map<String, dynamic> _userInfo = {}, _userStatInfo = {};
  AppInfoProvider _provider;
  TabController _tc;
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _UserViewState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    _userName = value["UserName"];
    if (value.containsKey("Interface")) {
      switch (value["Interface"]) {
        case "topics":
          _curIndex = 2;
          break;
        case "blogposts":
          _curIndex = 3;
          break;
        case "comments":
          _curIndex = 4;
          break;
        case "channels":
          _curIndex = 5;
          break;
        case "following":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return UserList(value: {
              "PageTitle": FlutterI18n.translate(context, "following") +
                  " - " +
                  _userName,
              "Url":
                  "/api/v1/u/" + Uri.encodeComponent(_userName) + "/following"
            });
          }));
          break;
        case "followers":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return UserList(value: {
              "PageTitle": FlutterI18n.translate(context, "followers") +
                  " - " +
                  _userName,
              "Url":
                  "/api/v1/u/" + Uri.encodeComponent(_userName) + "/followers"
            });
          }));
          break;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<AppInfoProvider>(context, listen: false);
    _rq = new RequestHandler(context,
        listNames: ["Updates", "Topics", "Blogposts", "Comments", "Channels"]);
    _tc = new TabController(length: 6, initialIndex: _curIndex, vsync: this);
    _initPage();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        switch (_curIndex) {
          case 1:
            _getUpdates();
            break;
          case 2:
            _getTopics();
            break;
          case 3:
            if (_rq.renderer.extractFromTree(_userInfo, ["BlogStatus"], 0) == 1)
              _getBlogposts();
            break;
          case 4:
            _getComments();
            break;
          case 5:
            _getChannels();
            break;
        }
      }
    });
    _tc.addListener(() {
      if (_tc.index.toDouble() == _tc.animation.value) {
        setState(() {
          _curIndex = _tc.index;
        });
        _initPage();
      }
    });
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

  //初始化页面。
  _initPage() {
    switch (_curIndex) {
      case 0:
      case 1:
        if (_rq.getCurPage("Updates") <= 0) _getUpdates();
        break;
      case 2:
        if (_rq.getCurPage("Topics") <= 0) _getTopics();
        break;
      case 3:
        if (_rq.renderer.extractFromTree(_userInfo, ["BlogStatus"], 0) == 1 &&
            _rq.getCurPage("Blogposts") <= 0) _getBlogposts();
        break;
      case 4:
        if (_rq.getCurPage("Comments") <= 0) _getComments();
        break;
      case 5:
        if (_rq.getCurPage("Channels") <= 0) _getChannels();
        break;
    }
  }

  //获取基本信息和动态。
  _getUpdates() async {
    _rq.updateListByName(
        "/api/v1/u/" + Uri.encodeComponent(_userName), "Updates", (data) {
      if (!data["IsUser"]) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) {
          return UserList(value: {
            "PageTitle": FlutterI18n.translate(context, "no_user_found"),
            "UsersArray": data["UsersArray"]
          });
        }));
      }
      _userInfo = Map<String, dynamic>.from(data["UserInfo"]);
      _userStatInfo = Map<String, dynamic>.from(data["UserStatInfo"]);
      return {
        "List": data["UpdatesArray"],
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

  //获取作品。
  _getTopics() async {
    Map<String, dynamic> params = {};
    if (_topicQueryString.length > 0) params["q"] = _topicQueryString;
    if (_topicSortBy.length > 0) params["sortby"] = _topicSortBy;
    _rq.updateListByName(
        "/api/v1/u/" + Uri.encodeComponent(_userName) + "/topics",
        "Topics",
        (data) {
          if (!data["IsUser"]) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (context) {
              return UserList(value: {
                "PageTitle": FlutterI18n.translate(context, "no_user_found"),
                "UsersArray": data["UsersArray"]
              });
            }));
          }
          _userInfo = Map<String, dynamic>.from(data["UserInfo"]);
          return {
            "List": data["TopicsArray"],
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
        });
  }

  //获取评论。
  _getComments() async {
    _rq.updateListByName(
        "/api/v1/u/" + Uri.encodeComponent(_userName) + "/comments", "Comments",
        (data) {
      if (!data["IsUser"]) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) {
          return UserList(value: {
            "PageTitle": FlutterI18n.translate(context, "no_user_found"),
            "UsersArray": data["UsersArray"]
          });
        }));
      }
      _userInfo = Map<String, dynamic>.from(data["UserInfo"]);
      return {
        "List": data["CommentsArray"],
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

  //获取博文。
  _getBlogposts() async {
    _rq.updateListByName(
        "/api/v1/u/" + Uri.encodeComponent(_userName) + "/blogposts",
        "Blogposts", (data) {
      if (!data["IsUser"]) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) {
          return UserList(value: {
            "PageTitle": FlutterI18n.translate(context, "no_user_found"),
            "UsersArray": data["UsersArray"]
          });
        }));
      }
      _userInfo = Map<String, dynamic>.from(data["UserInfo"]);
      return {
        "List": data["BlogpostsArray"],
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

  //获取频道。
  _getChannels() async {
    _rq.updateListByName(
        "/api/v1/u/" + Uri.encodeComponent(_userName) + "/channels", "Channels",
        (data) {
      if (!data["IsUser"]) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) {
          return UserList(value: {
            "PageTitle": FlutterI18n.translate(context, "no_user_found"),
            "UsersArray": data["UsersArray"]
          });
        }));
      }
      _userInfo = Map<String, dynamic>.from(data["UserInfo"]);
      return {
        "List": data["ChannelsArray"],
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

  //处理搜索内容。
  _processSearchText(var searchInfoStr) {
    Map<String, dynamic> searchInfo =
        Map<String, dynamic>.from(jsonDecode(searchInfoStr));
    if (searchInfo["Search"]) {
      switch (_curIndex) {
        case 2:
          _topicQueryString = searchInfo["Q"];
          _topicSortBy = searchInfo["SortBy"];
          _rq.clearOrCreateList("Topics");
          _getTopics();
          break;
        case 3:
          _blogpostQueryString = searchInfo["Q"];
          _blogpostSortBy = searchInfo["SortBy"];
          _rq.clearOrCreateList("Blogposts");
          _getBlogposts();
          break;
        case 5:
          _channelQueryString = searchInfo["Q"];
          _channelSortBy = searchInfo["SortBy"];
          _rq.clearOrCreateList("Channels");
          _getChannels();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> allowedOptions = List<String>.from(
        _rq.renderer.extractFromTree(_userInfo, ["AllowedOptions"], []));
    String background =
        _rq.renderer.extractFromTree(_userInfo, ["Background"], "");
    List<Widget> appBarActions = [];
    if ([2, 3, 5].contains(_curIndex))
      appBarActions.add(IconButton(
        icon: Icon(Icons.search),
        onPressed: () async {
          String target = "topic", query = "", sortBy = "";
          switch (_curIndex) {
            case 2:
              query = _topicQueryString;
              sortBy = _topicSortBy;
              break;
            case 3:
              target = "blogpost";
              query = _blogpostQueryString;
              sortBy = _blogpostSortBy;
              break;
            case 5:
              target = "channel";
              query = _channelQueryString;
              sortBy = _channelSortBy;
              break;
          }
          String searchInfo = await showSearch(
              context: context,
              delegate: SearchPage(
                  currentSearchTarget: target,
                  template: target,
                  queryString: query,
                  currentSortBy: sortBy,
                  openNewPage: false));
          _processSearchText(searchInfo);
        },
      ));
    if (allowedOptions.contains("favorite"))
      appBarActions.add(IconButton(
        icon: Icon(
            _userInfo["IsFavorite"] ? Icons.favorite : Icons.favorite_border),
        onPressed: () {
          _rq.manage(_rq.renderer.extractFromTree(_userInfo, ["ID"], 0), 4, "3",
              (res) {
            setState(() {
              if (_userInfo["IsFavorite"])
                _userInfo["Followers"]--;
              else
                _userInfo["Followers"]++;
              _userInfo["IsFavorite"] = !_userInfo["IsFavorite"];
            });
          });
        },
      ));

    if (allowedOptions.contains("inbox"))
      appBarActions.add(IconButton(
        icon: Icon(Icons.inbox),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return InboxView(value: {"ContactName": _userInfo["UserName"]});
          }));
        },
      ));

    List<PopupMenuItem<String>> actionMenu = [];
    if (allowedOptions.contains("report"))
      actionMenu.add(PopupMenuItem<String>(
        child: Text(FlutterI18n.translate(context, "report")),
        value: "report",
      ));

    if (actionMenu.length > 0)
      appBarActions.add(PopupMenuButton(
        itemBuilder: (BuildContext context) => actionMenu,
        onSelected: (String action) {
          switch (action) {
            case "report":
              _rq.renderer.reportWindow("user", _userInfo["ID"]);
              break;
          }
        },
      ));

    return new Scaffold(
      body: Container(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _sc,
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 350.0,
                floating: false,
                pinned: true,
                title: Text(_userName),
                actions: appBarActions,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.asset(
                        "assets/images/user_background.jpg",
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
                      ),
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(24),
                              child: _rq.renderer.userAvatar(
                                  _rq.renderer
                                      .extractFromTree(_userInfo, ["ID"], 0),
                                  size: "large",
                                  radius: 48),
                            ),
                            Text(
                              _rq.renderer
                                  .extractFromTree(_userInfo, ["UserName"], ""),
                              textScaleFactor: 2,
                              style: TextStyle(color: Colors.white),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              child: _rq.renderer.singleLineBadges(
                                  List<String>.from(_rq.renderer
                                      .extractFromTree(
                                          _userInfo, ["Badges"], []))),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 8),
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 0,
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  GestureDetector(
                                    onTap: () {
                                      if (_userInfo.isNotEmpty) {
                                        Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (context) {
                                          return UserList(value: {
                                            "PageTitle": FlutterI18n.translate(
                                                    context, "following") +
                                                " - " +
                                                _userName,
                                            "Url": "/api/v1/u/" +
                                                Uri.encodeComponent(_userName) +
                                                "/following"
                                          });
                                        }));
                                      }
                                    },
                                    child: Text(
                                      FlutterI18n.translate(
                                              context, "following") +
                                          " " +
                                          _rq.renderer
                                              .extractFromTree(
                                                  _userInfo, ["Following"], 0)
                                              .toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 10,
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (_userInfo.isNotEmpty) {
                                        Navigator.push(context,
                                            MaterialPageRoute(
                                                builder: (context) {
                                          return UserList(value: {
                                            "PageTitle": FlutterI18n.translate(
                                                    context, "followers") +
                                                " - " +
                                                _userName,
                                            "Url": "/api/v1/u/" +
                                                Uri.encodeComponent(_userName) +
                                                "/followers"
                                          });
                                        }));
                                      }
                                    },
                                    child: Text(
                                      FlutterI18n.translate(
                                              context, "followers") +
                                          " " +
                                          _rq.renderer
                                              .extractFromTree(
                                                  _userInfo, ["Followers"], 0)
                                              .toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 32,
                            )
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
                      text: FlutterI18n.translate(context, "introduction"),
                    ),
                    Tab(
                      text: FlutterI18n.translate(context, "updates"),
                    ),
                    Tab(
                      text: FlutterI18n.translate(context, "topics") +
                          " " +
                          _rq.renderer
                              .extractFromTree(_userInfo, ["Topics"], 0)
                              .toString(),
                    ),
                    Tab(
                      text: FlutterI18n.translate(context, "blogposts") +
                          " " +
                          _rq.renderer
                              .extractFromTree(_userInfo, ["Blogposts"], 0)
                              .toString(),
                    ),
                    Tab(
                      text: FlutterI18n.translate(context, "comments") +
                          " " +
                          _rq.renderer
                              .extractFromTree(_userInfo, ["Comments"], 0)
                              .toString(),
                    ),
                    Tab(
                      text: FlutterI18n.translate(context, "channels") +
                          " " +
                          _rq.renderer
                              .extractFromTree(_userInfo, ["Channels"], 0)
                              .toString(),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _showContent(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //根据不同索引渲染不同页面。
  List<Widget> _showContent(BuildContext context) {
    List<Widget> contentList = [];
    switch (_curIndex) {
      case 0:
        Map<String, dynamic> userGrade = Map<String, dynamic>.from(
            _rq.renderer.extractFromTree(_userInfo, ["GradeInfo"], {}));
        List<Widget> introList = [
          Container(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: _rq.renderer.userGradeLabel(userGrade),
          ),
        ];
        if (_userInfo["Medals"] != null && _userInfo["Medals"].length > 0) {
          List<InlineSpan> medalSpans = [
            WidgetSpan(
              child: Icon(
                Icons.security,
                color: Colors.teal,
              ),
            ),
          ];

          _userInfo["Medals"].forEach((element) {
            medalSpans.add(
              WidgetSpan(
                child: Tooltip(
                  message: element,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Image.network(
                        "https://fimtale.com/static/img/medals/" +
                            element +
                            ".png"),
                  ),
                ),
              ),
            );
          });

          introList.add(Container(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text.rich(
              TextSpan(
                children: medalSpans,
                style: TextStyle(wordSpacing: 12),
              ),
            ),
          ));
        }
        if (_userInfo["UserHomepage"] != null &&
            _userInfo["UserHomepage"].length > 0) {
          introList.add(Container(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    child: Icon(
                      Icons.domain,
                      color: Colors.amber[700],
                    ),
                  ),
                  TextSpan(
                    text: _userInfo["UserHomepage"],
                    style: TextStyle(
                      color: Colors.blue,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        _rq.launchURL(_userInfo["UserHomepage"]);
                      },
                  )
                ],
                style: TextStyle(wordSpacing: 12),
              ),
            ),
          ));
        }
        if (_userInfo["UserIntro"] != null &&
            _userInfo["UserIntro"].length > 0) {
          introList.add(Container(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    child: Icon(
                      Icons.short_text,
                      color: Colors.amber[700],
                    ),
                  ),
                  TextSpan(
                    text: _userInfo["UserIntro"],
                  )
                ],
                style: TextStyle(wordSpacing: 12),
              ),
            ),
          ));
        }
        introList.add(Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  child: Icon(
                    Icons.stars,
                    color: Colors.orange,
                  ),
                ),
                TextSpan(
                  text: _userInfo["Bits"].toString(),
                )
              ],
              style: TextStyle(wordSpacing: 12),
            ),
          ),
        ));

        contentList.add(Card(
          margin: EdgeInsets.all(12),
          child: Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: introList,
            ),
          ),
        ));

        List<Widget> statIndexChips = [];
        int index = 0;
        String currentStatIndex;

        _userStatInfo.forEach((key, value) {
          final curIndex = index;
          statIndexChips.add(ChoiceChip(
            label: Text(FlutterI18n.translate(
                context, "login_with_account_and_password")),
            selectedColor: Theme.of(context).accentColor,
            disabledColor: Theme.of(context).disabledColor,
            onSelected: (bool selected) {
              setState(() {
                _statIndex = curIndex;
              });
            },
            selected: _statIndex == _curIndex,
            labelStyle:
                _statIndex == _curIndex ? TextStyle(color: Colors.white) : null,
          ));
          if (index == _statIndex) currentStatIndex = key;
          index++;
        });

        if (statIndexChips.length > 0)
          contentList.add(Container(
            margin: EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: statIndexChips,
            ),
          ));

        if (currentStatIndex != null) {
          List statData = [];
          List<Color> colors;
          int datumIndex = 0;
          switch (_statIndex) {
            case 0:
              colors = [
                Colors.blue[400],
                Colors.blue[500],
                Colors.blue[600],
              ];
              break;
            case 1:
              colors = [
                Colors.amber[700],
                Colors.amber[800],
                Colors.amber[900],
              ];
              break;
            case 2:
              colors = [
                Colors.deepPurple[300],
                Colors.deepPurple[400],
                Colors.deepPurple[500],
              ];
              break;
            case 4:
              colors = [
                Colors.green[500],
                Colors.green[600],
                Colors.green[700],
              ];
              break;
            default:
              colors = [
                Colors.redAccent[200],
                Colors.redAccent[400],
                Colors.redAccent[700],
              ];
              break;
          }

          Map<String, dynamic>.from(_userStatInfo[currentStatIndex])
              .forEach((key, value) {
            statData.add([
              key,
              value,
              _statIndex == 3
                  ? Colors.teal[
                      ((value > 0 ? min(8, max(0, log(value).floor())) : 0) +
                              1) *
                          100]
                  : colors[datumIndex % 3]
            ]);
            datumIndex++;
          });

          if (statData.length > 0) {
            List<chart.Series<dynamic, String>> seriesList = [
              chart.Series(
                id: currentStatIndex,
                data: statData,
                domainFn: (data, _) => data[0],
                measureFn: (data, _) => data[1],
                colorFn: (data, _) => chart.Color(
                    r: data[2].red, g: data[2].green, b: data[2].blue),
                labelAccessorFn: (data, _) =>
                    data[0] + (_statIndex != 3 ? ":" + data[1].toString() : ""),
              )
            ];

            List<chart.SelectionModelConfig<String>> selectionModels = [
              chart.SelectionModelConfig(
                type: chart.SelectionModelType.info,
                changedListener: (chart.SelectionModel m) {
                  Toast.show(
                      m.selectedDatum[0].datum[0] +
                          ":" +
                          m.selectedDatum[0].datum[1].toString(),
                      context);
                },
              )
            ];

            contentList.add(Container(
              height: 400,
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _statIndex == 3
                  ? chart.BarChart(
                      seriesList,
                      animate: true,
                      behaviors: [
                        chart.SlidingViewport(),
                        chart.PanAndZoomBehavior(),
                      ],
                      domainAxis: chart.OrdinalAxisSpec(
                        viewport: chart.OrdinalViewport(statData[0][0], 6),
                      ),
                      selectionModels: selectionModels,
                    )
                  : chart.PieChart(
                      seriesList,
                      defaultRenderer: chart.ArcRendererConfig(
                        arcRendererDecorators: [
                          chart.ArcLabelDecorator(
                            labelPosition: chart.ArcLabelPosition.inside,
                          ),
                        ],
                      ),
                      selectionModels: selectionModels,
                    ),
            ));
          }
        }
        break;
      case 1:
        _rq.getListByName("Updates").forEach((element) {
          contentList.add(_rq.renderer.messageCard(element, useCard: true));
        });
        if (_rq.isLoading("Updates"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Updates") >= _rq.getTotalPage("Updates"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 2:
        contentList.addAll(_rq.renderer.topicList(_rq.getListByName("Topics")));
        if (_rq.isLoading("Topics"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 3:
        if (_rq.renderer.extractFromTree(_userInfo, ["BlogStatus"], 0) != 1) {
          contentList.add(Center(
            child: Text(FlutterI18n.translate(context, "blog_not_opened")),
          ));
        } else {
          contentList.addAll(
              _rq.renderer.blogpostList(_rq.getListByName("Blogposts")));
          if (_rq.isLoading("Blogposts"))
            contentList.add(_rq.renderer.preloader());
          else if (_rq.getCurPage("Blogposts") >= _rq.getTotalPage("Blogposts"))
            contentList.add(_rq.renderer.endNotice());
        }
        break;
      case 4:
        _rq.getListByName("Comments").forEach((element) {
          contentList.add(_rq.renderer.messageCard(element, useCard: true));
        });
        if (_rq.isLoading("Comments"))
          contentList.add(_rq.renderer.preloader());
        else if (_rq.getCurPage("Comments") >= _rq.getTotalPage("Comments"))
          contentList.add(_rq.renderer.endNotice());
        break;
      case 5:
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
}
