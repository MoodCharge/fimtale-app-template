import 'package:fimtale/library/request_handler.dart';
import 'package:flutter/material.dart';

//分享卡片，自动选择分享信息进行渲染。和网站上的差不多。

class ShareCard extends StatelessWidget {
  RequestHandler _rq;
  Map<String, dynamic> _thisInfo = {};
  String type = "";
  String code = "";
  Function _onLoaded;

  ShareCard(RequestHandler rq, String type, String code, {Function onLoaded}) {
    this._rq = rq;
    this.type = type;
    this.code = code;
    this._onLoaded = onLoaded;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_onLoaded != null) _onLoaded();
    });

    Map info = _rq.shareCardInfo["/" + _rq.getTypeCode(type) + "/" + code];
    Widget defaultCard = GestureDetector(
      onTap: () {
        _rq.launchURL("/" + _rq.getTypeCode(type) + "/" + code);
      },
      child: Card(
        margin: EdgeInsets.all(12),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              _rq.renderer.preloader(),
              Text(
                "https://fimtale.com/" + _rq.getTypeCode(type) + "/" + code,
                style: TextStyle(color: Colors.blue),
              )
            ],
          ),
        ),
      ),
    );

    if (info != null) {
      switch (type) {
        case 'blog':
          return _rq.renderer.blogpostCard(info);
          break;
        case 'channel':
          return _rq.renderer.channelCard(info);
          break;
        case 'tag':
          return _rq.renderer.tagCard(info);
          break;
        case 'topic':
          return _rq.renderer.topicCard(info);
          break;
        case 'user':
          return _rq.renderer.userCard(info);
          break;
      }
    }
    return defaultCard;
  }
}
