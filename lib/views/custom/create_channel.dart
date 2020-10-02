import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

//创建频道的页面，和登陆页面差不多。

class CreateChannel extends StatefulWidget {
  CreateChannel({Key key}) : super(key: key);

  @override
  _CreateChannelState createState() => new _CreateChannelState();
}

class _CreateChannelState extends State<CreateChannel> {
  bool _isCreating = false;
  RequestHandler _rq;
  TextEditingController _tc = TextEditingController(),
      _dc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
  }

  @override
  void dispose() {
    _tc.dispose();
    _dc.dispose();
    super.dispose();
  }

  //创建频道。
  _createChannel() async {
    if (_isCreating) return;

    var verifyInfo = await _rq.getCaptcha();
    if (!verifyInfo["Success"]) {
      Toast.show(
          FlutterI18n.translate(context, "verify_code_get_failed"), context);
      return;
    }

    if (!mounted) return;

    setState(() {
      _isCreating = true;
    });

    Map<String, dynamic> params = {
      "Name": _tc.text,
      "Description": _dc.text,
      "tencentCode": verifyInfo["Ticket"],
      "tencentRand": verifyInfo["RandStr"]
    };

    _rq.manage(
        _rq.provider.UserID,
        9,
        "CreateChannel",
        (res) {
          if (!mounted) return;
          setState(() {
            _isCreating = true;
          });
          _rq.launchURL(res["Message"], replaceCurrentPage: true);
        },
        params: params,
        onError: (err) {
          if (!mounted) return;
          setState(() {
            _isCreating = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "create_channel")),
      ),
      body: ListView(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(12.0),
            child: TextField(
              controller: _tc,
              maxLines: 1,
              maxLength: 20,
              style: TextStyle(fontSize: 18.0),
              decoration: InputDecoration(
                  labelText: FlutterI18n.translate(context, "channel_name")),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: TextField(
              controller: _dc,
              maxLines: 5,
              maxLength: 140,
              style: TextStyle(fontSize: 18.0),
              decoration: InputDecoration(
                  labelText: FlutterI18n.translate(context, "channel_desc")),
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: RaisedButton(
                child: Text(FlutterI18n.translate(context, "submit")),
                onPressed: _createChannel),
          ),
        ],
      ),
    );
  }
}
