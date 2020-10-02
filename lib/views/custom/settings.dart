import 'package:http_parser/http_parser.dart';
import 'package:dio/dio.dart';
import 'package:fimtale/views/custom/blacklist.dart';
import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image_picker/image_picker.dart';
import 'package:toast/toast.dart';

//设置页面。

class Settings extends StatefulWidget {
  Settings({Key key}) : super(key: key);

  @override
  _SettingsState createState() => new _SettingsState();
}

class _SettingsState extends State<Settings> with TickerProviderStateMixin {
  List<String> _indexList = [
    "UploadAvatar",
    "UpdateUserInfo",
    "SetGrandFilter",
    "BlackLists",
    "Console"
  ];
  Map<String, Map<String, dynamic>> _currentSettings;
  Map<String, dynamic> _messages;
  int _curIndex = 0;
  bool _isSettingsLoaded = false, _saveNeeded = false;
  RequestHandler _rq;
  TabController _tc;
  TextEditingController _ec = TextEditingController(),
      _hc = TextEditingController(),
      _ic = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
    _tc = new TabController(length: 3, vsync: this);
    _tc.addListener(() {
      if (_tc.index.toDouble() == _tc.animation.value) {
        if (_saveNeeded) _saveSettings(_indexList[_curIndex]);

        if (!mounted) return;

        setState(() {
          _curIndex = _tc.index;
        });
      }
    });
    _loadSettings();
  }

  @override
  void dispose() {
    if (_saveNeeded) _saveSettings(_indexList[_curIndex]);
    _tc.dispose();
    _ec.dispose();
    _hc.dispose();
    _ic.dispose();
    super.dispose();
  }

  //将小驼峰转为下划线格式，为了从FlutterI18n调取对应的文本
  String camel2under(String str) {
    return str
        .replaceAllMapped(RegExp(r"([a-z])([A-Z])"),
            (Match m) => "${m.group(1)}\_${m.group(2)}")
        .toLowerCase();
  }

  //将传回的设置项具体情况设置到各个页面。
  _displaySettings(rawSettings) {
    if (!mounted) return;

    setState(() {
      _currentSettings = {};
      _indexList.forEach((element) {
        _currentSettings[element] =
            Map<String, dynamic>.from(rawSettings[element]);
      });
      _messages = Map<String, dynamic>.from(rawSettings["Messages"]);
      _ec.text = rawSettings["UpdateUserInfo"]["UserMail"];
      _hc.text = rawSettings["UpdateUserInfo"]["UserHomepage"];
      _ic.text = rawSettings["UpdateUserInfo"]["UserIntro"];
      _isSettingsLoaded = true;
      _messages.forEach((key, value) {
        if (value != null && value.length > 0) Toast.show(value, context);
      });
    });
  }

  //加载设置（第一次进入的时候调用）
  _loadSettings() async {
    var result = await _rq.request("/api/v1/settings");

    if (!mounted) return;

    if (result["Status"] == 1) {
      _displaySettings(result);
    } else {
      Toast.show(result["ErrorMessage"], context);
    }
  }

  //保存设置。
  _saveSettings(String key) async {
    if (!_currentSettings.containsKey(key)) return;
    Map<String, dynamic> params = _currentSettings[key];
    params["Action"] = key;

    var result =
        await _rq.request("/api/v1/settings", method: "post", params: params);

    if (!mounted) return;

    if (result["Status"] == 1) {
      _saveNeeded = false;
      _displaySettings(result);
    } else {
      Toast.show(result["ErrorMessage"], context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "settings")),
      ),
      body: Container(
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
                          text: FlutterI18n.translate(
                              context, "basic_information")),
                      Tab(
                          text: FlutterI18n.translate(
                              context, "detailed_information")),
                      Tab(
                          text: FlutterI18n.translate(
                              context, "filter_settings")),
                    ],
                  ),
                ),
              ),
              Flexible(
                child: TabBarView(
                  controller: _tc,
                  children: <Widget>[
                    _isSettingsLoaded
                        ? ListView(
                            children: _displayBasicInfoList(),
                          )
                        : Center(
                            child: _rq.renderer.preloader(),
                          ),
                    _isSettingsLoaded
                        ? ListView(
                            children: _displayDetailedInfoList(),
                          )
                        : Center(
                            child: _rq.renderer.preloader(),
                          ),
                    _isSettingsLoaded
                        ? ListView(
                            children: _displayFilterSettingsList(),
                          )
                        : Center(
                            child: _rq.renderer.preloader(),
                          )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //显示第一栏（基础信息栏）
  List<Widget> _displayBasicInfoList() {
    List<Widget> contentList = [];
    contentList.add(ListTile(
      title: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "basic_information"),
          textColor: Theme.of(context).accentColor),
    ));
    contentList.add(ListTile(
      leading: _rq.renderer.userAvatar(_rq.provider.UserID),
      title: Text(
        _rq.provider.UserName,
        textScaleFactor: 1.25,
      ),
      subtitle:
          Text(FlutterI18n.translate(context, "tap_to_upload_new_avatar")),
      onTap: () async {
        var image = await ImagePicker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
        String path = image.path,
            name = path.substring(path.lastIndexOf("/") + 1, path.length),
            mime = name
                .substring(name.lastIndexOf(".") + 1, name.length)
                .toLowerCase();
        if (mime == "jpg") mime = "jpeg";
        print("path:" + path);
        print("name:" + name);
        print("mime:" + mime);
        _currentSettings["UploadAvatar"]["Avatar"] =
            await MultipartFile.fromFile(path,
                filename: name, contentType: MediaType("image", mime));
        _saveSettings("UploadAvatar");
      },
    )); //用户名、用户头像
    List<String> displayedBadges = [], hiddenBadges = [];
    _currentSettings["Console"]["Badges"]["Displayed"].forEach((e) {
      displayedBadges.add(e["Name"]);
    });
    _currentSettings["Console"]["Badges"]["Hidden"].forEach((e) {
      hiddenBadges.add(e["Name"]);
    });
    contentList.add(ListTile(
      leading: Icon(Icons.local_activity),
      title: Text(FlutterI18n.translate(context, "my_badges")),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  FlutterI18n.translate(context, "displayed"),
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
                Expanded(
                  child: _rq.renderer.singleLineBadges(displayedBadges),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  FlutterI18n.translate(context, "hidden"),
                  style: TextStyle(color: Theme.of(context).disabledColor),
                ),
                Expanded(
                  child: _rq.renderer.singleLineBadges(hiddenBadges),
                ),
              ],
            ),
          )
        ],
      ),
    )); //用户徽章
    contentList.add(SizedBox(
      height: 20,
    ));
    contentList.add(ListTile(
      title: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "local_settings"),
          textColor: Theme.of(context).accentColor),
    ));
    return contentList;
  }

  //显示第二栏（详细信息栏）
  List<Widget> _displayDetailedInfoList() {
    List<Widget> contentList = [];
    contentList.add(ListTile(
      title: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "detailed_information"),
          textColor: Theme.of(context).accentColor),
    ));
    contentList.add(ListTile(
      title: Text(FlutterI18n.translate(context, "gender")),
      trailing: DropdownButton(
        items: _rq.renderer.map2DropdownMenu({
          FlutterI18n.translate(context, "unknown"): "0",
          FlutterI18n.translate(context, "male"): "1",
          FlutterI18n.translate(context, "female"): "2",
        }),
        value: _currentSettings["UpdateUserInfo"]["UserSex"].toString(),
        onChanged: (temp) {
          int res = int.parse(temp);
          if (res != _currentSettings["UpdateUserInfo"]["UserSex"]) {
            _currentSettings["UpdateUserInfo"]["UserSex"] = res;
            _saveNeeded = true;
            if (mounted) setState(() {});
          }
        },
      ),
    )); //用户性别
    contentList.add(ListTile(
      title: Text(FlutterI18n.translate(context, "user_homepage")),
      subtitle: TextField(
        controller: _hc,
        maxLines: 1,
        onChanged: (text) {
          if (text != _currentSettings["UpdateUserInfo"]["UserHomepage"]) {
            _currentSettings["UpdateUserInfo"]["UserHomepage"] = text;
            _saveNeeded = true;
          }
        },
      ),
    )); //用户主页
    contentList.add(ListTile(
      title: Text(FlutterI18n.translate(context, "user_introduction")),
      subtitle: TextField(
        controller: _ic,
        maxLines: 1,
        onChanged: (text) {
          if (text != _currentSettings["UpdateUserInfo"]["UserIntro"]) {
            _currentSettings["UpdateUserInfo"]["UserIntro"] = text;
            _saveNeeded = true;
          }
        },
      ),
    )); //用户简介
    contentList.add(SizedBox(
      height: 20,
    ));
    contentList.add(ListTile(
      title: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "theme_and_preferences"),
          textColor: Theme.of(context).accentColor),
    ));
    String userBg = _currentSettings["UpdateUserInfo"]["UserPhoto"];
    contentList.add(ListTile(
      title: Text(FlutterI18n.translate(context, "user_background")),
      subtitle: Text(FlutterI18n.translate(
          context, "tap_to_" + (userBg.length > 0 ? "change" : "add"))),
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          builder: (context) {
            return SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(12),
                    child: Text(FlutterI18n.translate(
                        context, "current_user_background")),
                  ),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: userBg.length > 0
                        ? Image.network(
                            userBg,
                            fit: BoxFit.cover,
                          )
                        : Image.asset(
                            "assets/images/user_background.jpg",
                            fit: BoxFit.cover,
                          ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      FlatButton(
                        onPressed: () async {
                          var image = await ImagePicker.pickImage(
                              source: ImageSource.gallery);
                          if (image == null) return;
                          _rq.uploadImage2ImgBox(image).then((value) {
                            if (value != null) {
                              _currentSettings["UpdateUserInfo"]["UserIntro"] =
                                  value;
                              _saveNeeded = true;
                            }
                            Navigator.pop(context);
                          });
                        },
                        child: Text(FlutterI18n.translate(context, "update")),
                      ),
                      FlatButton(
                        onPressed: () {
                          _currentSettings["UpdateUserInfo"]["UserIntro"] = "";
                          _saveNeeded = true;
                          Navigator.pop(context);
                        },
                        child: Text(FlutterI18n.translate(context, "reset")),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    )); //用户背景
    contentList.add(ListTile(
      title: Text(FlutterI18n.translate(context, "theme")),
      trailing: DropdownButton(
        items: _rq.renderer.map2DropdownMenu({
          FlutterI18n.translate(context, "default_theme"): "1",
          FlutterI18n.translate(context, "fluttershy_yellow"): "2",
          FlutterI18n.translate(context, "anon_green"): "3",
          FlutterI18n.translate(context, "rainbow_dash_blue"): "4",
          FlutterI18n.translate(context, "twilight_purple"): "5",
          FlutterI18n.translate(context, "rarity_white"): "6",
          FlutterI18n.translate(context, "lyra_green"): "7",
        }),
        value: _currentSettings["UpdateUserInfo"]["Theme"].toString(),
        onChanged: (temp) {
          int res = int.parse(temp);
          if (res != _currentSettings["UpdateUserInfo"]["Theme"]) {
            _currentSettings["UpdateUserInfo"]["Theme"] = res;
            _saveSettings("UpdateUserInfo");
          }
        },
      ),
    )); //主题
    return contentList;
  }

  //显示第三栏（滤镜设置栏）
  List<Widget> _displayFilterSettingsList() {
    List<Widget> contentList = [];
    contentList.add(ListTile(
      title: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "grand_filter"),
          textColor: Theme.of(context).accentColor),
    ));
    _currentSettings["SetGrandFilter"].forEach((key, value) {
      contentList.add(SwitchListTile(
        value: value == 1,
        onChanged: (status) {
          if (!mounted) return;
          setState(() {
            _currentSettings["SetGrandFilter"][key] = status ? 1 : 0;
            _saveNeeded = true;
          });
        },
        title: Text(FlutterI18n.translate(context, camel2under(key))),
      ));
    });
    contentList.add(SizedBox(
      height: 20,
    ));
    contentList.add(ListTile(
      title: _rq.renderer.pageSubtitle(
          FlutterI18n.translate(context, "blacklists"),
          textColor: Theme.of(context).accentColor),
    ));
    _currentSettings["BlackLists"].forEach((key, value) {
      contentList.add(ListTile(
        title: Text(
            FlutterI18n.translate(context, "blocked_" + key.toLowerCase())),
        subtitle: Text(value.length.toString() +
            " " +
            FlutterI18n.translate(context, key.toLowerCase())),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return Blacklist(
              value: {
                "PageTitle": FlutterI18n.translate(
                    context, "blocked_" + key.toLowerCase()),
                "Interface": "user",
                "Target": key.toLowerCase().replaceAll(RegExp(r"s$"), ""),
                "Blacklist": List.from(value)
              },
            );
          }));
        },
      ));
    }); //大滤镜
    return contentList;
  }
}
