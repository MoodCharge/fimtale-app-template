import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/viewers/topic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class HistoryList extends StatefulWidget {
  final value;

  HistoryList({Key key, this.value}) : super(key: key);

  @override
  _HistoryListState createState() => new _HistoryListState(value);
}

class _HistoryListState extends State<HistoryList> {
  var value;
  RequestHandler _rq;
  ScrollController _sc = new ScrollController();

  _HistoryListState(value) {
    this.value = value;
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: ["Topics"]);
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getHistoryTopics();
      }
    });
    _getHistoryTopics();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //刷新页面。
  Future<void> _refresh() async {
    _rq.clearOrCreateList("Topics");
    await _getHistoryTopics();
    return null;
  }

  //显示历史作品信息。
  _getHistoryTopics() {
    _rq.updateListByName("/api/v1/history", "Topics", (data) {
      List temp = data["HistoryTopics"],
          temp2 = _rq.getListByName("Topics"),
          res = [];
      temp.forEach((element) {
        if (!temp2.any((element2) => element2["ID"] == element["ID"]))
          res.add(element);
      });
      return {
        "List": res,
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

  //擦除历史。
  _eraseHistory(int id) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(FlutterI18n.translate(
                context, "confirm_" + (id > 0 ? "deletion" : "clear"))),
            content:
                Text(FlutterI18n.translate(context, "action_is_irreversible")),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  _rq.manage(id, 9, 'EraseHistory', (res) {
                    if (id > 0) {
                      _rq.setCurPage("Topics", _rq.getCurPage("Topics") - 1);
                      List temp = _rq.getListByName("Topics");
                      temp.removeWhere((element) => element["ID"] == id);
                      _rq.setListByName("Topics", temp);
                      _getHistoryTopics();
                    } else {
                      setState(() {
                        _rq.clearOrCreateList("Topics");
                      });
                    }
                  });
                  Navigator.of(context).pop(this);
                },
                child: Text(FlutterI18n.translate(context, "confirm")),
              ),
              FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(this);
                },
                child: Text(FlutterI18n.translate(context, "quit")),
              )
            ],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "history")),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              _eraseHistory(0);
            },
          )
        ],
      ),
      body: new RefreshIndicator(
        child: new ListView(
          controller: _sc,
          children: _showHistoryContent(),
        ),
        onRefresh: _refresh,
      ),
    );
  }

  //展示历史记录内容。
  List<Widget> _showHistoryContent() {
    List<Widget> contentList = [];
    String dateStr = "";
    int now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    int index = 0;

    _rq.getListByName("Topics").forEach((element) {
      final int li = index;
      int dateCreated =
          _rq.renderer.extractFromTree(element, ["DateCreated"], 0);
      String tempTime = FlutterI18n.translate(context, "unknown");
      double progress = double.parse(
          _rq.renderer.extractFromTree(element, ["Progress"], 0.0).toString());
      if (now - dateCreated < 86400) {
        tempTime = FlutterI18n.translate(context, "within_24_hours");
      } else {
        tempTime = _rq.renderer.formatTime(dateCreated);
      }
      if (tempTime != dateStr) {
        contentList.add(Container(
          padding: EdgeInsets.all(12),
          child: _rq.renderer
              .pageSubtitle(tempTime, textColor: Theme.of(context).accentColor),
        ));
        dateStr = tempTime;
      }
      contentList.add(ListTile(
        title: Text(_rq.renderer.extractFromTree(element, ["Title"], "")),
        subtitle: Text(FlutterI18n.translate(context, "reading") +
            (progress >= 1
                ? FlutterI18n.translate(context, "complete")
                : (FlutterI18n.translate(context, "continuing") +
                    " " +
                    FlutterI18n.translate(context, "progress") +
                    (progress * 100).toStringAsFixed(1) +
                    "%"))),
        trailing: IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            if (element["ID"] != null && element["ID"] > 0)
              _eraseHistory(element["ID"]);
          },
        ),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            var v = {
              "TopicID": _rq.renderer.extractFromTree(element, ["MainID"], 0)
            };
            List<int> from = List<int>.from(
                _rq.renderer.extractFromTree(element, ["From"], []));
            if (from.length > 0) v["From"] = from;
            return TopicView(
              value: v,
            );
          })).then((value) {
            _refresh();
          });
        },
      ));
    });

    if (_rq.isLoading("Topics"))
      contentList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
      contentList.add(_rq.renderer.endNotice());
    return contentList;
  }
}
