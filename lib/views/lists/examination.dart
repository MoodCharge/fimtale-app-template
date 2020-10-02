import 'package:flutter/material.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class ExaminationList extends StatefulWidget {
  final value;

  ExaminationList({Key key, this.value}) : super(key: key);

  @override
  _ExaminationListState createState() => new _ExaminationListState(value);
}

class _ExaminationListState extends State<ExaminationList> {
  var value;
  String _queryString = "", _sortBy = "";
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _ExaminationListState(value) {
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
    _getExaminationTopics();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getExaminationTopics();
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  //刷新页面。
  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Topics");
    await _getExaminationTopics();
    return;
  }

  //获取审核中的作品。
  _getExaminationTopics() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_sortBy.length > 0) params["sortby"] = _sortBy;
    _rq.updateListByName(
        "/api/v1/examination",
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
          if(mounted) setState(() {});
        },
        afterUpdate: (list) {
          if(mounted) setState(() {});
        },
        onError: (err) {
          Toast.show(err, context,
              duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
        });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> contentList =
        _rq.renderer.topicList(_rq.getListByName("Topics"));
    if (_rq.isLoading("Topics"))
      contentList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
      contentList.add(_rq.renderer.endNotice());
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "examination_queue") +
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
                    currentSearchTarget: "Examination",
                    template: "Examination",
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
              children: contentList,
              controller: _sc,
            )),
      ),
    );
  }
}
