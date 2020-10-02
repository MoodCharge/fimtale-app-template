import 'dart:async';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//选择联系人、搜索用户（一般用于艾特界面或者分享界面，选择用户之后，返回用户名，没有用户名则返回null）

class ContactSelector extends StatefulWidget {
  ContactSelector({Key key}) : super(key: key);

  @override
  _ContactSelectorState createState() => new _ContactSelectorState();
}

class _ContactSelectorState extends State<ContactSelector>
    with TickerProviderStateMixin {
  List _friends = [], _contacts = [], _searchResult = [];
  String _queryString = "";
  TabController _tc;
  bool _isLoading = false;
  RequestHandler _rq;
  TextEditingController _sec = TextEditingController();
  Timer _set;

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
    _tc = TabController(length: 3, vsync: this);
    _loadingContacts();
    _sec.addListener(() {
      if (_set != null) {
        _set.cancel();
        _set = null;
      }
      _set = Timer(Duration(seconds: 1), () {
        if (_queryString.indexOf(_sec.text) < 0) {
          _queryString = _sec.text;
          _search();
        }
      }); //这个是一个延迟设定，只要搜索框中的内容改变，且1秒之内不再改变，就开始搜索。
    });
  }

  @override
  void dispose() {
    if (_set != null) _set.cancel();
    _tc.dispose();
    _sec.dispose();
    super.dispose();
  }

  //加载联系人。
  _loadingContacts() async {
    var result = await _rq.request("/api/v1/json/getContact");
    if (result["Status"] == 1) {
      if (!mounted) return;
      setState(() {
        _contacts = result["InboxArr"];
        _friends = result["FriendArr"];
      });
    } else {
      Toast.show(result["ErrorMessage"], context);
    }
  }

  //搜索用户。
  _search() async {
    if (_isLoading) return;
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["UserName"] = _queryString;
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    var result = await _rq.request("/api/v1/json/getUsersWithSimilarName",
        params: params);
    if (result["Status"] == 1) {
      if (!mounted) return;
      setState(() {
        _searchResult = result["UsersArray"];
        _isLoading = false;
      });
    } else {
      Toast.show(result["ErrorMessage"], context);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "choose_user")),
      ),
      body: Container(
        child: DefaultTabController(
          length: 3,
          child: Column(
            children: <Widget>[
              Container(
                child: Material(
                  child: TabBar(
                    controller: _tc,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 2.0,
                    tabs: <Widget>[
                      Tab(text: FlutterI18n.translate(context, "contacts")),
                      Tab(text: FlutterI18n.translate(context, "friends")),
                      Tab(text: FlutterI18n.translate(context, "search"))
                    ],
                  ),
                ),
              ),
              Flexible(
                child: TabBarView(
                  controller: _tc,
                  children: <Widget>[
                    _displayUserList(context, _contacts),
                    _displayUserList(context, _friends),
                    _displayUserList(context, _searchResult, search: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  //显示用户列表（简单版本的，每个用户只有一个ListTile）。
  Widget _displayUserList(BuildContext context, List usersArray,
      {bool search = false}) {
    return ListView.builder(
      itemCount: usersArray.length + (search ? 1 : 0),
      itemBuilder: (context, index) {
        if (search) {
          if (index <= 0)
            return Container(
              padding: EdgeInsets.all(12),
              child: TextField(
                controller: _sec,
                maxLines: 1,
                style: TextStyle(fontSize: 18.0),
                decoration: InputDecoration(
                    icon: Icon(Icons.search),
                    labelText: FlutterI18n.translate(context, "search")),
              ),
            );
          else
            index = index - 1;
        }
        return ListTile(
          leading: _rq.renderer.userAvatar(usersArray[index]["ID"]),
          title: Text(usersArray[index]["UserName"]),
          onTap: () {
            Navigator.pop(context, usersArray[index]["UserName"]);
          },
        );
      },
    );
  }
}
