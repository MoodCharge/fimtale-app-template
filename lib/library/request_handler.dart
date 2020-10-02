import 'dart:convert';
import 'dart:io';
import 'package:fimtale/library/app_provider.dart';
import 'package:fimtale/library/renderer.dart';
import 'package:fimtale/views/others/share_ticket.dart';
import 'package:fimtale/views/others/verify_page.dart';
import 'package:fimtale/views/viewers/inbox.dart';
import 'package:flutter/services.dart';
import 'package:connectivity/connectivity.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:fimtale/views/viewers/blogpost.dart';
import 'package:fimtale/views/viewers/channel.dart';
import 'package:fimtale/views/viewers/tag.dart';
import 'package:fimtale/views/viewers/topic.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:toast/toast.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestHandler {
  BuildContext _context;
  Dio dio = new Dio();
  Connectivity c = new Connectivity();
  AppInfoProvider provider;
  Renderer renderer;

  //网站基地址
  String _host = "https://fimtale.com",
      _imgBoxTokenId = "",
      _imgBoxTokenSecret = "";

  //网络连接状态。0为未连接，1为移动网，2为wifi
  int _webStatus;

  //这里记录已发送正在等待请求的request（关键字），避免在同一时间重复发起。
  List<String> _requestSending = [], shareLinkBuffer = [], _linksOnRequest = [];

  //这里存储已请求的数据
  Map _lists = {}, shareCardInfo = {};

  RequestHandler(BuildContext context,
      {String host, List<String> listNames, Renderer renderer}) {
    _context = context;
    if (host != null) _host = host;
    if (renderer != null)
      this.renderer = renderer;
    else
      this.renderer = Renderer(context, requestHandler: this);
    provider = Provider.of<AppInfoProvider>(context, listen: false);

    dio.options.connectTimeout = 20000;
    dio.options.receiveTimeout = 20000;
    if (listNames != null) {
      listNames.forEach((element) {
        this.clearOrCreateList(element);
      });
    }
    initConnectivityListener();
  }

  _checkConnectivity(result) {
    if (result == ConnectivityResult.mobile) {
      this._webStatus = 1;
    } else if (result == ConnectivityResult.wifi) {
      this._webStatus = 2;
    } else {
      this._webStatus = 0;
    }
  }

  initConnectivityListener() async {
    c.onConnectivityChanged.listen((ConnectivityResult result) {
      _checkConnectivity(result);
    });
    var res = await c.checkConnectivity();
    _checkConnectivity(res);
  }

  Future<String> getAppDocPath() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    return appDocDir.path;
  }

  initCookieJar() async {
    dio.interceptors.clear();
    dio.interceptors.add(CookieManager(
        PersistCookieJar(dir: (await getAppDocPath()) + "/cookies")));
  }

  bool isConnected() {
    return (this._webStatus != 0);
  }

  bool isWifi() {
    return (this._webStatus == 2);
  }

  List<String> getListNames() {
    List<String> l = [];
    _lists.keys.forEach((k) {
      l.add(k);
    });
    return l;
  }

  bool hasName(String name) {
    return _lists.containsKey(name);
  }

  List<dynamic> getListByName(String name) {
    return hasName(name) ? _lists[name]["List"] : List();
  }

  void setListByName(String name, List newList) {
    if (hasName(name)) _lists[name]["List"] = newList;
  }

  void addListByName(String name, List newList) {
    if (hasName(name)) _lists[name]["List"].addAll(newList);
  }

  void setListItemByNameAndIndex(String name, int index, dynamic item) {
    if (hasName(name) && index >= 0 && index < _lists[name]["List"].length)
      _lists[name]["List"][index] = item;
  }

  int getCurPage(String name) {
    return hasName(name) ? _lists[name]["CurPage"] : 0;
  }

  void setCurPage(String name, int page) {
    if (hasName(name)) _lists[name]["CurPage"] = page;
  }

  int getTotalPage(String name) {
    return hasName(name) ? _lists[name]["TotalPage"] : 0;
  }

  void setTotalPage(String name, int page) {
    if (hasName(name)) _lists[name]["TotalPage"] = page;
  }

  bool isLoading(String name) {
    return hasName(name) ? _lists[name]["IsLoading"] : false;
  }

  void setIsLoading(String name, bool status) {
    if (hasName(name)) _lists[name]["IsLoading"] = status;
  }

  bool isRefreshing(String name) {
    return hasName(name) ? _lists[name]["IsRefreshing"] : false;
  }

  void setIsRefreshing(String name, bool status) {
    if (hasName(name)) _lists[name]["IsRefreshing"] = status;
  }

  void clearOrCreateList(String name) {
    _lists[name] = {
      "List": [],
      "CurPage": 0,
      "TotalPage": 1,
      "IsLoading": false,
      "IsRefreshing": false
    };
  }

  void updateListByName(String url, String listName, Function processor,
      {String method = "get",
      bool isRefreshing = false,
      Map<String, dynamic> params,
      Function beforeRequest,
      Function afterUpdate,
      Function onError}) async {
    if (!hasName(listName)) return;
    if (_lists[listName]["IsLoading"] ||
        _lists[listName]["CurPage"] >= _lists[listName]["TotalPage"]) return;
    if (isRefreshing) {
      _lists[listName]["List"].clear();
      _lists[listName]["CurPage"] = 0;
      _lists[listName]["TotalPage"] = 1;
      _lists[listName]["IsRefreshing"] = true;
    }
    _lists[listName]["IsLoading"] = true;
    _lists[listName]["CurPage"]++;
    if (_lists[listName]["CurPage"] > 1) {
      if (params == null) {
        params = {"page": _lists[listName]["CurPage"].toString()};
      } else {
        params["page"] = _lists[listName]["CurPage"].toString();
      }
    }
    if (beforeRequest != null) beforeRequest();
    var result = await request(url, method: method, params: params);
    if (result["Status"] == 1) {
      var data = processor(result);
      if (_lists[listName]["CurPage"] <= data["TotalPage"] &&
          data["List"] != null) _lists[listName]["List"].addAll(data["List"]);
      _lists[listName]["CurPage"] = data["CurPage"];
      _lists[listName]["TotalPage"] = data["TotalPage"];
      _lists[listName]["IsRefreshing"] = false;
      _lists[listName]["IsLoading"] = false;
      if (afterUpdate != null) afterUpdate(_lists[listName]["List"]);
    } else {
      print(result["ErrorMessage"]);
      if (onError != null) onError(result["ErrorMessage"]);
    }
  }

  String getTypeCode(String type) {
    switch (type) {
      case 'blog':
        return 'b';
      case 'topic':
        return 't';
      case 'user':
        return 'u';
      default:
        return type;
    }
  }

  Future<void> updateShareCardInfo() async {
    List<String> links = [];

    shareLinkBuffer.forEach((element) {
      if (shareCardInfo[element] == null &&
          !_linksOnRequest.contains(element)) {
        links.add("https://fimtale.com" + element);
        _linksOnRequest.add(element);
      }
    });
    shareLinkBuffer = [];

    if (links.length <= 0) return;

    var result = await request("/api/v1/json/getInfoByURL",
        params: {'urls': jsonEncode(links)});

    if (result["Status"] == 1) {
      result["BlogpostsArray"].forEach((element) {
        shareCardInfo["/b/" + element["ID"].toString()] = Map.from(element);
        _linksOnRequest.remove("/b/" + element["ID"].toString());
      });
      result["ChannelsArray"].forEach((element) {
        shareCardInfo["/channel/" + element["ID"].toString()] =
            Map.from(element);
        _linksOnRequest.remove("/channel/" + element["ID"].toString());
      });
      result["TagsArray"].forEach((element) {
        shareCardInfo["/tag/" + Uri.encodeComponent(element["Name"])] =
            Map.from(element);
        _linksOnRequest.remove("/tag/" + Uri.encodeComponent(element["Name"]));
      });
      result["TopicsArray"].forEach((element) {
        shareCardInfo["/t/" + element["ID"].toString()] = Map.from(element);
        _linksOnRequest.remove("/t/" + element["ID"].toString());
      });
      result["UsersArray"].forEach((element) {
        shareCardInfo["/u/" + Uri.encodeComponent(element["UserName"])] =
            Map.from(element);
        _linksOnRequest
            .remove("/u/" + Uri.encodeComponent(element["UserName"]));
      });
    }
  }

  Future<Map<String, dynamic>> request(
    String url, {
    String method = "get",
    Map<String, dynamic> params,
    bool updateUserInfo = true,
  }) async {
    if (!this.isConnected())
      return {
        "Status": -1,
        "ErrorMessage":
            FlutterI18n.translate(_context, "no_internet_connection")
      };
    if (!url.startsWith("http://") &&
        !url.startsWith("https://") &&
        !url.startsWith("ftp://")) url = _host + url;
    await initCookieJar();
    method = method.toLowerCase();
    final options = Options(method: method);
    try {
      print("Request sending, url: \"" +
          url +
          "\", params: " +
          params.toString());
      Response response;
      switch (method) {
        case "get":
          response = await this.dio.get(url, queryParameters: params);
          break;
        case "post":
          response = await this.dio.post(url, data: FormData.fromMap(params));
          break;
        default:
          response = await this.dio.request(url,
              queryParameters: params,
              data: FormData.fromMap(params),
              options: options);
          break;
      }
      var data = response.data;
      if (data is Map) {
        if (!data.containsKey("Status")) data["Status"] = 1;
        if (data.containsKey("CurrentUser")) {
          provider.initUserInfo(Map.from(data["CurrentUser"]));
        }
        return Map<String, dynamic>.from(data);
      } else {
        if (data is String && data.toLowerCase().contains("security check"))
          return {
            "Status": 0,
            "ErrorMessage":
                FlutterI18n.translate(_context, "website_rejected_subjectively")
          };
        return {"Status": 1, "Message": data};
      }
    } on DioError catch (e) {
      return {"Status": 0, "ErrorMessage": e.toString()};
    }
  }

  manage(int id, int type, String action, Function onSuccess,
      {Map<String, dynamic> params, Function onError}) async {
    String requestKey =
        "manage/" + action + "/" + type.toString() + "/" + id.toString();
    if (_requestSending.contains(requestKey)) return;
    if (params == null) params = {};
    params["ID"] = id.toString();
    params["Type"] = type.toString();
    params["Action"] = action;
    _requestSending.add(requestKey);
    var result = await request("/manage", method: "post", params: params);
    _requestSending.remove(requestKey);
    if (result["Status"] == 1) {
      onSuccess(result);
    } else {
      Toast.show(result["ErrorMessage"], _context);
      if (onError != null) onError(result["ErrorMessage"]);
    }
  }

  uploadPost(String url, Map<String, dynamic> data,
      {Function onSubmit, Function onSuccess, Function onError}) async {
    if (_requestSending.contains(url)) return;

    if (onSubmit != null) onSubmit();

    var verifyInfo = await getCaptcha();
    if (!verifyInfo["Success"]) {
      Toast.show(
          FlutterI18n.translate(_context, "verify_code_get_failed"), _context);
      onError(FlutterI18n.translate(_context, "verify_code_get_failed"));
      return;
    } else {
      data["tencentCode"] = verifyInfo["Ticket"];
      data["tencentRand"] = verifyInfo["RandStr"];
    }

    _requestSending.add(url);
    var result = await request(url, method: "post", params: data);
    _requestSending.remove(url);

    if (result["Status"] == 1) {
      String message = FlutterI18n.translate(_context, "post_complete");
      if (result.containsKey("Bits") && result["Bits"] > 0) {
        message = message +
            "," +
            FlutterI18n.translate(_context, "bits_added",
                translationParams: {"Bits": result["Bits"].toString()});
      }
      Toast.show(message, _context);
      if (result.containsKey("Href") && result["Href"].length > 0) {
        if (onSuccess != null)
          onSuccess(result["Href"]);
        else
          launchURL(result["Href"]);
      }
    } else {
      Toast.show(result["ErrorMessage"], _context);
      if (onError != null) onError(result["ErrorMessage"]);
    }
  }

  Future<Map> getCaptcha() async {
    var verifVal =
        await Navigator.push(_context, MaterialPageRoute(builder: (context) {
      return VerifyPage();
    }));

    print(verifVal);

    if (verifVal == null)
      return {
        "Success": false,
      };

    var verifyInfo = jsonDecode(verifVal);

    return {
      "Success": verifyInfo["ret"] == 0,
      "Ticket": verifyInfo["ticket"],
      "RandStr": verifyInfo["randstr"]
    };
  }

  Future<String> uploadImage2ImgBox(image) async {
    String path = image.path,
        name = path.substring(path.lastIndexOf("/") + 1, path.length);
    String tokenId, tokenSecret;

    if (_imgBoxTokenId.length > 0 && _imgBoxTokenSecret.length > 0) {
      tokenId = _imgBoxTokenId;
      tokenSecret = _imgBoxTokenSecret;
    } else {
      Toast.show(FlutterI18n.translate(_context, "getting_token"), _context);
      var token =
          await request("https://imgbox.fimtale.com/ajax/token/generate");
      if (token["Status"] != 1) {
        Toast.show(
            FlutterI18n.translate(_context, "get_token_failed"), _context);
        print(token["ErrorMessage"]);
        return null;
      }
      tokenId = token["token_id"].toString();
      tokenSecret = token["token_secret"];
      _imgBoxTokenId = tokenId;
      _imgBoxTokenSecret = tokenSecret;
    }

    Toast.show(FlutterI18n.translate(_context, "uploading"), _context);
    var result = await request("https://imgbox.fimtale.com/upload/process",
        method: "post",
        params: {
          'token_id': tokenId,
          'token_secret': tokenSecret,
          'content_type': '1',
          'thumbnail_size': '100c',
          'gallery_id': 'null',
          'gallery_secret': 'null',
          'comments_enabled': '0',
          'files[]': await MultipartFile.fromFile(path, filename: name)
        });

    if (result["Status"] == 1) {
      Map<String, dynamic> fileInfo =
          Map<String, dynamic>.from(jsonDecode(result["Message"]));
      var url = fileInfo["files"][0]["original_url"];
      url = url.replaceAll("images2.imgbox.com", "imgbox-get.fimtale.com");
      url = url.replaceAll("images.imgbox.com", "imgbox-get.fimtale.com");
      return url;
    } else {
      Toast.show(FlutterI18n.translate(_context, "upload_failed"), _context);
      print(result["ErrorMessage"]);
      return null;
    }
  }

  Future<bool> downloadFile(String link, String savePath) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    Response response = await dio.download(link, appDocPath + savePath);
    return response.statusCode == 200;
  }

  Future<String> launchURL(String url,
      {bool returnWhenCommentIDFounds = false,
      bool replaceCurrentPage = false}) async {
    Function openPage =
        replaceCurrentPage ? Navigator.pushReplacement : Navigator.push;
    if (await canLaunch(url)) {
      if (url.startsWith("http://") || url.startsWith("https://")) {
        await launch(url);
      }
      return jsonEncode({"IsCommentFound": false});
    } else {
      RegExp blogpost = new RegExp(r"\/b\/([0-9]+)(\?comment=([0-9]+))?"),
          channel = new RegExp(r"\/channel\/([0-9]+)(\?comment=([0-9]+))?"),
          inbox = new RegExp(r"\/inbox\/(.+)"),
          topicComment = new RegExp(r"\/goto\/([0-9]+)\-([0-9]+)"),
          tag = new RegExp(r"\/tag\/([A-Za-z0-9%_\-]+)"),
          topic = new RegExp(r"\/t\/([0-9]+)"),
          user = new RegExp(r"\/u\/([A-Za-z0-9%_\-]+)");
      int mainID = 0, commentID = 0;
      String mainName = "";
      bool isMatched = false;
      Iterable<Match> blogpostMatchRes = blogpost.allMatches(url);
      if (blogpostMatchRes.isNotEmpty) {
        for (Match m in blogpostMatchRes) {
          if (m.group(3) != null) commentID = int.parse(m.group(3));
          mainID = int.parse(m.group(1));
          break;
        }
        isMatched = true;
        if (commentID > 0) {
          if (returnWhenCommentIDFounds) {
            return jsonEncode({
              "IsCommentFound": true,
              "Type": "blogpost",
              "MainID": mainID,
              "CommentID": commentID
            });
          } else {
            openPage(_context, MaterialPageRoute(builder: (_context) {
              return BlogpostView(
                  value: {"BlogpostID": mainID, "CommentID": commentID});
            }));
          }
        } else {
          openPage(_context, MaterialPageRoute(builder: (_context) {
            return BlogpostView(value: {"BlogpostID": mainID});
          }));
        }
      }
      Iterable<Match> channelMatchRes = channel.allMatches(url);
      if (channelMatchRes.isNotEmpty) {
        for (Match m in channelMatchRes) {
          if (m.group(3) != null) commentID = int.parse(m.group(3));
          mainID = int.parse(m.group(1));
          break;
        }
        isMatched = true;
        if (commentID > 0) {
          if (returnWhenCommentIDFounds) {
            return jsonEncode({
              "IsCommentFound": true,
              "Type": "channel",
              "MainID": mainID,
              "CommentID": commentID
            });
          } else {
            openPage(_context, MaterialPageRoute(builder: (_context) {
              return ChannelView(
                  value: {"ChannelID": mainID, "CommentID": commentID});
            }));
          }
        } else {
          openPage(_context, MaterialPageRoute(builder: (_context) {
            return ChannelView(value: {"ChannelID": mainID});
          }));
        }
      }
      Iterable<Match> inboxMatchRes = inbox.allMatches(url);
      if (inboxMatchRes.isNotEmpty) {
        for (Match m in inboxMatchRes) {
          mainName = m.group(1);
          break;
        }
        isMatched = true;
        openPage(_context, MaterialPageRoute(builder: (_context) {
          return InboxView(
              value: {"ContactName": Uri.decodeComponent(mainName)});
        }));
      }
      Iterable<Match> tagMatchRes = tag.allMatches(url);
      if (tagMatchRes.isNotEmpty) {
        for (Match m in tagMatchRes) {
          mainName = m.group(1);
          break;
        }
        isMatched = true;
        openPage(_context, MaterialPageRoute(builder: (_context) {
          return TagView(value: {"TagName": Uri.decodeComponent(mainName)});
        }));
      }
      Iterable<Match> topicCommentMatchRes = topicComment.allMatches(url);
      if (topicCommentMatchRes.isNotEmpty) {
        for (Match m in topicCommentMatchRes) {
          commentID = int.parse(m.group(2));
          mainID = int.parse(m.group(1));
          break;
        }
        isMatched = true;
        if (returnWhenCommentIDFounds) {
          return jsonEncode({
            "IsCommentFound": true,
            "Type": "topic",
            "MainID": mainID,
            "CommentID": commentID
          });
        } else {
          openPage(_context, MaterialPageRoute(builder: (_context) {
            return TopicView(
                value: {"TopicID": mainID, "CommentID": commentID});
          }));
        }
      }
      Iterable<Match> topicMatchRes = topic.allMatches(url);
      if (topicMatchRes.isNotEmpty) {
        for (Match m in topicMatchRes) {
          mainID = int.parse(m.group(1));
          break;
        }
        isMatched = true;
        openPage(_context, MaterialPageRoute(builder: (_context) {
          return TopicView(value: {"TopicID": mainID});
        }));
      }
      Iterable<Match> userMatchRes = user.allMatches(url);
      if (userMatchRes.isNotEmpty) {
        for (Match m in userMatchRes) {
          mainName = m.group(1);
          break;
        }
        isMatched = true;
        openPage(_context, MaterialPageRoute(builder: (_context) {
          return UserView(value: {"UserName": Uri.decodeComponent(mainName)});
        }));
      }
      if (!isMatched)
        Toast.show(FlutterI18n.translate(_context, "cannot_launch") + ":" + url,
            _context);
      return jsonEncode({"IsCommentFound": false});
    }
  }

  share(String type, String url, {Map<String, dynamic> info}) async {
    if (info == null) info = {};
    switch (type) {
      case "share_ticket":
        info["link"] = url;
        Navigator.push(_context, MaterialPageRoute(builder: (_context) {
          return ShareTicket(value: info);
        }));
        break;
      default:
        Clipboard.setData(ClipboardData(text: url));
        Toast.show(FlutterI18n.translate(_context, "copy_complete"), _context);
        break;
    }
  }
}
