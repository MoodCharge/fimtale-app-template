import 'package:fimtale/library/request_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//黑名单页面

class Blacklist extends StatefulWidget {
  final value;

  Blacklist({Key key, this.value}) : super(key: key);

  @override
  _BlacklistState createState() => new _BlacklistState(value);
}

class _BlacklistState extends State<Blacklist> {
  var value;
  List _blacklist = [];
  int _mainID = 0;
  String _pageTitle, _interface, _target, _searchText = "";
  RequestHandler _rq;
  TextEditingController _sec = TextEditingController();

  //构造函数，把传入的值传给类内的私有变量。
  _BlacklistState(value) {
    this.value = value;
    this._pageTitle = value["PageTitle"];
    this._interface = value["Interface"];
    this._target = value["Target"];
    if (value["MainID"] != null) this._mainID = value["MainID"];
    this._blacklist = value["Blacklist"];
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
  }

  @override
  void dispose() {
    _sec.dispose();
    super.dispose();
  }

  //屏蔽人/解除屏蔽
  _toggleBlock(int id, int index) {
    switch (_interface) {
      case "channel":
        break;
      case "user":
        switch (_target) {
          case "tag":
            if (mounted)
              setState(() {
                _blacklist[index]["Status"] = "pending";
              });
            _rq.manage(id, 5, "Block", (res) {
              Toast.show(FlutterI18n.translate(context, "complete"), context);
              if (mounted)
                setState(() {
                  _blacklist[index]["Status"] =
                      res["Message"] == 1 ? null : "unblocked";
                });
            });
            break;
          case "user":
            if (mounted)
              setState(() {
                _blacklist[index]["Status"] = "pending";
              });
            _rq.manage(id, 3, "Block", (res) {
              Toast.show(FlutterI18n.translate(context, "complete"), context);
              if (mounted)
                setState(() {
                  _blacklist[index]["Status"] =
                      res["Message"] == 1 ? null : "unblocked";
                });
            });
            break;
        }
    }
  }

  //根据用户或者标签选择不同的渲染头像的方式。
  Widget _getAvatar(int id) {
    switch (_target) {
      case "user":
        return _rq.renderer.userAvatar(id, size: "small");
      case "tag":
        return Icon(Icons.local_offer);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_pageTitle),
      ),
      body: ListView.builder(
        itemCount: _blacklist.length + 1,
        itemBuilder: (context, index) {
          if (index <= 0)
            return Container(
              padding: EdgeInsets.all(12),
              child: TextField(
                controller: _sec,
                maxLines: 1,
                onChanged: (text) {
                  if (mounted)
                    setState(() {
                      _searchText = text;
                    });
                },
                style: TextStyle(fontSize: 18.0),
                decoration: InputDecoration(
                    icon: Icon(Icons.search),
                    labelText: FlutterI18n.translate(context, "search")),
              ),
            );
          else
            index = index - 1;
          return _searchText.length <= 0 ||
                  _blacklist[index]["Name"].contains(_searchText)
              ? ListTile(
                  leading: _getAvatar(_blacklist[index]["ID"]),
                  title: Text(_blacklist[index]["Name"]),
                  trailing: IconButton(
                    icon: Icon(_blacklist[index]["Status"] == "pending"
                        ? Icons.more_horiz
                        : (_blacklist[index]["Status"] == "unblocked"
                            ? Icons.block
                            : Icons.panorama_fish_eye)),
                    onPressed: () {
                      _toggleBlock(_blacklist[index]["ID"], index);
                    },
                  ),
                )
              : SizedBox(
                  height: 0,
                );
        },
      ),
    );
  }
}
