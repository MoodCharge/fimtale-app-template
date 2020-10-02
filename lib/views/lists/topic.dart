import 'package:flutter/material.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

class TopicList extends StatefulWidget {
  final value;

  TopicList({Key key, this.value}) : super(key: key);

  @override
  _TopicListState createState() => new _TopicListState(value);
}

class _TopicListState extends State<TopicList> {
  var value;
  String _queryString = "", _sortBy = "";
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _TopicListState(value) {
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
    _rq = new RequestHandler(context, listNames: ["Topics"]);
    _getTopics();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getTopics();
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Topics");
    await _getTopics();
    return;
  }

  _getTopics() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_sortBy.length > 0) params["sortby"] = _sortBy;
    _rq.updateListByName(
        "/api/v1/topics",
        "Topics",
        (data) {
          return {
            "List": data["TopicsArray"],
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
    List<Widget> topicList =
        _rq.renderer.topicList(_rq.getListByName("Topics"));
    if (_rq.isLoading("Topics"))
      topicList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
      topicList.add(_rq.renderer.endNotice());
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "topics") +
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
                    currentSearchTarget: "topic",
                    template: "topic",
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
              children: topicList,
              controller: _sc,
            )),
      ),
    );
  }
}
