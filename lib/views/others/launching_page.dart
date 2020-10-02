import 'dart:async';
import 'dart:convert';
import 'package:fimtale/library/consts.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/lists/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:sp_util/sp_util.dart';
import 'package:toast/toast.dart';

//启动页面，用来加载各式各样的初始化信息。

class LaunchingPage extends StatefulWidget {
  @override
  _LaunchingPageState createState() => new _LaunchingPageState();
}

class _LaunchingPageState extends State<LaunchingPage> {
  RequestHandler _rq;
  int _stage = 0, _totalStage = 12;
  String _curStatus = "", _welcomeWord = "Another World Inside Books";

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  @override
  void dispose() {
    super.dispose();
  }

  int _parseColorHex(String hex) {
    hex = hex.toLowerCase().replaceAll("#", "").replaceAll('0X', '');
    if (hex.length == 6) {
      hex = "ff" + hex;
    }
    return int.parse(hex, radix: 16);
  }

  Future<void> _initAsync() async {
    try {
      await SpUtil.getInstance();
    } catch (e) {
      Toast.show(e.toString(), context);
    }
    if (!mounted) return;
    setState(() {
      _stage = 0;
      _curStatus = "Initializing System Preference";
    });
    _rq = RequestHandler(context);
    if (!mounted) return;
    setState(() {
      _stage = 1;
    });
    await _rq.provider.loadUserPreference();
    if (!mounted) return;
    setState(() {
      _stage = 2;
    });
    await _rq.provider.loadUserInfo();
    if (!mounted) return;
    setState(() {
      _stage = 3;
    });
    if (!mounted) return;
    setState(() {
      _stage = 4;
    });
    await FlutterI18n.refresh(context, _rq.provider.locale);
    if (!mounted) return;
    setState(() {
      _stage = 5;
    });
    if (!mounted) return;
    setState(() {
      _stage = 6;
      _curStatus = FlutterI18n.translate(context, "initializing_tags") +
          "(" +
          FlutterI18n.translate(context, "use_a_little_cellular_network") +
          ")";
      _welcomeWord = FlutterI18n.translate(context, "welcome_word");
    });
    Map<String, dynamic> tempResult =
        await _rq.request("/api/v1/json/getMainTags");
    if (!mounted) return;
    setState(() {
      _stage = 7;
    });
    setState(() {
      _stage = 8;
    });
    Map tags, badges;
    int status = tempResult["Status"];
    if (status == 1 &&
        tempResult["TagsArray"] != null &&
        tempResult["BadgesArray"] != null) {
      tags = Map.from(tempResult["TagsArray"]);
      badges = Map.from(tempResult["BadgesArray"]);
      SpUtil.putString("main_tags", jsonEncode(tags));
      SpUtil.putString("badges", jsonEncode(badges));
    } else {
      Map tempTags =
              jsonDecode(SpUtil.getString("main_tags", defValue: "{}")) ?? {},
          tempBadges =
              jsonDecode(SpUtil.getString("badges", defValue: "{}")) ?? {};
      tags = Map.from(tempTags);
      badges = Map.from(tempBadges);
      Toast.show(tempResult["Message"] ?? tempResult["ErrorMessage"], context);
    }
    if (!mounted) return;
    setState(() {
      _stage = 9;
    });
    badges.forEach((key, value) {
      badges[key] = _parseColorHex(value);
    });
    tags.forEach((key, value) {
      tags[key][1] = COLOR_MAP[value[1]];
      tags[key][2] = COLOR_MAP[value[2]];
    });
    if (!mounted) return;
    setState(() {
      _stage = 10;
    });
    await _rq.provider.setSystemProperties(badges, tags);
    if (!mounted) return;
    setState(() {
      _stage = 11;
    });
    _rq.provider.setReady(true);
    if (!mounted) return;
    setState(() {
      _stage = 12;
      _curStatus = FlutterI18n.translate(context, "complete");
    });
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) {
      return HomePage();
    }));
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          new Expanded(
            child: new Stack(
              children: <Widget>[
                new Image.asset(
                  "assets/images/launch_img.jpg",
                  fit: BoxFit.cover,
                ),
                new Container(
                  color: Colors.black.withAlpha(127),
                ),
                new Container(
                  padding: EdgeInsets.all(24),
                  alignment: AlignmentDirectional.bottomCenter,
                  child: new Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      new Text(
                        "F  I  M  T  A  L  E",
                        textScaleFactor: 3,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w100,
                        ),
                      ),
                      SizedBox(
                        height: 12,
                      ),
                      new Text(
                        _welcomeWord,
                        textScaleFactor: 1.2,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 4),
                      ),
                    ],
                  ),
                )
              ],
              fit: StackFit.expand,
            ),
          ),
          new LinearProgressIndicator(
            backgroundColor: Colors.teal[100],
            value: _stage / _totalStage,
            valueColor: new AlwaysStoppedAnimation<Color>(Colors.teal),
          ),
          new Container(
            padding: EdgeInsets.all(24),
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                new Text((_stage < _totalStage
                        ? (_stage + 1).toString() +
                            "/" +
                            _totalStage.toString() +
                            " "
                        : "") +
                    _curStatus),
                new Text("Copyright © 2018-" +
                    DateTime.now().year.toString() +
                    " fimtale.com"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
