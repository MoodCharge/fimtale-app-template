import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:markdown_widget/config/style_config.dart';
import 'package:markdown_widget/markdown_generator.dart';
import 'package:provider/provider.dart';
import 'package:fimtale/library/app_provider.dart';
import 'package:fimtale/views/lists/search_page.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:toast/toast.dart';

//标签、频道、用户三个页面的原理大同小异。仅在viewers/channel.dart进行详细注释，就不在其它两个页面做多余注释了。

class TagView extends StatefulWidget {
  final value;

  TagView({Key key, @required this.value}) : super(key: key);

  @override
  _TagViewState createState() => new _TagViewState(value);
}

class _TagViewState extends State<TagView> {
  var value;
  String _tagName = "", _queryString = "", _sortBy = "";
  Map<String, dynamic> _tagInfo = {};
  AppInfoProvider _provider;
  ScrollController _sc = new ScrollController();
  RequestHandler _rq;

  _TagViewState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    _tagName = value["TagName"];
    if (value.containsKey("Q")) _queryString = value["Q"];
    if (value.containsKey("SortBy")) _sortBy = value["SortBy"];
  }

  @override
  void initState() {
    super.initState();
    _provider = Provider.of<AppInfoProvider>(context, listen: false);
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

  //刷新页面。
  Future<Null> _refresh() async {
    _rq.clearOrCreateList("Topics");
    await _getTopics();
    return;
  }

  //获取作品。
  _getTopics() async {
    Map<String, dynamic> params = {};
    if (_queryString.length > 0) params["q"] = _queryString;
    if (_sortBy.length > 0) params["sortby"] = _sortBy;
    _rq.updateListByName(
        "/api/v1/tag/" + Uri.encodeComponent(_tagName),
        "Topics",
        (data) {
          _tagInfo = Map<String, dynamic>.from(data["TagInfo"]);
          return {
            "List": data["TopicsArray"],
            "CurPage": data["Page"],
            "TotalPage": data["TotalPage"]
          };
        },
        params: params,
        beforeRequest: () {
          setState(() {});
        },
        afterUpdate: (list) {
          setState(() {});
        },
        onError: (err) {
          Toast.show(err, context,
              duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
        });
  }

  //处理搜索内容。
  _processSearchText(var searchInfoStr) {
    Map<String, dynamic> searchInfo =
        Map<String, dynamic>.from(jsonDecode(searchInfoStr));
    if (searchInfo["Search"]) {
      _queryString = searchInfo["Q"];
      _sortBy = searchInfo["SortBy"];
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> allowedOptions = List<String>.from(
        _rq.renderer.extractFromTree(_tagInfo, ["AllowedOptions"], []));
    List<Widget> appBarActions = [
      IconButton(
        icon: Icon(Icons.search),
        onPressed: () async {
          String searchInfo = await showSearch(
              context: context,
              delegate: SearchPage(
                  currentSearchTarget: "topic",
                  template: "topic",
                  queryString: _queryString,
                  currentSortBy: _sortBy,
                  openNewPage: false));
          _processSearchText(searchInfo);
        },
      )
    ],
        topicList = _rq.renderer.topicList(_rq.getListByName("Topics"));
    if (_rq.isLoading("Topics"))
      topicList.add(_rq.renderer.preloader());
    else if (_rq.getCurPage("Topics") >= _rq.getTotalPage("Topics"))
      topicList.add(_rq.renderer.endNotice());
    if (allowedOptions.contains("favorite"))
      appBarActions.add(IconButton(
        icon: Icon(
            _tagInfo["IsFavorite"] ? Icons.favorite : Icons.favorite_border),
        onPressed: () {
          _rq.manage(_rq.renderer.extractFromTree(_tagInfo, ["ID"], 0), 4, "2",
              (res) {
            setState(() {
              if (_tagInfo["IsFavorite"])
                _tagInfo["Followers"]--;
              else
                _tagInfo["Followers"]++;
              _tagInfo["IsFavorite"] = !_tagInfo["IsFavorite"];
            });
          });
        },
      ));

    return new Scaffold(
      body: Container(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _sc,
            slivers: <Widget>[
              SliverAppBar(
                expandedHeight: 150.0,
                floating: false,
                pinned: true,
                title: Text(_tagName +
                    (_queryString.length > 0
                        ? "(" +
                            FlutterI18n.translate(context, "search") +
                            ":" +
                            _queryString +
                            ")"
                        : "")),
                actions: appBarActions,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.asset(
                        "assets/images/tag_background.jpg",
                        fit: BoxFit.cover,
                      ),
                      _rq.renderer
                              .extractFromTree(_tagInfo, ["IconExists"], false)
                          ? Image.network(
                              "https://fimtale.com/upload/tag/middle/" +
                                  _rq.renderer
                                      .extractFromTree(_tagInfo, ["ID"], 0)
                                      .toString() +
                                  ".png",
                              fit: BoxFit.cover,
                            )
                          : SizedBox(
                              height: 0,
                            ),
                      Container(
                        color: Colors.black.withAlpha(127),
                      ),
                      Container(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              _tagName,
                              textScaleFactor: 2.4,
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Wrap(
                              spacing: 3,
                              runSpacing: 0,
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.collections_bookmark,
                                  color: Colors.lightBlue,
                                ),
                                Text(
                                  _rq.renderer
                                      .extractFromTree(
                                          _tagInfo, ["TotalTopics"], 0)
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Icon(
                                  Icons.schedule,
                                  color: Colors.blue[600],
                                ),
                                Text(
                                  _rq.renderer.formatTime(_rq.renderer
                                      .extractFromTree(
                                          _tagInfo, ["LastTime"], 0)),
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Icon(
                                  Icons.favorite,
                                  color: Colors.red[300],
                                ),
                                Text(
                                  _rq.renderer
                                      .extractFromTree(
                                          _tagInfo, ["Followers"], 0)
                                      .toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                  child: Card(
                margin: EdgeInsets.all(16),
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: MarkdownGenerator(
                      data: _tagInfo["Intro"] != null &&
                              _tagInfo["Intro"].length > 0
                          ? _tagInfo["Intro"]
                          : FlutterI18n.translate(context, "no_desc"),
                      //博文简介（渲染过emoji后）
                      styleConfig: StyleConfig(
                        titleConfig: TitleConfig(),
                        pConfig: PConfig(
                          onLinkTap: (url) {
                            _rq.launchURL(url);
                          },
                        ),
                        blockQuoteConfig: BlockQuoteConfig(),
                        tableConfig: TableConfig(),
                        preConfig: PreConfig(),
                        ulConfig: UlConfig(),
                        olConfig: OlConfig(),
                        imgBuilder: (String url, attributes) {
                          return Image.network(url);
                        },
                      ),
                    ).widgets, //从用户端返回的内容为markdown格式，因此需要用MarkDownGenerator类来解析文本，使之成为flutter的组件。
                  ),
                ),
              )),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: topicList,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
