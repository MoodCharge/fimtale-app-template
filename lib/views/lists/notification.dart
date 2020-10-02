import 'package:badges/badges.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

class NotificationList extends StatefulWidget {
  final value;

  NotificationList({Key key, this.value}) : super(key: key);

  @override
  _NotificationListState createState() => new _NotificationListState(value);
}

class _NotificationListState extends State<NotificationList>
    with TickerProviderStateMixin {
  var value;
  int _curIndex = 0;
  Map<String, dynamic> _notificationNum = {
    "NewReply": 0,
    "NewMention": 0,
    "NewInteraction": 0,
    "NewMessage": 0,
    "NewReport": 0
  };
  ScrollController _sc1 = new ScrollController(),
      _sc2 = new ScrollController(),
      _sc3 = new ScrollController(),
      _sc4 = new ScrollController(),
      _sc5 = new ScrollController();
  TabController _tc;
  RequestHandler _rq;

  _NotificationListState(value) {
    this.value = value;
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: [
      "Replies",
      "Mentions",
      "Interactions",
      "Contacts",
      "Reports"
    ]);
    _tc = new TabController(length: 5, vsync: this);
    _sc1.addListener(() {
      if (_sc1.position.pixels >= _sc1.position.maxScrollExtent - 400) {
        _getNotifications(true);
      }
    });
    _sc2.addListener(() {
      if (_sc2.position.pixels >= _sc2.position.maxScrollExtent - 400) {
        _getNotifications(true);
      }
    });
    _sc3.addListener(() {
      if (_sc3.position.pixels >= _sc3.position.maxScrollExtent - 400) {
        _getNotifications(true);
      }
    });
    _sc4.addListener(() {
      if (_sc4.position.pixels >= _sc4.position.maxScrollExtent - 400) {
        _getNotifications(true);
      }
    });
    _sc5.addListener(() {
      if (_sc5.position.pixels >= _sc5.position.maxScrollExtent - 400) {
        _getNotifications(true);
      }
    });
    _tc.addListener(() {
      if (_tc.index.toDouble() == _tc.animation.value) {
        if (!mounted) return;
        setState(() {
          _curIndex = _tc.index;
          _clearCurrentNotificationNum();
        });
        _getNotifications(false);
      }
    });
    _getNotificationNum();
    _getNotifications(false);
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

  Future<Null> _refresh() async {
    _rq.getListNames().forEach((element) {
      _rq.clearOrCreateList(element);
    });
    _getNotifications(false);
    return;
  }

  _getNotificationNum() async {
    var result = await _rq.request("/api/v1/notifications/list");

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _notificationNum.forEach((key, value) {
          _notificationNum[key] = result[key];
        });
        _clearCurrentNotificationNum();
      });
    } else {
      Toast.show(result["ErrorMessage"], context);
    }
  }

  _clearCurrentNotificationNum() {
    List<String> indexList = [
      "NewReply",
      "NewMention",
      "NewInteraction",
      "NewMessage",
      "NewReport"
    ];
    _notificationNum[indexList[_curIndex]] = 0;
  }

  _getNotifications(bool withForce) {
    switch (_curIndex) {
      case 0:
        if (_rq.getCurPage("Replies") <= 0 || withForce)
          _getSingleNotification("reply", "Replies", "ReplyArray");
        break;
      case 1:
        if (_rq.getCurPage("Mentions") <= 0 || withForce)
          _getSingleNotification("mention", "Mentions", "MentionArray");
        break;
      case 2:
        if (_rq.getCurPage("Interactions") <= 0 || withForce)
          _getSingleNotification(
              "interaction", "Interactions", "InteractionArray");
        break;
      case 3:
        if (_rq.getCurPage("Contacts") <= 0 || withForce)
          _getSingleNotification("inbox", "Contacts", "InboxArray");
        break;
      case 4:
        if (_rq.getCurPage("Reports") <= 0 || withForce)
          _getSingleNotification("reports", "Reports", "ReportsArray");
        break;
    }
  }

  _getSingleNotification(
      String path, String tableName, String arrayName) async {
    _rq.updateListByName("/api/v1/notifications/" + path, tableName, (data) {
      return {
        "List": data[arrayName],
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

  List<Widget> _displayNotificationList(String tableName) {
    List<Widget> res = [];
    if (tableName == "Contacts") {
      _rq.getListByName(tableName).forEach((element) {
        res.add(ListTile(
          onTap: () {
            _rq.launchURL(
                _rq.renderer.extractFromTree(element, ["HeaderLink"], ""));
          },
          leading: Badge(
            badgeContent: Text(
              _rq.renderer
                  .extractFromTree(element, ["NewMessageNum"], 0)
                  .toString(),
              style: TextStyle(color: Colors.white),
            ),
            showBadge:
                _rq.renderer.extractFromTree(element, ["NewMessageNum"], 0) > 0,
            child: _rq.renderer.userAvatar(_rq.renderer
                .extractFromTree(element, ["Avatar"], ["avatar", 0])[1]),
          ),
          title: Text(
            _rq.renderer.extractFromTree(element, ["Title"], ""),
            textScaleFactor: 1.25,
            maxLines: 1,
          ),
          subtitle: Text(
            _rq.renderer.extractFromTree(element, ["Subtitle"], ""),
            maxLines: 1,
          ),
        ));
      });
    } else {
      _rq.getListByName(tableName).forEach((element) {
        res.add(_rq.renderer.messageCard(
          element,
          useCard: false,
          singleLineSubtitle: tableName == "Contacts",
        ));
      });
    }
    if (_rq.isLoading(tableName))
      res.add(_rq.renderer.preloader());
    else if (_rq.getCurPage(tableName) >= _rq.getTotalPage(tableName))
      res.add(_rq.renderer.endNotice());
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "notifications")),
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
                        Tab(
                          child: Badge(
                            badgeContent: Text(
                              _notificationNum["NewReply"].toString(),
                              style: TextStyle(color: Colors.white),
                            ),
                            showBadge: _notificationNum["NewReply"] > 0,
                            child:
                                Text(FlutterI18n.translate(context, "replies")),
                          ),
                        ),
                        Tab(
                          child: Badge(
                            badgeContent: Text(
                              _notificationNum["NewMention"].toString(),
                              style: TextStyle(color: Colors.white),
                            ),
                            showBadge: _notificationNum["NewMention"] > 0,
                            child: Text(
                                FlutterI18n.translate(context, "mentions")),
                          ),
                        ),
                        Tab(
                          child: Badge(
                            badgeContent: Text(
                              _notificationNum["NewInteraction"].toString(),
                              style: TextStyle(color: Colors.white),
                            ),
                            showBadge: _notificationNum["NewInteraction"] > 0,
                            child: Text(
                                FlutterI18n.translate(context, "interactions")),
                          ),
                        ),
                        Tab(
                          child: Badge(
                            badgeContent: Text(
                              _notificationNum["NewMessage"].toString(),
                              style: TextStyle(color: Colors.white),
                            ),
                            showBadge: _notificationNum["NewMessage"] > 0,
                            child:
                                Text(FlutterI18n.translate(context, "inbox")),
                          ),
                        ),
                        Tab(
                          child: Badge(
                            badgeContent: Text(
                              _notificationNum["NewReport"].toString(),
                              style: TextStyle(color: Colors.white),
                            ),
                            showBadge: _notificationNum["NewReport"] > 0,
                            child:
                                Text(FlutterI18n.translate(context, "system")),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                Flexible(
                  child: TabBarView(
                    controller: _tc,
                    children: <Widget>[
                      ListView(
                        children: _displayNotificationList("Replies"),
                        controller: _sc1,
                      ),
                      ListView(
                        children: _displayNotificationList("Mentions"),
                        controller: _sc2,
                      ),
                      ListView(
                        children: _displayNotificationList("Interactions"),
                        controller: _sc3,
                      ),
                      ListView(
                        children: _displayNotificationList("Contacts"),
                        controller: _sc4,
                      ),
                      ListView(
                        children: _displayNotificationList("Reports"),
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
