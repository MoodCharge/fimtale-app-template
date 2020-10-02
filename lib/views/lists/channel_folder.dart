import 'package:fimtale/library/request_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

//频道文件夹的显示。所有lists目录中的内容都有着差不多的结构，这里仅在topic.dart做详细注释。

class ChannelFolder extends StatefulWidget {
  final value;

  ChannelFolder({Key key, this.value}) : super(key: key);

  @override
  _ChannelFolderState createState() => new _ChannelFolderState(value);
}

class _ChannelFolderState extends State<ChannelFolder> {
  var value;
  String _channelName = "";
  RequestHandler _rq;
  Map<String, dynamic> _folders = {};

  _ChannelFolderState(value) {
    if (!(value is Map)) {
      value = {};
    }
    this.value = value;
    if (value.containsKey("ChannelName")) _channelName = value["ChannelName"]; //传入频道名。
    if (value.containsKey("Folders")) {
      if (value["Folders"] is Map) {
        _folders = Map.from(value["Folders"]); //传入频道的文件夹信息。
      } else {
        _folders = {};
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(
            FlutterI18n.translate(context, "folders") + " - " + _channelName),
      ),
      body: ListView(
        children: _buildFolderList(),
      ),
    );
  }

  //返回一个渲染好的文件夹列表。
  List<Widget> _buildFolderList() {
    List<Widget> res = [];
    _folders.forEach((key, value) {
      bool isPublic = value.containsKey("IsPublic") && value["IsPublic"],
          isHoldingBallot = value.containsKey("BallotInfo");
      res.add(ListTile(
        leading: Icon(isPublic ? Icons.folder_shared : Icons.folder),
        title: Text(key),
        subtitle: Text(value["Collections"].toString() +
            FlutterI18n.translate(context, "topics") +
            " " +
            FlutterI18n.translate(
                context, (isPublic ? "shared_" : "") + "folder") +
            (isHoldingBallot
                ? "," + FlutterI18n.translate(context, "holding_ballot")
                : "")),
        onTap: () {
          Navigator.of(context).pop(key);
        },
      ));
    });
    return res;
  }
}
