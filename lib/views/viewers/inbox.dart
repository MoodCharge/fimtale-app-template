import 'dart:async';
import 'dart:convert';
import 'package:fimtale/elements/share_card.dart';
import 'package:intl/intl.dart';

import 'package:fimtale/elements/ftemoji.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:markdown_widget/config/style_config.dart';
import 'package:markdown_widget/markdown_generator.dart';
import 'package:sp_util/sp_util.dart';
import 'package:toast/toast.dart';

import 'image_viewer.dart';

//对话界面。气泡的对齐一直是个大问题，哪个高手帮我解决一下哈哈哈。
//TODO:使气泡能够默认从下往上跑。

class InboxView extends StatefulWidget {
  final value;

  InboxView({Key key, @required this.value}) : super(key: key);

  @override
  _InboxViewState createState() => new _InboxViewState(value);
}

class _InboxViewState extends State<InboxView> {
  var value;
  int _inboxID = 0, _lastListTime = -1, _lastRequestTime = -1;
  double _originalHeight = 0;
  String _contactName = "";
  Map<String, dynamic> _contactInfo = {};
  List _messageList = [], _imageUrls = [];
  bool _isLoading = false,
      _isRefreshing = false,
      _isEnd = false,
      _isJump = false,
      _isSending = false;
  RequestHandler _rq;
  ScrollController _sc = ScrollController();
  TextEditingController _mc = TextEditingController();
  Timer _mt = null;

  _InboxViewState(value) {
    this.value = value;
    if (value.containsKey("InboxID")) this._inboxID = value["InboxID"];
    if (value.containsKey("ContactName"))
      this._contactName = value["ContactName"];
  }

  @override
  void initState() {
    super.initState();
    _rq = new RequestHandler(context, listNames: ["Messages"]);
    _loadInboxInfo().then((res) {
      if (_inboxID > 0) _loadMessageList(false, isJump: true);
    });
    _sc.addListener(() {
      if (_sc.position.pixels < MediaQuery.of(context).size.height + 100 &&
          _sc.position.pixels < _sc.position.maxScrollExtent) {
        _loadMessageList(false);
      }
    });
    _setMessageRequestInterval(true);
  }

  @override
  void dispose() {
    _setMessageRequestInterval(false);
    super.dispose();
  }

  //设置向服务器获取信息的周期。
  _setMessageRequestInterval(bool isOpen) {
    if (_mt != null) {
      _mt.cancel();
      _mt = null;
    }
    if (isOpen)
      _mt = Timer.periodic(Duration(milliseconds: 30000), (timer) {
        _loadMessageList(true,
            isJump: _sc.position.pixels > _sc.position.maxScrollExtent - 100);
      });
  }

  //加载这个对话的相关信息。
  _loadInboxInfo() async {
    var result = await this._rq.request("/api/v1/inbox/" +
        (_inboxID > 0
            ? _inboxID.toString()
            : Uri.encodeComponent(_contactName)));

    if (result["Status"] == 1) {
      setState(() {
        _inboxID = result["InboxID"];
        _contactInfo = Map.from(result["ContactInfo"]);
        _contactName = _contactInfo["UserName"];
      });
    } else {
      print(result["ErrorMessage"]);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
    }

    Map<String, dynamic> draft = jsonDecode(
        SpUtil.getString("draft_inbox_" + _inboxID.toString(), defValue: "{}"));
    if (draft != null && draft.containsKey("Content"))
      _mc.text = draft["Content"];
  }

  //加载消息列表。
  _loadMessageList(bool isNew, {bool isJump = false}) async {
    if (_inboxID <= 0 || _isLoading) return;
    setState(() {
      _isLoading = true;
    });

    String url = "/api/v1/inbox/" + _inboxID.toString() + "/list";
    Map<String, dynamic> params = {};

    if (isNew) {
      url = "/api/v1/inbox/new";
      params["id"] = _inboxID.toString();
      if (_lastRequestTime >= 0) params["last_date"] = _lastRequestTime;
    } else {
      if (_lastListTime >= 0) params["last_date"] = _lastListTime;
    }

    var result = await this._rq.request(url, params: params);

    if (!mounted) return;

    if (result["Status"] == 1) {
      setState(() {
        _insertMessages(result["MessagesArray"], isJump: isJump);
        if (isNew) _lastRequestTime = result["RequestTime"];
        _isLoading = false;
        _isRefreshing = false;
        if (!isNew && result["MessagesArray"].isEmpty) _isEnd = true;
      });
    } else {
      print(result["ErrorMessage"]);
      Toast.show(result["ErrorMessage"], context,
          duration: Toast.LENGTH_SHORT, gravity: Toast.BOTTOM);
      _isLoading = false;
      _isRefreshing = false;
    }
  }

  //插入气泡。
  _insertMessages(List messages, {bool isJump = false}) {
    messages.forEach((element) {
      if (!_messageList.any((e) => e["ID"] == element["ID"]))
        _messageList.add(element);
    });
    _messageList.sort((left, right) {
      return left["DateCreated"].compareTo(right["DateCreated"]);
    });
    if (_messageList.length > 0) _lastListTime = _messageList[0]["DateCreated"];
    _isJump = isJump;
  }

  //发送消息。
  _sendMessage(String message, {bool getVerifyCode = false}) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
    });
    Map<String, dynamic> params = {"Content": message};
    if (getVerifyCode) {
      var verifyInfo = await _rq.getCaptcha();
      if (verifyInfo["Success"]) {
        params["tencentCode"] = verifyInfo["Ticket"];
        params["tencentRand"] = verifyInfo["RandStr"];
      } else {
        Toast.show(
            FlutterI18n.translate(context, "verify_code_get_failed"), context);
        return;
      }
    }

    var result = await _rq.request("/api/v1/inbox/" + _inboxID.toString(),
        method: "post", params: params);

    if (result["Status"] == 1) {
      Toast.show(FlutterI18n.translate(context, "post_complete"), context);
      _insertMessages(result["MessagesArray"], isJump: true);
      SpUtil.remove("draft_inbox_" + _inboxID.toString());
      setState(() {
        _mc.text = "";
        _isSending = false;
      });
    } else {
      setState(() {
        _isSending = false;
      });
      if (result["ErrorMessage"].contains("需要验证")) {
        _sendMessage(message, getVerifyCode: true);
      } else {
        print(result["ErrorMessage"]);
        Toast.show(result["ErrorMessage"], context);
      }
    }
  }

  //这里的时间格式化与其余页面的时间格式化都不一样。
  String _formatTime(int time) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(time * 1000),
        now = DateTime.now();
    if (DateFormat("yyyy-MM-dd").format(date) ==
        DateFormat("yyyy-MM-dd").format(now))
      return DateFormat("HH:mm:ss").format(date);
    else if (DateFormat("yyyy").format(date) == DateFormat("yyyy").format(now))
      return DateFormat("MM-dd HH:mm:ss").format(date);
    else
      return DateFormat("yyyy-MM-dd HH:mm:ss").format(date);
  }

  //更新位置。
  _updatePosition() {
    final originalHeight = _originalHeight,
        newHeight = _sc.position.maxScrollExtent;
    _sc.jumpTo(_sc.position.pixels + newHeight - originalHeight);
    _originalHeight = newHeight;
  }

  //打开图片预览器。
  _openImageViewer(int index) {
    Navigator.push(context, MaterialPageRoute(builder: (context) {
      return ImageViewer(
        value: {"UrlList": _imageUrls, "CurIndex": index},
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rq.updateShareCardInfo().then((value) {
        if (!mounted) return;
        setState(() {});
      });

      if (_isJump) {
        _sc.jumpTo(_sc.position.maxScrollExtent);
        _isJump = false;
      }
    });

    return new Scaffold(
      appBar: new AppBar(
        title: new Text(_contactName),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.perm_identity),
            onPressed: () {
              if (_contactName.length > 0) {
                _setMessageRequestInterval(false);
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return UserView(value: {"UserName": _contactName});
                })).then((value) {
                  _setMessageRequestInterval(true);
                });
              }
            },
          ),
        ],
      ),
      body: new SingleChildScrollView(
        controller: _sc,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _displayMessageBubbles(),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: GestureDetector(
          onTap: () {
            if (_inboxID > 0)
              _rq.renderer
                  .inputModal(
                      draftKey: "inbox_" + _inboxID.toString(),
                      hint: FlutterI18n.translate(context, "input_message"),
                      options: ["emoji", "image"],
                      instantSubmit: true,
                      onChange: (msg) {
                        _mc.text = msg;
                      })
                  .then((value) {
                setState(() {});
                if (value != null && value.length > 0) _sendMessage(value);
              });
          },
          child: AbsorbPointer(
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: TextField(
                controller: _mc,
                decoration: InputDecoration(
                    hintText: FlutterI18n.translate(context, "input_message")),
                enabled: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  //显示短信息的泡泡。
  List<Widget> _displayMessageBubbles() {
    int lastBubbleTime = 0;
    List<Widget> contentList = [];

    if (_isEnd)
      contentList.add(_rq.renderer.endNotice());
    else if (_isLoading) contentList.add(_rq.renderer.preloader());

    _messageList.forEach((element) {
      bool isSpecialBubble = false;
      int bubbleTime =
          _rq.renderer.extractFromTree(element, ["DateCreated"], 0);

      List<Widget> rawContent = MarkdownGenerator(
        data: _rq.renderer
            .emojiUtil(_rq.renderer.htmlUnescape(element["Content"])),
        styleConfig: StyleConfig(
          titleConfig: TitleConfig(),
          pConfig: PConfig(
            onLinkTap: (url) {
              _rq.launchURL(url);
            },
            custom: (node) {
              switch (node.tag) {
                case "share":
                  isSpecialBubble = true;
                  _rq.shareLinkBuffer.add("/" +
                      _rq.getTypeCode(node.attributes["type"]) +
                      "/" +
                      node.attributes["code"]);
                  return ShareCard(
                    _rq,
                    node.attributes["type"],
                    node.attributes["code"],
                    onLoaded: () {
                      _updatePosition();
                    },
                  );
                  break;
                case "ftemoji":
                  return FTEmoji(node.attributes["code"]);
                  break;
                default:
                  return SizedBox(
                    width: 0,
                    height: 0,
                  );
              }
            },
          ),
          blockQuoteConfig: BlockQuoteConfig(),
          tableConfig: TableConfig(),
          preConfig: PreConfig(),
          ulConfig: UlConfig(),
          olConfig: OlConfig(),
          imgBuilder: (String url, attributes) {
            isSpecialBubble = true;
            int index = _imageUrls.indexOf(url);
            if (index < 0) {
              index = _imageUrls.length;
              _imageUrls.add(url);
            }
            return GestureDetector(
              onTap: () {
                _openImageViewer(index);
              },
              child: Image.network(url),
            );
          },
        ),
      ).widgets;

      Widget avatar = Flexible(
        child: _rq.renderer.userAvatar(element["UserID"]),
        flex: 0,
      ),
          content = Flexible(
        child: Align(
          alignment:
              element["IsMe"] ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: isSpecialBubble ? null : EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rawContent,
            ),
            decoration: isSpecialBubble
                ? null
                : BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(element["IsMe"] ? 3 : 0),
                      topRight: Radius.circular(element["IsMe"] ? 0 : 3),
                      bottomLeft: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                    color: element["IsMe"]
                        ? Colors.lightGreen.withAlpha(31)
                        : Colors.grey.withAlpha(31),
                  ),
          ),
        ),
        flex: 6,
      ),
          blank = Flexible(
        child: SizedBox(),
        flex: 1,
      );

      if (bubbleTime - lastBubbleTime > 300000)
        contentList.add(Container(
          padding: EdgeInsets.all(12),
          alignment: Alignment.center,
          child: Chip(
            label: Text(
              _formatTime(bubbleTime),
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black.withAlpha(63),
          ),
        ));
      lastBubbleTime = bubbleTime;

      contentList.add(Container(
        margin: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: element["IsMe"]
              ? [blank, content, avatar]
              : [avatar, content, blank],
        ),
      ));
    });

    return contentList;
  }
}
