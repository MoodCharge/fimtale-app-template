import 'package:flutter/material.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:toast/toast.dart';

class Login extends StatefulWidget {
  Login({Key key}) : super(key: key);

  @override
  _LoginState createState() => new _LoginState();
}

class _LoginState extends State<Login> {
  int _curIndex = 0;
  var _email = "", _token = "", _loginStatus = "", _isSending = false;
  RequestHandler _rq;
  TextEditingController _ec = TextEditingController(),
      _pc = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context);
  }

  @override
  void dispose() {
    _ec.dispose();
    _pc.dispose();
    super.dispose();
  }

  //发送邮件
  _sendEmail() async {
    if (!mounted) return;

    setState(() {
      _loginStatus = "邮件正在发送中，请稍候……";
      _isSending = true;
      _email = _ec.text;
    });

    var verifyInfo = await _rq.getCaptcha();
    if (!verifyInfo["Success"]) {
      Toast.show(
          FlutterI18n.translate(context, "verify_code_get_failed"), context);
      return;
    }

    var result = await this._rq.request("/login", method: "post", params: {
      'tencentCode': verifyInfo["Ticket"],
      'tencentRand': verifyInfo["RandStr"],
      'email': _email
    });

    if (!mounted) return;

    if (result["Status"] == 1) {
      _loginStatus = result["Message"];
      setState(() {
        _isSending = false;
      });
    } else {
      print(result["ErrorMessage"]);
      _loginStatus = "";
      _isSending = false;
    }
  }

  //登录（method为方法，用账号密码登录还是用邮箱登录）
  _login(String method) async {
    setState(() {
      _loginStatus = "正在登录……";
      _email = _ec.text;
      _token = _pc.text;
    });

    Map<String, dynamic> params = {};
    if (method == "account") {
      var verifyInfo = await _rq.getCaptcha();
      if (!verifyInfo["Success"]) {
        Toast.show(
            FlutterI18n.translate(context, "verify_code_get_failed"), context);
        return;
      }
      params["account"] = _email;
      params["password"] = _token;
      params["tencentCode"] = verifyInfo["Ticket"];
      params["tencentRand"] = verifyInfo["RandStr"];
    } else {
      params["email"] = _email;
      params["verifyCode"] = _token;
    }

    var result =
        await this._rq.request("/login", method: "post", params: params);

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _loginStatus = result["Message"];
      });
      if (_loginStatus.contains("成功")) {
        var data = await this._rq.request("/api/v1/json/getMyInfo");
        if (data.containsKey("CurrentUser")) {
          await _rq.provider.initUserInfo(data["CurrentUser"]);
          await _rq.provider.saveUserInfo();
          Navigator.pop(context);
        } else {
          _loginStatus = FlutterI18n.translate(context, "login_failed");
        }
      }
    } else {
      print(result["ErrorMessage"]);
      _loginStatus = "";
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> secondInputLine = [
      Expanded(
        child: Container(
          padding: EdgeInsets.all(12.0),
          child: TextField(
            controller: _pc,
            maxLines: 1,
            style: TextStyle(fontSize: 18.0),
            obscureText: _curIndex == 0,
            decoration: InputDecoration(
                labelText: FlutterI18n.translate(
                    context, _curIndex == 1 ? "token" : "password")),
          ),
        ),
        flex: 3,
      )
    ];

    if (_curIndex == 1) {
      secondInputLine.add(Expanded(
        child: Container(
          padding: EdgeInsets.all(12.0),
          child: RaisedButton(
              child: Text(FlutterI18n.translate(context, "send_token")),
              onPressed: _sendEmail),
        ),
        flex: 2,
      ));
    }

    return new Scaffold(
      appBar: new AppBar(
        title: new Text(FlutterI18n.translate(context, "login")),
      ),
      body: ListView(
        children: <Widget>[
          Container(
            padding: EdgeInsets.all(12.0),
            child: _rq.renderer.pageTitle(
                FlutterI18n.translate(context, "login_title"),
                textColor: Theme.of(context).accentColor),
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: Text(FlutterI18n.translate(context, "login_desc")),
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 5,
              children: <Widget>[
                ChoiceChip(
                  label: Text(FlutterI18n.translate(
                      context, "login_with_account_and_password")),
                  selectedColor: Theme.of(context).accentColor,
                  disabledColor: Theme.of(context).disabledColor,
                  onSelected: (bool selected) {
                    setState(() {
                      _curIndex = 0;
                    });
                  },
                  selected: _curIndex == 0,
                  labelStyle:
                      _curIndex == 0 ? TextStyle(color: Colors.white) : null,
                ),
                ChoiceChip(
                  label:
                      Text(FlutterI18n.translate(context, "login_with_email")),
                  selectedColor: Theme.of(context).accentColor,
                  disabledColor: Theme.of(context).disabledColor,
                  onSelected: (bool selected) {
                    setState(() {
                      _curIndex = 1;
                    });
                  },
                  selected: _curIndex == 1,
                  labelStyle:
                      _curIndex == 1 ? TextStyle(color: Colors.white) : null,
                )
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: Text(_loginStatus),
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: TextField(
              controller: _ec,
              maxLines: 1,
              style: TextStyle(fontSize: 18.0),
              decoration: InputDecoration(
                  labelText: FlutterI18n.translate(
                      context, _curIndex == 1 ? "email_account" : "account")),
            ),
          ),
          Row(
            children: secondInputLine,
          ),
          Container(
            padding: EdgeInsets.all(12.0),
            child: RaisedButton(
                child: Text(FlutterI18n.translate(context, "login")),
                onPressed: () {
                  _login(_curIndex == 1 ? 'email' : 'account');
                }),
          ),
        ],
      ),
    );
  }
}
