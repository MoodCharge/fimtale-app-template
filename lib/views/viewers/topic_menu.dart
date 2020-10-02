import 'package:fimtale/library/renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

class TopicMenu extends StatefulWidget {
  final value;

  TopicMenu({Key key, @required this.value}) : super(key: key);

  @override
  _TopicMenuState createState() => new _TopicMenuState(value);
}

class _TopicMenuState extends State<TopicMenu> {
  var value;
  List _menu;
  int _currentChapterID = 0;
  Renderer _renderer;

  _TopicMenuState(value) {
    this.value = value;
    this._menu = this.value["Menu"];
    this._currentChapterID = this.value["CurID"];
  }

  @override
  void initState() {
    super.initState();
    _renderer = new Renderer(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "menu")),
      ),
      body: new ListView.builder(
        itemCount: _menu.length,
        itemBuilder: (BuildContext context, int index) {
          var tID = _renderer.extractFromTree(_menu[index], ["ID"], 0);
          return ListTile(
            title: Text(
              "$index " +
                  _renderer.extractFromTree(_menu[index], ["Title"], ""),
              style: tID == _currentChapterID
                  ? TextStyle(color: Colors.blue)
                  : null,
            ),
            onTap: () {
              Navigator.of(context).pop(tID);
            },
          );
        },
      ),
    );
  }
}
