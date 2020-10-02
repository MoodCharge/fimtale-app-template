import 'package:flutter/material.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class ChannelList extends StatefulWidget {
  final value;

  ChannelList({Key key, this.value}) : super(key: key);

  @override
  _ChannelListState createState() => new _ChannelListState(value);
}

class _ChannelListState extends State<ChannelList> {
  var value;
  String _queryString = "", _sortBy = "";
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _ChannelListState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    if (value.containsKey("Q")) _queryString = value["Q"];
    if (value.containsKey("SortBy")) _sortBy = value["SortBy"];
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: ["Channels"]);
    _getChannels();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getChannels();
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  //刷新页面
  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Channels");
    await _getChannels();
    return;
  }

  //获取频道
  _getChannels() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_sortBy.length > 0) params["sortby"] = _sortBy;
    _rq.updateListByName(
        "/api/v1/channels",
        "Channels",
        (data) {
          return {
            "List": data["ChannelsArray"],
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

  @override
  Widget build(BuildContext context) {
    List<Widget> channelList =
        _rq.renderer.channelList(_rq.getListByName("Channels"));
    if (_rq.isLoading("Channels"))
      channelList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Channels") >= _rq.getTotalPage("Channels"))
      channelList.add(_rq.renderer.endNotice());
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "channels") +
            (_queryString.length > 0
                ? "(" +
                    FlutterI18n.translate(context, "search") +
                    ":" +
                    _queryString +
                    ")"
                : "")),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearch(
                  context: context,
                  delegate: SearchPage(
                    currentSearchTarget: "channel",
                    template: "channel",
                    queryString: _queryString,
                    currentSortBy: _sortBy,
                  ));
            },
          ),
        ],
      ),
      body: Container(
        child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: channelList,
              controller: _sc,
            )),
      ),
    );
  }
}
