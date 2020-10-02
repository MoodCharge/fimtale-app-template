import 'package:charts_flutter/flutter.dart' as chart;
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:package_info/package_info.dart';
import 'package:toast/toast.dart';

//关于页面。如果您是改APP的开发者，您可以在这个页面留下自己的名字。

class AboutPage extends StatefulWidget {
  @override
  _AboutPageState createState() => new _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  int _curIndex = 0;
  Map<String, dynamic> _statData = {};
  RequestHandler _rq;
  PackageInfo _pi;

  @override
  void initState() {
    super.initState();
    _rq = RequestHandler(context);
    PackageInfo.fromPlatform().then((value) {
      if (!mounted) return;
      setState(() {
        _pi = value;
      });
    });
    _getStat();
  }

  @override
  void dispose() {
    super.dispose();
  }

  //获取站点统计信息。
  _getStat() async {
    var result = await _rq.request("/api/v1/statistics");
    if (!mounted) return;
    if (result["Status"] == 1) {
      setState(() {
        _statData = Map<String, dynamic>.from(result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> webStatIndexList = [
      FlutterI18n.translate(context, "topics"),
      FlutterI18n.translate(context, "interactions"),
      FlutterI18n.translate(context, "users"),
      FlutterI18n.translate(context, "tags")
    ];

    return new Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "about_app")),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            title: _rq.renderer.pageSubtitle(
              FlutterI18n.translate(context, "website_statistics"),
              textColor: Theme.of(context).accentColor,
            ),
            subtitle: Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: List<Widget>.generate(4, (int index) {
                return ChoiceChip(
                  label: Text(webStatIndexList[index]),
                  selectedColor: Theme.of(context).accentColor,
                  disabledColor: Theme.of(context).disabledColor,
                  onSelected: (bool selected) {
                    setState(() {
                      _curIndex = index;
                    });
                  },
                  selected: _curIndex == index,
                  labelStyle: _curIndex == index
                      ? TextStyle(color: Colors.white)
                      : null,
                );
              }),
            ),
          ),
          Container(
            height: 400,
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _displayStatChart(),
          ),
          ListTile(
            title: Text(
              "FimTale",
              textScaleFactor: 1.5,
              textAlign: TextAlign.center,
            ),
            subtitle: Text(
              FlutterI18n.translate(
                context,
                "version_info",
                translationParams: {
                  "Version": _pi != null ? _pi.version : "",
                  "Build": _pi != null ? _pi.buildNumber : ""
                },
              ),
              textAlign: TextAlign.center,
            ),
          ),
          ListTile(
            leading: _rq.renderer.userAvatar(432),
            title: Text("立冬"),
            subtitle:
                Text(FlutterI18n.translate(context, "developed_by_flutter")),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) {
                return UserView(
                  value: {"UserName": "立冬"},
                );
              }));
            },
          ), //在这后面留下您的名字。虚位以待……
          ListTile(
            leading: Icon(Icons.monetization_on),
            title: Text(FlutterI18n.translate(context, "donate_us")),
            onTap: () {
              _rq.launchURL("https://afdian.net/@fimtale");
            },
          )
        ],
      ),
    );
  }

  //显示统计图。
  Widget _displayStatChart() {
    List<chart.Series<dynamic, String>> seriesList;
    String start = "";
    if (_statData.isEmpty) return _rq.renderer.preloader();

    switch (_curIndex) {
      case 1:
        seriesList = [
          chart.Series(
            id: "TotalPosts",
            data: _statData["TotalPosts"],
            domainFn: (data, _) => data["Date"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) => data["Date"],
          ),
          chart.Series(
            id: "DaysPosts",
            data: _statData["DaysPosts"],
            domainFn: (data, _) => data["Date"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) => data["Date"],
          )
        ];
        if (_statData["TotalPosts"].length > 4) {
          start = _statData["TotalPosts"][_statData["TotalPosts"].length - 4]
              ["Date"];
        } else {
          start = _statData["TotalPosts"][0]["Date"];
        }
        break;
      case 2:
        seriesList = [
          chart.Series(
            id: "TotalUsers",
            data: _statData["TotalUsers"],
            domainFn: (data, _) => data["Date"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) => data["Date"],
          ),
          chart.Series(
            id: "DaysUsers",
            data: _statData["DaysUsers"],
            domainFn: (data, _) => data["Date"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) => data["Date"],
          )
        ];
        if (_statData["TotalUsers"].length > 4) {
          start = _statData["TotalUsers"][_statData["TotalUsers"].length - 4]
              ["Date"];
        } else {
          start = _statData["TotalUsers"][0]["Date"];
        }
        break;
      case 3:
        seriesList = [
          chart.Series(
            id: "Tags",
            data: _statData["Tags"],
            domainFn: (data, _) => data["Name"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) =>
                data["Name"] + ":" + data["Value"].toString(),
          )
        ];
        break;
      default:
        seriesList = [
          chart.Series(
            id: "TotalTopics",
            data: _statData["TotalTopics"],
            domainFn: (data, _) => data["Date"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) => data["Date"],
          ),
          chart.Series(
            id: "DaysTopics",
            data: _statData["DaysTopics"],
            domainFn: (data, _) => data["Date"],
            measureFn: (data, _) => data["Value"],
            labelAccessorFn: (data, _) => data["Date"],
          )
        ];
        if (_statData["TotalTopics"].length > 4) {
          start = _statData["TotalTopics"][_statData["TotalTopics"].length - 4]
              ["Date"];
        } else {
          start = _statData["TotalTopics"][0]["Date"];
        }
        break;
    }

    return _curIndex == 3
        ? chart.PieChart(
            seriesList,
            defaultRenderer: chart.ArcRendererConfig(
              arcRendererDecorators: [
                chart.ArcLabelDecorator(
                  labelPosition: chart.ArcLabelPosition.inside,
                ),
              ],
            ),
            selectionModels: [
              chart.SelectionModelConfig(
                type: chart.SelectionModelType.info,
                changedListener: (chart.SelectionModel m) {
                  Toast.show(
                      m.selectedDatum[0].datum["Name"] +
                          ":" +
                          m.selectedDatum[0].datum["Value"].toString(),
                      context);
                },
              )
            ],
          )
        : chart.BarChart(
            seriesList,
            animate: true,
            behaviors: [
              chart.SlidingViewport(),
              chart.PanAndZoomBehavior(),
            ],
            selectionModels: [
              chart.SelectionModelConfig(
                type: chart.SelectionModelType.info,
                changedListener: (chart.SelectionModel m) {
                  Toast.show(
                      m.selectedDatum[0].datum["Date"] +
                          ":" +
                          m.selectedDatum[0].datum["Value"].toString(),
                      context);
                },
              )
            ],
            domainAxis: chart.OrdinalAxisSpec(
                viewport: chart.OrdinalViewport(start, 4)),
          );
  }
}
