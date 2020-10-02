import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class BlogpostList extends StatefulWidget {
  final value;

  BlogpostList({Key key, this.value}) : super(key: key);

  @override
  _BlogpostListState createState() => new _BlogpostListState(value);
}

class _BlogpostListState extends State<BlogpostList> {
  var value;
  String _queryString = "", _sortBy = "";
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _BlogpostListState(value) {
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
    _rq = new RequestHandler(context, listNames: ["Blogposts"]);
    _getBlogposts();
    _sc.addListener(() {
      if (_sc.position.pixels >= _sc.position.maxScrollExtent - 400) {
        _getBlogposts();
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
    _rq.clearOrCreateList("Blogposts");
    await _getBlogposts();
    return;
  }

  //获取博文。
  _getBlogposts() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_sortBy.length > 0) params["sortby"] = _sortBy;
    _rq.updateListByName(
        "/api/v1/blogposts",
        "Blogposts",
        (data) {
          return {
            "List": data["BlogpostsArray"],
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
    List<Widget> blogpostList =
        _rq.renderer.blogpostList(_rq.getListByName("Blogposts"));
    if (_rq.isLoading("Blogposts"))
      blogpostList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Blogposts") >= _rq.getTotalPage("Blogposts"))
      blogpostList.add(_rq.renderer.endNotice());
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "blogposts") +
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
                    currentSearchTarget: "blogpost",
                    template: "blogpost",
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
              children: blogpostList,
              controller: _sc,
            )),
      ),
    );
  }
}
