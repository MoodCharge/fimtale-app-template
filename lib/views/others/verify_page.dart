import 'dart:convert';
import 'package:fimtale/library/renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:webview_flutter/webview_flutter.dart';

//验证码获取页面，本质上是个WebView。

class VerifyPage extends StatefulWidget {
  @override
  _VerifyPageState createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  WebViewController _webViewController;
  Renderer _renderer;
  String filePath = 'assets/files/verify_code.html';

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
    return Scaffold(
      appBar:
          AppBar(title: Text(FlutterI18n.translate(context, "verify_code"))),
      body: WebView(
        initialUrl: '',
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          _webViewController = webViewController;
          _loadHtml();
        },
        javascriptChannels: <JavascriptChannel>[
          JavascriptChannel(
              name: "returnVerify",
              onMessageReceived: (JavascriptMessage message) {
                Navigator.of(context).pop(message.message);
              }),
        ].toSet(),
      ),
    );
  }

  _loadHtml() async {
    String fileHtmlContents =
        "<html><head><script src=\"https://ssl.captcha.qq.com/TCaptcha.js\"></script></head><body><script>var captcha = new TencentCaptcha('2027092386', function (res) {if (res.ret === 0) returnVerify.postMessage(JSON.stringify(res));}); captcha.show();</script></body></html>";
    _webViewController.loadUrl(Uri.dataFromString(fileHtmlContents,
            mimeType: 'text/html', encoding: Encoding.getByName('utf-8'))
        .toString());
  }
}
