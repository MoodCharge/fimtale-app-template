import 'dart:convert';
import 'dart:io';
import 'package:fimtale/elements/base64_image.dart';
import 'package:fimtale/library/renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:toast/toast.dart';
import 'package:webview_flutter/webview_flutter.dart';

//分享卡片，本质上是WebView。

class ShareTicket extends StatefulWidget {
  final value;

  ShareTicket({Key key, @required this.value}) : super(key: key);

  @override
  _ShareTicketState createState() => _ShareTicketState(value);
}

class _ShareTicketState extends State<ShareTicket> {
  var _value;
  WebViewController _webViewController;
  Renderer _renderer;

  _ShareTicketState(value) {
    _value = value;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(FlutterI18n.translate(context, "share_ticket")),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.file_download),
              onPressed: () async {
                if (_webViewController == null) return;
                String base64 = jsonDecode(
                    await _webViewController.evaluateJavascript(
                        "jQuery('#share-ticket-generate-area').attr('src')"));
                if (base64 != null && base64.length > 0) {
                  Base64Image img = new Base64Image(base64);
                  print(img.isValid);
                  if (img.isValid) {
                    String path =
                        (await _renderer.requestHandler.getAppDocPath()) +
                            "share_ticket_" +
                            DateTime.now().millisecondsSinceEpoch.toString() +
                            "." +
                            img.appendix;
                    File saveFile = await File(path).writeAsBytes(img.decode());
                    if (saveFile != null) {
                      final result = await ImageGallerySaver.saveFile(path);
                      Toast.show(
                          FlutterI18n.translate(
                              context, saveFile != null ? "succeed" : "failed"),
                          context);
                    } else {
                      Toast.show("falied", context);
                    }
                  }
                }
              })
        ],
      ),
      body: WebView(
        initialUrl: 'https://fimtale.com/share/ticket',
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController webViewController) {
          _webViewController = webViewController;
        },
        onPageFinished: (String url) {
          _webViewController.evaluateJavascript(
              "generateShareTicket(" + jsonEncode(_value) + ")");
        },
      ),
    );
  }
}
