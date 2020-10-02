import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:toast/toast.dart';

class UserList extends StatefulWidget {
  final value;

  UserList({Key key, this.value}) : super(key: key);

  @override
  _UserListState createState() => new _UserListState(value);
}

class _UserListState extends State<UserList> {
  var value;
  String _pageTitle = "", _url = "";
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _UserListState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    if (value.containsKey("PageTitle")) _pageTitle = value["PageTitle"];
    if (value.containsKey("Url")) _url = value["Url"];
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: ["Users"]);
    _getUsers();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getUsers();
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Users");
    await _getUsers();
    return;
  }

  _getUsers() async {
    if (_url.length > 0) {
      _rq.updateListByName(_url, "Users", (data) {
        return {
          "List": data["UsersArray"],
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
    } else if (value.containsKey("UsersArray")) {
      _rq.setListByName("Users", value["UsersArray"]);
      _rq.setCurPage("Users", 1);
      _rq.setTotalPage("Users", 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> userList = _rq.renderer.userList(_rq.getListByName("Users"));
    if (_rq.isLoading("Users"))
      userList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Users") >= _rq.getTotalPage("Users"))
      userList.add(_rq.renderer.endNotice());
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(_pageTitle),
      ),
      body: Container(
        child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: userList,
              controller: _sc,
            )),
      ),
    );
  }
}
