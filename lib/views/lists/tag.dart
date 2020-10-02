import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';
import 'package:fimtale/library/app_provider.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:toast/toast.dart';

class TagList extends StatefulWidget {
  final value;

  TagList({Key key, this.value}) : super(key: key);

  @override
  _TagListState createState() => new _TagListState(value);
}

class _TagListState extends State<TagList> {
  var value;
  String _queryString = "", _sortBy = "";
  AppInfoProvider _provider;
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _TagListState(value) {
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
    _provider = Provider.of<AppInfoProvider>(context, listen: false);
    _rq = new RequestHandler(context, listNames: ["Tags"]);
    _getTags();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getTags();
      }
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Tags");
    await _getTags();
    return;
  }

  _getTags() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_sortBy.length > 0) params["sortby"] = _sortBy;
    _rq.updateListByName(
        "/api/v1/tags",
        "Tags",
        (data) {
          return {
            "List": data["TagsArray"],
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
    List<Widget> tagList = _rq.renderer.tagList(_rq.getListByName("Tags"));
    if (_rq.isLoading("Tags"))
      tagList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Tags") >= _rq.getTotalPage("Tags"))
      tagList.add(_rq.renderer.endNotice());
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "tags") +
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
                    currentSearchTarget: "tag",
                    template: "tag",
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
              children: tagList,
              controller: _sc,
            )),
      ),
    );
  }
}
