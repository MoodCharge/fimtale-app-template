import 'dart:convert';
import 'package:fimtale/library/renderer.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:fimtale/views/lists/channel.dart';
import 'package:fimtale/views/lists/tag.dart';
import 'package:flutter/material.dart';
import 'package:fimtale/views/lists/blogpost.dart';
import 'package:fimtale/views/lists/topic.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

class SearchPage extends SearchDelegate<String> {
  Map<String, dynamic> _searchTargetList = {
    "作品": "topic",
    "用户": "user",
    "标签": "tag",
    "频道": "channel",
    "博文": "blogpost"
  },
      _sortByList = {},
      _filterList = {};
  String _searchTarget = "topic", _sortBy = "";
  bool _openNewPage = true;
  Map<String, dynamic> queryResult = {};

  SearchPage(
      {String queryString,
      String currentSearchTarget,
      String currentSortBy,
      String template,
      Map<String, dynamic> sortByList,
      Map<String, dynamic> filterList,
      bool openNewPage = true}) {
    if (queryString != null) query = queryString;
    if (currentSearchTarget != null) _searchTarget = currentSearchTarget;
    if (currentSortBy != null) _sortBy = currentSortBy;
    if (template != null) _initSortByAndFilterTemplate(template);
    if (sortByList != null) _sortByList = sortByList;
    if (filterList != null) _filterList = filterList;
    if (_sortByList.isNotEmpty) {
      if (_sortByList.containsValue("default"))
        _sortBy = "default";
      else
        _sortBy = _sortByList[_sortByList.keys.toList()[0]];
    }
    _openNewPage = openNewPage;
  }

  _initSortByAndFilterTemplate(String type) {
    switch (type) {
      case "blogpost":
        _sortByList = {
          "默认排序": "default",
          "发表时间": "posttime",
          "收藏数": "followers"
        };
        break;
      case "channel":
        _sortByList = {
          "默认排序": "default",
          "更新时间": "updated",
          "关注人数": "followers",
          "评分": "rating"
        };
        break;
      case "tag":
        _sortByList = {
          "默认排序": "default",
          "更新时间": "updated",
          "关注人数": "followers",
          "总作品数": "topicsum"
        };
        break;
      case "topic":
        _sortByList = {
          "默认排序": "default",
          "发表时间": "publish",
          "更新时间": "update",
          "最后评论": "lasttime",
          "字数": "wordcount",
          "评论数": "replies",
          "浏览量": "views",
          "评分": "rating"
        };
        _filterList = {
          "最近7天内发表": "posted:-7",
          "最近1个月内发表": "posted:-30",
          "最近7天内有更新": "updated:-7",
          "最近1个月内有更新": "updated:-30",
          "字数较少（1万字以内）": "characters:-10000",
          "字数中等（1万字~10万字）": "characters:10000-100000",
          "字数较多（10万字以上）": "characters:100000-",
          "温和型（滤去Restricted分级）": "rating:et",
          "激烈型（滤去Everyone分级）": "rating:tr"
        };
        break;
    }
  }

  _search(BuildContext context) async {
    if (_openNewPage) {
      switch (_searchTarget) {
        case "blogpost":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return BlogpostList(
              value: {"Q": query, "SortBy": _sortBy},
            );
          }));
          break;
        case "channel":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return ChannelList(
              value: {"Q": query, "SortBy": _sortBy},
            );
          }));
          break;
        case "tag":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return TagList(
              value: {"Q": query, "SortBy": _sortBy},
            );
          }));
          break;
        case "topic":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return TopicList(
              value: {"Q": query, "SortBy": _sortBy},
            );
          }));
          break;
        case "user":
          Navigator.push(context, MaterialPageRoute(builder: (context) {
            return UserView(
              value: {"UserName": query},
            );
          }));
          break;
      }
    } else {
      close(
          context, jsonEncode({"Search": true, "Q": query, "SortBy": _sortBy}));
    }
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.search),
        onPressed: () {
          _search(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: AnimatedIcon(
          icon: AnimatedIcons.menu_arrow, progress: transitionAnimation),
      onPressed: () {
        if (query.isEmpty) {
          close(context, jsonEncode({"Search": false}));
        } else {
          query = "";
          showSuggestions(context);
        }
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return buildSelectionList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildSelectionList(context);
  }

  Widget buildSelectionList(BuildContext context) {
    Renderer _renderer = new Renderer(context);
    List<Widget> listItems = [
      ListTile(
        title: Text(FlutterI18n.translate(context, "search_target")),
        trailing: DropdownButton(
          items: _renderer.map2DropdownMenu(_searchTargetList),
          value: _searchTarget,
          onChanged: (T) {
            _searchTarget = T;
            showSuggestions(context);
          },
        ),
      )
    ];

    if (_sortByList.isNotEmpty) {
      listItems.add(ListTile(
        title: Text(FlutterI18n.translate(context, "sort_by")),
        trailing: DropdownButton(
          items: _renderer.map2DropdownMenu(_sortByList),
          value: _sortBy,
          onChanged: (T) {
            _sortBy = T;
            showSuggestions(context);
          },
        ),
      ));
    }

    if (_filterList.isNotEmpty) {
      List<Widget> chipItems = [];

      _filterList.forEach((key, value) {
        chipItems.add(GestureDetector(
          child: Chip(label: Text(key)),
          onTap: () {
            if (query.length <= 0) {
              query = query + value;
            } else {
              query = query + " " + value;
            }
          },
        ));
      });

      listItems.addAll([
        ListTile(
          title: Text(FlutterI18n.translate(context, "filters")),
        ),
        Container(
          padding: EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            children: chipItems,
          ),
        )
      ]);
    }

    return ListView(
      children: listItems,
    );
  }
}
