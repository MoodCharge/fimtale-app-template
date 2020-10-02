import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//频道话题列表。所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class ChannelHashTopic extends StatefulWidget {
  final value;

  ChannelHashTopic({Key key, this.value}) : super(key: key);

  @override
  _ChannelHashTopicState createState() => new _ChannelHashTopicState(value);
}

class _ChannelHashTopicState extends State<ChannelHashTopic> {
  var value;
  int _channelID = 0;
  String _queryString = "";
  Map<String, dynamic> _channelInfo = {};
  TextEditingController _sec = TextEditingController();
  ScrollController _sc = new ScrollController();
  Timer _set;
  RequestHandler _rq;

  _ChannelHashTopicState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    if (value.containsKey("ChannelID")) _channelID = value["ChannelID"];
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: ["HashTopics"]);
    _getHashTopics();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getHashTopics();
      }
    });
    _sec.addListener(() {
      if (_set != null) {
        _set.cancel();
        _set = null;
      }
      _set = Timer(Duration(seconds: 1), () {
        if (_queryString != _sec.text) {
          _queryString = _sec.text;
          _refresh();
        }
      });
    });
  }

  @override
  void dispose() {
    if (_set != null) _set.cancel();
    _sc.dispose();
    _sec.dispose();
    super.dispose();
  }

  //刷新页面。
  Future<Null> _refresh() async {
    _rq.clearOrCreateList("HashTopics");
    await _getHashTopics();
    return;
  }

  //获取频道的话题。
  _getHashTopics() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_channelID > 0) {
      _rq.updateListByName(
          "/api/v1/channel/" + _channelID.toString() + "/hashtopics",
          "HashTopics",
          (data) {
            _channelInfo = data["ChannelInfo"];
            return {
              "List": data["HashTopicsArray"],
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
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "hash_topics") +
            " - " +
            _rq.renderer.extractFromTree(_channelInfo, ["Name"], "")),
      ),
      body: Container(
        child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: _buildHashTopicList(),
              controller: _sc,
            )),
      ),
    );
  }

  //返回一个渲染好的话题列表。
  List<Widget> _buildHashTopicList() {
    List<Widget> res = [];
    res.add(Container(
      padding: EdgeInsets.all(12.0),
      child: TextField(
        controller: _sec,
        maxLines: 1,
        style: TextStyle(fontSize: 18.0),
        decoration: InputDecoration(
            icon: Icon(Icons.search),
            labelText: FlutterI18n.translate(context, "search")),
      ),
    ));
    _rq.getListByName("HashTopics").forEach((element) {
      res.add(ListTile(
        title: Text(_rq.renderer.extractFromTree(element, ["HashTopic"], "")),
        subtitle: RichText(
          maxLines: 1,
          text: TextSpan(
            children: <InlineSpan>[
              WidgetSpan(
                child: Icon(
                  Icons.forum,
                  color: Colors.deepPurple[400],
                  size: 18,
                ),
              ),
              TextSpan(
                text: " " +
                    _rq.renderer
                        .extractFromTree(element, ["Frequency"], 0)
                        .toString() +
                    " ",
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                ),
              ),
              WidgetSpan(
                child: Icon(
                  Icons.schedule,
                  color: Colors.blue[600],
                  size: 18,
                ),
              ),
              TextSpan(
                text: " " +
                    _rq.renderer.formatTime(_rq.renderer
                        .extractFromTree(element, ["LastTime"], 0)) +
                    " " +
                    _rq.renderer.extractFromTree(element, ["LastUser"], "") +
                    " ",
                style: TextStyle(
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          Navigator.of(context).pop(element["HashTopic"]);
        },
      ));
    });
    if (_rq.isLoading("HashTopics"))
      res.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("HashTopics") >= _rq.getTotalPage("HashTopics"))
      res.add(_rq.renderer.endNotice());
    return res;
  }
}
