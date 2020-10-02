import 'dart:convert';
import 'package:fimtale/elements/share_card.dart';
import 'package:fimtale/library/consts.dart';
import 'package:fimtale/library/request_handler.dart';
import 'package:fimtale/elements/ftemoji.dart';
import 'package:fimtale/elements/spoiler.dart';
import 'package:fimtale/views/custom/contact_selector.dart';
import 'package:fimtale/views/viewers/channel.dart';
import 'package:fimtale/views/viewers/tag.dart';
import 'package:fimtale/views/viewers/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:markdown/markdown.dart' show markdownToHtml;
import 'package:markdown_widget/markdown_generator.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:fimtale/views/viewers/blogpost.dart';
import 'package:fimtale/views/viewers/topic.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sp_util/sp_util.dart';
import 'package:toast/toast.dart';

//本应用的两大核心库之一，用于渲染各种界面以及整理各式各样的字符串。在大部分界面中都以requestHandler.renderer为变量名进行实例化。
class Renderer {
  BuildContext _context; //传入的上下文，这里有些函数需要该变量，所以构造函数中一定要将context传入。
  RequestHandler
      requestHandler; //这个是本应用的另一大核心库，详情可参考library/request_handler.dart。

  Renderer(BuildContext context, {RequestHandler requestHandler}) {
    _context = context; //赋值给_context。
    if (requestHandler != null)
      this.requestHandler = requestHandler;
    else
      this.requestHandler =
          new RequestHandler(context, renderer: this); //初始化一个requestHandler。
  }

  //从由Map组成的树中取出某个内容，没有对应值的时候返回defaultValue。
  dynamic extractFromTree(Map info, List<String> keys, dynamic defaultValue) {
    dynamic tempInfo = info;
    for (final k in keys) {
      if (tempInfo is Map && tempInfo.containsKey(k)) {
        tempInfo = tempInfo[k];
      } else {
        tempInfo = defaultValue;
      }
    }
    return tempInfo;
  }

  //对时间戳进行规范化，得到时间的字符串表述。
  String formatTime(int time) {
    DateTime now = DateTime.now(),
        then = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    int timeStamp = (now.millisecondsSinceEpoch / 1000).round(),
        timeSpan = timeStamp - time;
    if (timeSpan < 2592000) {
      // 小于30天如下显示
      if (timeSpan >= 86400) {
        return FlutterI18n.translate(_context, 'days_ago',
            translationParams: {"Days": (timeSpan / 86400).round().toString()});
      } else if (timeSpan >= 3600) {
        return FlutterI18n.translate(_context, 'hours_ago',
            translationParams: {"Hours": (timeSpan / 3600).round().toString()});
      } else if (timeSpan >= 60) {
        return FlutterI18n.translate(_context, 'minutes_ago',
            translationParams: {"Minutes": (timeSpan / 60).round().toString()});
      } else if (timeSpan < 0) {
        return FlutterI18n.translate(_context, 'future');
      } else {
        return FlutterI18n.translate(_context, 'seconds_ago',
            translationParams: {"Seconds": (timeSpan + 1).toString()});
      }
    } else {
      List<String> months =
          FlutterI18n.translate(_context, "months").split("|");
      if (months.length < 12) {
        for (int i = months.length; i < 12; i++) {
          months.add((i + 1).toString());
        }
      }
      // 大于一月
      if (now.year == then.year) {
        return months[then.month - 1] +
            " " +
            FlutterI18n.translate(_context, "day_val",
                translationParams: {"Day": then.day.toString()});
      } else {
        return FlutterI18n.translate(_context, "year_val",
                translationParams: {"Year": then.year.toString()}) +
            " " +
            months[then.month - 1] +
            " " +
            FlutterI18n.translate(_context, "day_val",
                translationParams: {"Day": then.day.toString()});
      }
    }
  }

  //反转义HTML字符串
  String htmlUnescape(String str) {
    return str
        .replaceAll("&quot;", '"')
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&nbsp;", " ")
        .replaceAll("&amp;", "&");
  }

  //将emoji对应的shortCode转为对应的表情符号或图片
  String emojiUtil(String content) {
    RegExp emojiPattern = new RegExp(r":([A-Za-z0-9\-_\\]+):");
    Iterable<Match> matchRes = emojiPattern.allMatches(content);
    for (Match m in matchRes) {
      String shortCode = m.group(1),
          emoji = requestHandler.provider.getEmoji(shortCode);
      if (emoji != null) {
        content = content.replaceAll(":" + shortCode + ":", emoji);
      } else if (shortCode.startsWith(RegExp(r"ftemoji[\\]?_"))) {
        content = content.replaceAll(
            ":" + shortCode + ":",
            "<ftemoji code=" +
                shortCode.replaceFirst(RegExp(r"ftemoji[\\]?_"), "") +
                ">");
      }
    }
    return content;
  }

  //渲染单张博文卡片，传入从网站API获取来的博文信息。以下卡片渲染方式与该处相同，故只在该处留详细注解。
  Widget blogpostCard(Map info) {
    //首先先初始化一个列表，作为纵向排版的元素列表。
    var cardContent = <Widget>[];
    //标题，ListTile部件能更加方便展示头像、标题和用户名。
    cardContent.add(ListTile(
      leading: userAvatar(extractFromTree(info, ["UserID"], 0)), //头像。
      title: Text(
        extractFromTree(info, ["Title"], ""),
        textScaleFactor: 1.25,
        maxLines: 2,
      ), //博文标题。
      subtitle: Text(extractFromTree(info, ["UserName"], "")), //博文的作者用户名。
    ));
    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: MarkdownGenerator(
          data: emojiUtil(extractFromTree(info, ["Intro"], "")),
          //博文简介（渲染过emoji后）
          styleConfig: StyleConfig(
            titleConfig: TitleConfig(),
            pConfig: PConfig(
              onLinkTap: (url) {
                requestHandler.launchURL(url);
              },
              custom: (node) {
                switch (node.tag) {
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
              return Image.network(url);
            },
          ),
        ).widgets, //从用户端返回的内容为markdown格式，因此需要用MarkDownGenerator类来解析文本，使之成为flutter的组件。
      ),
    ));

    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 3,
        runSpacing: 0,
        alignment: WrapAlignment.end,
        children: <Widget>[
          Chip(
            label: Text(formatTime(extractFromTree(info, ["DateCreated"], 0))),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.event,
              color: Colors.blue[600],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //创建日期。
          Chip(
            label: Text(formatTime(extractFromTree(info, ["LastTime"], 0))),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.schedule,
              color: Colors.blue[600],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //最后活跃日期。
          Chip(
            label: Text(extractFromTree(info, ["Followers"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.collections_bookmark,
              color: Colors.lightBlue,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //收藏数。
          Chip(
            label: Text(extractFromTree(info, ["WordCount"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.chrome_reader_mode,
              color: Colors.brown,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //字数。
          Chip(
            label: Text(extractFromTree(info, ["Comments"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.forum,
              color: Colors.deepPurple[400],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //评论数。
        ],
      ),
    ));

    return GestureDetector(
      onTap: () {
        Navigator.push(_context, MaterialPageRoute(builder: (_context) {
          return BlogpostView(value: {"BlogpostID": info["ID"]});
        })); //点击后，将一个新页面（由BlogpostView类构建而成）推入当前的路由栈中。
      },
      child: Card(
        margin: EdgeInsets.all(16), //表示边界距离
        child: Column(
          children: cardContent, //整个刚才的内容。
          crossAxisAlignment: CrossAxisAlignment.stretch,
        ),
      ), //卡片外形。
    );
  }

  //传入所有的博文信息，返回所有的博文卡片。
  List<Widget> blogpostList(List arr) {
    List<Widget> res = [];
    arr.forEach((element) {
      res.add(blogpostCard(Map.from(element)));
    });
    return res;
  }

  //频道卡片。
  Widget channelCard(Map info) {
    var cardContent = <Widget>[];
    String background = extractFromTree(info, ["Background"], "");
    cardContent.add(GestureDetector(
      onTap: () {
        Navigator.push(_context, MaterialPageRoute(builder: (_context) {
          return ChannelView(value: {"ChannelID": info["ID"]});
        }));
      },
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: AspectRatio(
            aspectRatio: 1,
            child: background != null && background.length > 0
                ? Image.network(
                    background,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    "assets/images/channel_cover_square.jpg",
                    fit: BoxFit.cover,
                  ),
          ), //AspectRatio用来框定比例，此处令图像为1：1。
        ), //频道封面。
        title: Text(
          extractFromTree(info, ["Name"], ""),
          textScaleFactor: 1.25,
          maxLines: 2,
        ), //频道名
        subtitle: Text(extractFromTree(info, ["CreatorName"], "")), //创建者。
      ),
    ));
    String intro = extractFromTree(info, ["Intro"], ""); //频道简介。
    bool hasIntro = intro != null && intro.length > 0;
    if (hasIntro) {
      cardContent.add(GestureDetector(
        onTap: () {
          Navigator.push(_context, MaterialPageRoute(builder: (_context) {
            return ChannelView(value: {"ChannelID": info["ID"]});
          }));
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            intro,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ));
    }
    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return ChannelView(value: {"ChannelID": info["ID"]});
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.collections_bookmark,
                  color: Colors.lightBlue,
                ),
                Text(
                  extractFromTree(info, ["Collections"], 0).toString(),
                  style: TextStyle(color: Colors.lightBlue),
                ),
              ],
            ),
          ), //频道收藏。
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.thumb_up,
                color: Colors.green,
              ),
              Text(
                extractFromTree(info, ["Upvotes"], 0).toString(),
                style: TextStyle(color: Colors.green),
              ),
            ],
          ), //频道的赞数。
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return ChannelView(
                    value: {"ChannelID": info["ID"], "Interface": "followers"});
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.favorite,
                  color: Colors.red[300],
                ),
                Text(
                  extractFromTree(info, ["Followers"], 0).toString(),
                  style: TextStyle(color: Colors.red[300]),
                ),
              ],
            ),
          ), //频道的订阅者。
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return ChannelView(
                    value: {"ChannelID": info["ID"], "Interface": "comments"});
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.forum,
                  color: Colors.deepPurple[400],
                ),
                Text(
                  extractFromTree(info, ["Comments"], 0).toString(),
                  style: TextStyle(color: Colors.deepPurple[400]),
                ),
              ],
            ),
          ), //频道的讨论板。
        ],
      ),
    ));

    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Wrap(
        children: <Widget>[
          Icon(
            Icons.schedule,
            color: Colors.blue[600],
          ),
          Text(
            formatTime(extractFromTree(info, ["LastTime"], 0)),
            style: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
          ),
        ],
      ),
    )); //最后活跃时间。

    return Card(
      margin: EdgeInsets.all(16), //表示边界距离
      child: Column(
        children: cardContent,
        crossAxisAlignment: CrossAxisAlignment.stretch,
      ),
    );
  }

  List<Widget> channelList(List arr) {
    List<Widget> res = [];
    arr.forEach((element) {
      res.add(channelCard(Map.from(element)));
    });
    return res;
  }

  //评论卡片。
  Widget commentCard(Map info, Function urlFunction,
      {bool useCard = false, List<Widget> actionBarItems}) {
    var cardContent = <Widget>[];
    if (extractFromTree(info, ["IsDel"], 0) == 0) {
      cardContent.addAll([
        ListTile(
          leading: userAvatar(extractFromTree(info, ["UserID"], 0)), //用户头像。
          title: Text(
            extractFromTree(info, ["UserName"], ""),
            textScaleFactor: 1.25,
            maxLines: 1,
          ), //用户名。
        ),
        Container(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: MarkdownGenerator(
              data: emojiUtil(extractFromTree(info, ["Content"], "")),
              styleConfig: StyleConfig(
                titleConfig: TitleConfig(),
                pConfig: PConfig(
                  onLinkTap: (url) {
                    urlFunction(url);
                  },
                  custom: (node) {
                    switch (node.tag) {
                      case "collapse":
                      case "reply":
                        return ExpansionTile(
                          title: new Text(FlutterI18n.translate(
                              _context, "something_is_collapsed")),
                          children: <Widget>[Text(node.attributes["content"])],
                        );
                        break;
                      case "login":
                        if (node.attributes["available"] == "true") {
                          return Card(
                            child: Container(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    FlutterI18n.translate(
                                        _context, "content_visible_when_login"),
                                    textScaleFactor: 1.25,
                                  ),
                                  Text(node.attributes["content"]),
                                ],
                              ),
                            ),
                          );
                        } else {
                          return Card(
                            child: Container(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Text(
                                    FlutterI18n.translate(
                                        _context, "login_to_read"),
                                    textScaleFactor: 1.25,
                                  ),
                                  Text(node.attributes["content"]),
                                ],
                              ),
                            ),
                          );
                        }
                        break;
                      case "share":
                        requestHandler.shareLinkBuffer.add("/" +
                            requestHandler
                                .getTypeCode(node.attributes["type"]) +
                            "/" +
                            node.attributes["code"]);
                        return ShareCard(requestHandler,
                            node.attributes["type"], node.attributes["code"]);
                        break;
                      case "spoiler":
                        return Spoiler(content: node.attributes["content"]);
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
                  return Image.network(url);
                },
              ),
            ).widgets,
          ),
        ), //评论内容。
        Container(
          padding: EdgeInsets.all(12),
          child: Text(
            formatTime(extractFromTree(info, ["DateCreated"], 0)),
            style: TextStyle(color: Theme.of(_context).disabledColor),
            textAlign: TextAlign.right,
          ),
        ) //评论日期。
      ]);

      //如果传入了工具栏，就显示工具栏
      if (actionBarItems != null)
        cardContent.add(Wrap(
          spacing: 3,
          runSpacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actionBarItems,
        ));
    } else {
      //当被删时显示被删的提示（原因的显示改日再说）
      cardContent.add(Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.red.withAlpha(63),
        ),
        child: Text(
          FlutterI18n.translate(_context, "some_comment_deleted",
              translationParams: {
                "UserName": extractFromTree(info, ["UserName"], "")
              }),
          style: TextStyle(color: Colors.red),
        ),
      ));
    }

    //卡片内容。
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cardContent,
    );

    //如果需要卡片就返回卡片；如果不需要就返回内容（无边框）
    return useCard
        ? Card(
            child: content,
          )
        : Container(
            child: content,
          );
  }

  //消息卡片（一般用于渲染通知这类）
  Widget messageCard(Map info,
      {bool useCard = false, bool singleLineSubtitle = false}) {
    RegExp watchMoreRegExp = RegExp(r"[\n\.… ]*查看更多[\n\.… ]*$");
    String txtContent = emojiUtil(extractFromTree(info, ["Content"], ""));
    bool watchMoreSignalFounded = watchMoreRegExp.hasMatch(txtContent);
    txtContent = txtContent.replaceAll(watchMoreRegExp, "……");
    List<Widget> cardContent = [];
    Widget avatar;
    if (info.containsKey("Avatar")) {
      switch (info["Avatar"][0]) {
        case 'icon':
          switch (info["Avatar"][1]) {
            case 'topic':
              avatar = CircleAvatar(
                child: Icon(
                  Icons.collections_bookmark,
                  color: Colors.white,
                ),
                backgroundColor: Colors.amber[700],
              );
              break;
            case 'channel':
              avatar = CircleAvatar(
                child: Icon(
                  Icons.leak_add,
                  color: Colors.white,
                ),
                backgroundColor: Colors.blue[700],
              );
              break;
          }
          break;
        case "avatar":
          avatar = userAvatar(info["Avatar"][1]);
          break;
      }
    } //头像。
    cardContent.add(ListTile(
      leading: avatar,
      title: Text(
        extractFromTree(info, ["Title"], ""),
        textScaleFactor: 1.25,
        maxLines: 1,
      ), //标题。
      subtitle: info.containsKey("Subtitle")
          ? Text(
              htmlUnescape(markdownToHtml(info["Subtitle"])
                      .replaceAll(RegExp(r"<[^>]+>"), ""))
                  .trim(),
              maxLines: singleLineSubtitle ? 1 : null,
            )
          : null, //副标题
      onTap: () {
        if (info.containsKey("HeaderLink") && info["HeaderLink"] != null)
          requestHandler.launchURL(info["HeaderLink"]);
      },
    ));
    if (info.containsKey("Content") && info["Content"] != null) {
      List<Widget> content = MarkdownGenerator(
        data: txtContent,
        styleConfig: StyleConfig(
          titleConfig: TitleConfig(),
          pConfig: PConfig(
            onLinkTap: (url) {
              requestHandler.launchURL(url);
            },
            custom: (node) {
              switch (node.tag) {
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
            return Image.network(url);
          },
        ),
      ).widgets; //内容。
      if (watchMoreSignalFounded) {
        content.add(Text(
          FlutterI18n.translate(_context, "watch_more"),
          style: TextStyle(color: Colors.indigo),
        ));
      }
      if (info.containsKey("ContentLink") && info["ContentLink"] != null)
        cardContent.add(GestureDetector(
          onTap: () {
            requestHandler.launchURL(info["ContentLink"]);
          },
          child: AbsorbPointer(
            child: Container(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: content,
              ),
            ),
          ),
        ));
      else
        cardContent.add(Container(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          ),
        ));
    }
    if (info.containsKey("Message") && info["Message"] != null)
      cardContent.add(Container(
        padding: EdgeInsets.all(12),
        child: Text(
          extractFromTree(info, ["Message"], ""),
          style: TextStyle(color: Theme.of(_context).disabledColor),
        ),
      )); //底端小字。
    if (info.containsKey("Appendix") && info["Appendix"] != null)
      cardContent.add(GestureDetector(
        onTap: () {
          if (info["Appendix"].containsKey("Link") &&
              info["Appendix"]["Link"] != null)
            requestHandler.launchURL(info["Appendix"]["Link"]);
        },
        child: Card(
          margin: EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              (info["Appendix"].containsKey("Cover") &&
                      info["Appendix"]["Cover"] != null)
                  ? Flexible(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.network(
                          info["Appendix"]["Cover"],
                          fit: BoxFit.cover,
                        ),
                      ),
                      flex: 1,
                    )
                  : SizedBox(
                      width: 0,
                    ),
              Flexible(
                child: Container(
                  padding: EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(
                      info["Appendix"]["Title"],
                      textScaleFactor: 1.1,
                      maxLines: 2,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: MarkdownGenerator(
                        data: emojiUtil(info["Appendix"]["Subtitle"]),
                        styleConfig: StyleConfig(
                          titleConfig: TitleConfig(
                            commonStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          pConfig: PConfig(
                            textStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          blockQuoteConfig: BlockQuoteConfig(
                            blockStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          tableConfig: TableConfig(
                            headerStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                            bodyStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          preConfig: PreConfig(
                            textStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          ulConfig: UlConfig(
                            textStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          olConfig: OlConfig(
                            textStyle: TextStyle(
                              color: Theme.of(_context).disabledColor,
                            ),
                          ),
                          imgBuilder: (String url, attributes) {
                            return Image.network(url);
                          },
                        ),
                      ).widgets,
                    ),
                  ),
                ),
                flex: 3,
              )
            ],
          ),
          elevation: 0,
          color: Colors.grey.withAlpha(31),
        ),
      )); //附加的分享信息
    cardContent.add(Container(
      padding: EdgeInsets.all(12),
      child: Text(
        formatTime(extractFromTree(info, ["DateCreated"], 0)),
        style: TextStyle(color: Theme.of(_context).disabledColor),
        textAlign: TextAlign.right,
      ),
    )); //日期

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cardContent,
    );
    return useCard
        ? Card(
            margin: EdgeInsets.all(12),
            child: content,
          )
        : Container(
            padding: EdgeInsets.all(12),
            child: content,
          );
  }

  //标签卡片
  Widget tagCard(Map info) {
    var cardContent = <Widget>[];
    cardContent.add(ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(
            extractFromTree(info, ["IconExists"], false)
                ? "https://fimtale.com/upload/tag/middle/" +
                    extractFromTree(info, ["ID"], 0).toString() +
                    ".png"
                : "https://i.loli.net/2020/04/09/JrxohDzQgKN6vUn.jpg"),
      ), //图标。
      title: Text(
        extractFromTree(info, ["Name"], ""),
        textScaleFactor: 1.25,
        maxLines: 2,
      ), //标签名。
    ));
    String intro = extractFromTree(info, ["Intro"], "");
    bool hasIntro = intro != null && intro.length > 0;
    if (hasIntro) {
      cardContent.add(Container(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          intro,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ));
    } //标签简介。
    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 3,
        runSpacing: 0,
        alignment: WrapAlignment.end,
        children: <Widget>[
          Chip(
            label: Text(extractFromTree(info, ["TotalTopics"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.collections_bookmark,
              color: Colors.lightBlue,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //作品数。
          Chip(
            label: Text(formatTime(extractFromTree(info, ["LastTime"], 0))),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.schedule,
              color: Colors.blue[600],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //最后一个作品的发表日期。
          Chip(
            label: Text(extractFromTree(info, ["Followers"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.favorite,
              color: Colors.red[300],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //关注者。
        ],
      ),
    ));

    return GestureDetector(
      onTap: () {
        Navigator.push(_context, MaterialPageRoute(builder: (_context) {
          return TagView(value: {"TagName": info["Name"]});
        }));
      },
      child: Card(
        margin: EdgeInsets.all(16), //表示边界距离
        child: Column(
          children: cardContent,
          crossAxisAlignment: CrossAxisAlignment.stretch,
        ),
      ),
    );
  }

  //标签列表。
  List<Widget> tagList(List arr) {
    List<Widget> res = [];
    arr.forEach((element) {
      res.add(tagCard(Map.from(element)));
    });
    return res;
  }

  //作品卡片
  Widget topicCard(Map info) {
    var cardContent = <Widget>[];
    String background = extractFromTree(info, ["Background"], null);
    bool hasBackground = background != null && background != "NONE";
    cardContent.add(Stack(
      //Stack用于叠加内容，比如说在背景上罩一个纯黑半透明遮罩或是在背景上加文字。
      children: <Widget>[
        hasBackground
            ? AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  background,
                  fit: BoxFit.cover,
                ),
              ) //如果有封面，就显示封面。
            : SizedBox(
                height: 60,
              ), //如果没有的话，就显示一个高60的占位符，以便放下主标签。
        mainTagSet(
            extractFromTree(info, ["Tags"], {}),
            extractFromTree(info, ["IsDel"], 0) > 0,
            extractFromTree(info, ["ExaminationStatus"], "passed")), //主标签。
      ],
    ));
    cardContent.add(ListTile(
      leading: userAvatar(extractFromTree(info, ["UserID"], 0)), //头像。
      title: Text(
        extractFromTree(info, ["Title"], ""),
        textScaleFactor: 1.25,
        maxLines: 2,
      ), //作品标题。
      subtitle: Text(extractFromTree(info, ["UserName"], "")), //用户名。
    ));
    String intro = extractFromTree(info, ["Intro"], "");
    bool hasIntro = intro != null && intro.length > 0;
    if (hasIntro) {
      cardContent.add(Container(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(intro),
      ));
    } //简介。
    if (!hasBackground || !hasIntro) {
      List<String> tags =
          List.from(extractFromTree(info, ["Tags", "OtherTags"], []));
      cardContent.add(Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 0,
          children: tags2Chips(tags),
        ),
      ));
    } //如果没有封面或简介，则把标签打上占位。
    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Wrap(
        spacing: 3,
        runSpacing: 0,
        alignment: WrapAlignment.end,
        children: <Widget>[
          Chip(
            label: Text(formatTime(extractFromTree(info, ["DateUpdated"], 0))),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.event_note,
              color: Colors.blue[600],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //发表时间。
          Chip(
            label: Text(formatTime(extractFromTree(info, ["LastTime"], 0))),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.schedule,
              color: Colors.blue[600],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //最后活跃时间。
          (extractFromTree(info, ["Tags", "Type"], "内容") == "图集")
              ? Chip(
                  label:
                      Text(extractFromTree(info, ["ImageCount"], 0).toString()),
                  labelStyle: TextStyle(
                    color: Theme.of(_context).disabledColor,
                  ),
                  avatar: Icon(
                    Icons.photo_library,
                    color: Colors.brown,
                  ),
                  backgroundColor: Theme.of(_context).cardColor,
                  padding: EdgeInsets.all(0),
                  labelPadding: EdgeInsets.all(0),
                ) //如果是图楼，显示图片数。
              : Chip(
                  label:
                      Text(extractFromTree(info, ["WordCount"], 0).toString()),
                  labelStyle: TextStyle(
                    color: Theme.of(_context).disabledColor,
                  ),
                  avatar: Icon(
                    Icons.chrome_reader_mode,
                    color: Colors.brown,
                  ),
                  backgroundColor: Theme.of(_context).cardColor,
                  padding: EdgeInsets.all(0),
                  labelPadding: EdgeInsets.all(0),
                ), //如果不是，显示字数。
          Chip(
            label: Text(extractFromTree(info, ["Views"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.visibility,
              color: Colors.teal,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //阅读数。
          Chip(
            label: Text(extractFromTree(info, ["Comments"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.forum,
              color: Colors.deepPurple[400],
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //评论数。
          Chip(
            label: Text(extractFromTree(info, ["Followers"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.collections_bookmark,
              color: Colors.lightBlue,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //收藏数
          Chip(
            label: Text(extractFromTree(info, ["Upvotes"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.thumb_up,
              color: Colors.green,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //赞数。
          Chip(
            label: Text(extractFromTree(info, ["Downvotes"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.thumb_down,
              color: Colors.red,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //踩数。
          Chip(
            label: Text(extractFromTree(info, ["HighPraise"], 0).toString()),
            labelStyle: TextStyle(
              color: Theme.of(_context).disabledColor,
            ),
            avatar: Icon(
              Icons.star,
              color: Colors.orange,
            ),
            backgroundColor: Theme.of(_context).cardColor,
            padding: EdgeInsets.all(0),
            labelPadding: EdgeInsets.all(0),
          ), //黄星数。
        ],
      ),
    ));

    return GestureDetector(
      onTap: () {
        Navigator.push(_context, MaterialPageRoute(builder: (_context) {
          return TopicView(value: {"TopicID": info["ID"]});
        }));
      },
      child: Card(
        margin: EdgeInsets.all(16),
        child: Column(
          children: cardContent,
          crossAxisAlignment: CrossAxisAlignment.stretch,
        ),
      ),
    );
  }

  //标题列表。
  List<Widget> topicList(List arr) {
    List<Widget> res = [];
    arr.forEach((element) {
      res.add(topicCard(Map.from(element)));
    });
    return res;
  }

  //用户卡片。
  Widget userCard(Map info) {
    var cardContent = <Widget>[];
    cardContent.add(GestureDetector(
      onTap: () {
        Navigator.push(_context, MaterialPageRoute(builder: (_context) {
          return UserView(value: {"UserName": info["UserName"]});
        }));
      },
      child: ListTile(
        leading: userAvatar(extractFromTree(info, ["ID"], 0)), //头像。
        title: Text(
          extractFromTree(info, ["UserName"], ""),
          textScaleFactor: 1.25,
          maxLines: 2,
        ), //用户名。
      ),
    ));
    String intro = extractFromTree(info, ["UserIntro"], "");
    bool hasIntro = intro != null && intro.length > 0;
    if (hasIntro) {
      cardContent.add(GestureDetector(
        onTap: () {
          Navigator.push(_context, MaterialPageRoute(builder: (_context) {
            return UserView(value: {"UserName": info["UserName"]});
          }));
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            intro,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ));
    } //简介。
    cardContent.add(Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return UserView(value: {
                  "UserName": info["UserName"],
                  "Interface": "topics"
                });
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.book,
                  color: Colors.lightBlue,
                ),
                Text(extractFromTree(info, ["Topics"], 0).toString()),
              ],
            ),
          ), //作品数。
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return UserView(value: {
                  "UserName": info["UserName"],
                  "Interface": "channels"
                });
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.cast,
                  color: Colors.blue[700],
                ),
                Text(extractFromTree(info, ["Channels"], 0).toString()),
              ],
            ),
          ), //频道数。
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return UserView(value: {
                  "UserName": info["UserName"],
                  "Interface": "blogposts"
                });
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.photo_album,
                  color: Colors.deepPurple,
                ),
                Text(extractFromTree(info, ["Blogposts"], 0).toString()),
              ],
            ),
          ), //博文数。
          GestureDetector(
            onTap: () {
              Navigator.push(_context, MaterialPageRoute(builder: (_context) {
                return UserView(value: {
                  "UserName": info["UserName"],
                  "Interface": "followers"
                });
              }));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.favorite,
                  color: Colors.red[300],
                ),
                Text(extractFromTree(info, ["Followers"], 0).toString()),
              ],
            ),
          ), //粉丝数。
        ],
      ),
    ));

    return Card(
      margin: EdgeInsets.all(16), //表示边界距离
      child: Column(
        children: cardContent,
        crossAxisAlignment: CrossAxisAlignment.stretch,
      ),
    );
  }

  //用户列表。
  List<Widget> userList(List arr) {
    List<Widget> res = [];
    arr.forEach((element) {
      res.add(userCard(Map.from(element)));
    });
    return res;
  }

  //页面标题的格式。
  Widget pageTitle(String text, {Color textColor}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      textScaleFactor: 2.4,
      style: TextStyle(
        fontWeight: FontWeight.w300,
        color: textColor,
      ),
    );
  }

  //页面副标题的格式。
  Widget pageSubtitle(String text, {Color textColor}) {
    return Text(
      text,
      textScaleFactor: 2,
      style: TextStyle(
        fontWeight: FontWeight.w300,
        color: textColor,
      ),
    );
  }

  //根据作品的所有标签来渲染主标签。
  Widget mainTagSet(Map tagInfo, bool isDeleted, String examinationStatus) {
    String type = extractFromTree(tagInfo, ["Type"], ""),
        source = extractFromTree(tagInfo, ["Length"], "") +
            extractFromTree(tagInfo, ["Source"], ""),
        rating = extractFromTree(tagInfo, ["Rating"], ""),
        status = extractFromTree(tagInfo, ["Status"], "");
    if (type == "公告") {
      return Chip(
        label: Text("公告"),
        labelStyle: TextStyle(color: Colors.white),
        backgroundColor: Colors.red[300],
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(3))),
      );
    }
    List<Widget> chips = [];
    bool typeExists = type.length > 0,
        sourceExists = source.length > 0,
        ratingExists = rating.length > 0;
    if (typeExists) {
      var typeShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(3),
          right:
              (sourceExists || ratingExists) ? Radius.zero : Radius.circular(3),
        ),
      );
      switch (type) {
        case "文章":
          chips.add(Chip(
            label: Text("文"),
            labelStyle: TextStyle(color: Colors.white),
            labelPadding: EdgeInsets.symmetric(horizontal: 5),
            backgroundColor: Colors.lightBlue[500],
            shape: typeShape,
          ));
          break;
        case "图集":
          chips.add(Chip(
            label: Text("图"),
            labelStyle: TextStyle(color: Colors.white),
            labelPadding: EdgeInsets.symmetric(horizontal: 5),
            backgroundColor: Colors.amber[600],
            shape: typeShape,
          ));
          break;
        case "帖子":
          chips.add(Chip(
            label: Text("帖"),
            labelStyle: TextStyle(color: Colors.white),
            labelPadding: EdgeInsets.symmetric(horizontal: 5),
            backgroundColor: Colors.teal[300],
            shape: typeShape,
          ));
          break;
        default:
          chips.add(Chip(
            label: Text(type),
            shape: typeShape,
          ));
          break;
      }
    }
    if (sourceExists) {
      var sourceShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: typeExists ? Radius.zero : Radius.circular(3),
          right: ratingExists ? Radius.zero : Radius.circular(3),
        ),
      );
      chips.add(Chip(
        label: Text(source),
        shape: sourceShape,
      ));
    }
    if (ratingExists) {
      var ratingShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          left: (typeExists || sourceExists) ? Radius.zero : Radius.circular(3),
          right: Radius.circular(3),
        ),
      );
      switch (rating) {
        case "Everyone":
          chips.add(Chip(
            label: Text("E"),
            labelStyle: TextStyle(color: Colors.white),
            backgroundColor: Colors.green,
            shape: ratingShape,
          ));
          break;
        case "Teen":
          chips.add(Chip(
            label: Text("T"),
            labelStyle: TextStyle(color: Colors.white),
            backgroundColor: Colors.orange,
            shape: ratingShape,
          ));
          break;
        case "Restricted":
          chips.add(Chip(
            label: Text("R"),
            labelStyle: TextStyle(color: Colors.white),
            backgroundColor: Colors.red[700],
            shape: ratingShape,
          ));
          break;
        default:
          chips.add(Chip(
            label: Text("?"),
            shape: ratingShape,
          ));
          break;
      }
    }

    chips.add(SizedBox(
      width: 15,
    ));

    if (isDeleted) {
      chips.add(Chip(
        label: Text(FlutterI18n.translate(_context, "deleted")),
        labelStyle: TextStyle(color: Colors.white),
        backgroundColor: Colors.red[400],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(3)),
        ),
      ));
    } else {
      switch (examinationStatus) {
        case "outside":
          chips.add(Chip(
            label: Text(FlutterI18n.translate(_context, "examine_outside")),
            labelStyle: TextStyle(color: Colors.white),
            backgroundColor: Colors.blue[400],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
          ));
          break;
        case "pending":
          chips.add(Chip(
            label: Text(FlutterI18n.translate(_context, "examine_pending")),
            labelStyle: TextStyle(color: Colors.white),
            backgroundColor: Colors.amber[700],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3)),
            ),
          ));
          break;
        default:
          if (status.length > 0) {
            chips.add(Chip(
              label: Text(status),
              labelStyle: TextStyle(color: Colors.white),
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(3)),
              ),
            ));
          }
          break;
      }
    }

    chips.map((e) => Expanded(
          child: e,
        ));

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: chips,
      ),
    );
  }

  Widget userGradeLabel(Map<String, dynamic> userGrade) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "Lv." + extractFromTree(userGrade, ["Grade"], 0).toString(),
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: " " +
                extractFromTree(userGrade, ["Exp"], 0).toString() +
                "/" +
                (extractFromTree(userGrade, ["ExpToUpgrade"], 0) +
                        extractFromTree(userGrade, ["Exp"], 0))
                    .toString(),
          ),
        ],
      ),
    );
  }

  Widget singleLineBadges(List<String> badgeStrArray) {
    List<WidgetSpan> innerBadges = [];
    badgeStrArray.forEach((element) {
      innerBadges.add(WidgetSpan(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 5),
          padding: EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(3)),
            color: Color(requestHandler.provider
                .getBadgeColor(element, defValue: 4288585374)),
          ),
          child: Text(
            element,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ));
    });
    return Text.rich(
      TextSpan(style: TextStyle(wordSpacing: 5), children: innerBadges),
      maxLines: 1,
    );
  }

  //将标签字符串转为标签组件，并为其上色。
  List<Widget> tags2Chips(List<String> tags,
      {bool colored = false, Function onTap}) {
    List<Widget> chips = [];
    tags.forEach((element) {
      if (element.length > 0) {
        List<int> tagColor = requestHandler.provider.getTagColor(element);
        Widget innerChip;
        if (tagColor != null) {
          innerChip = Chip(
            label: Text(
              element,
              style: TextStyle(color: Color(tagColor[1])),
            ),
            backgroundColor: Color(tagColor[0]),
          );
        } else {
          innerChip = Chip(
            label: Text(element),
          );
        }
        if (onTap != null)
          chips.add(GestureDetector(
            onTap: () {
              onTap(element);
            },
            child: innerChip,
          ));
        else
          chips.add(innerChip);
      }
    });
    return chips;
  }

  //将字典解析为select选择项，该字典的键为显示的字符串，值为选择该项时所对应的值。
  List<DropdownMenuItem<String>> map2DropdownMenu(
      Map<String, dynamic> kvPairs) {
    List<DropdownMenuItem<String>> dropdownMenu = [];
    kvPairs.forEach((key, value) {
      dropdownMenu.add(DropdownMenuItem(
        child: new Text(key),
        value: value,
      ));
    });
    return dropdownMenu;
  }

  //提示已经到底/到顶。
  Widget endNotice() {
    return Container(
      padding: EdgeInsets.all(12),
      child: Text(
        FlutterI18n.translate(_context, "no_more"),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(_context).disabledColor,
        ),
      ),
    );
  }

  //转圈圈的小圆钮。
  Widget preloader() {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget userAvatar(int userID, {String size = "middle", double radius}) {
    return CircleAvatar(
      backgroundImage: userID > 0
          ? NetworkImage("https://fimtale.com/upload/avatar/" +
              size +
              "/" +
              userID.toString() +
              ".png")
          : AssetImage("assets/images/default_user_avatar.png"),
      radius: radius,
    );
  }

  //输入窗口，一般用于评论和举报窗口。
  Future<String> inputModal(
      {String draftKey,
      String hint,
      String text,
      int maxLength,
      String buttonText,
      List<String> options,
      bool instantSubmit = false,
      Map<String, dynamic> checkBoxConfig,
      Function onChange}) async {
    Map draft = {};
    bool isInit = false;
    if (draftKey != null) {
      draft = jsonDecode(SpUtil.getString("draft_" + draftKey, defValue: "{}"));
    }
    TextEditingController tc = new TextEditingController();
    String res = await showModalBottomSheet(
      context: _context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (BuildContext context) {
        Function insertContent = (String content) {
          TextSelection tempSelection = tc.selection;
          int offset = 0;
          if (tc.text.length > 0) {
            offset = tempSelection.extent.offset;
          }
          if (offset >= 0) {
            String front = tc.text.substring(0, offset),
                back = tc.text.substring(offset);
            tc.text = front + content + back;
            tc.selection = new TextSelection(
                baseOffset: offset + content.length,
                extentOffset: offset + content.length);
          } else {
            tc.text = tc.text + content;
            tc.selection = new TextSelection(
                baseOffset: tc.text.length, extentOffset: tc.text.length);
          }
        };

        if (!isInit) {
          if (text != null) {
            insertContent(text);
          } else if (draft != null && draft.containsKey("Content")) {
            insertContent(draft["Content"]);
          }
          isInit = true;
        }

        return StatefulBuilder(
          builder: (context1, setBottomSheetState) {
            if (options == null) options = [];
            return SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                    12, 12, 12, MediaQuery.of(context).viewInsets.bottom + 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextField(
                      controller: tc,
                      maxLines: 3,
                      style: TextStyle(fontSize: 18.0),
                      maxLength: maxLength,
                      decoration: hint != null
                          ? InputDecoration(labelText: hint)
                          : null,
                      onChanged: (content) {
                        if (draftKey != null) {
                          Map<String, dynamic> newDraft = {};
                          newDraft["Content"] = content;
                          SpUtil.putString(
                              "draft_" + draftKey, jsonEncode(newDraft));
                        }
                        if (onChange != null) onChange(content);
                        setBottomSheetState(() {});
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Wrap(
                            children: <Widget>[
                              options.contains("emoji")
                                  ? IconButton(
                                      icon: Icon(Icons.insert_emoticon),
                                      onPressed: () {
                                        emojiPicker().then((value) {
                                          insertContent(value);
                                          setBottomSheetState(() {});
                                        });
                                      })
                                  : SizedBox(
                                      width: 0,
                                    ),
                              options.contains("image")
                                  ? IconButton(
                                      icon: Icon(Icons.photo),
                                      onPressed: () async {
                                        var image = await ImagePicker.pickImage(
                                            source: ImageSource.gallery);
                                        if (image == null) return;
                                        requestHandler
                                            .uploadImage2ImgBox(image)
                                            .then((value) {
                                          if (value != null) {
                                            if (instantSubmit)
                                              Navigator.pop(context1,
                                                  "![](" + value + ")");
                                            else
                                              insertContent((tc.text.length > 0
                                                      ? "\n"
                                                      : "") +
                                                  "![](" +
                                                  value +
                                                  ")\n");
                                            setBottomSheetState(() {});
                                          }
                                        });
                                      })
                                  : SizedBox(
                                      width: 0,
                                    ),
                              options.contains("at")
                                  ? IconButton(
                                      icon: Icon(Icons.alternate_email),
                                      onPressed: () {
                                        Navigator.push(_context,
                                            MaterialPageRoute(
                                                builder: (_context) {
                                          return ContactSelector();
                                        })).then((value) {
                                          if (value is String &&
                                              value != null &&
                                              value.length > 0)
                                            insertContent("@" + value + " ");
                                        });
                                      })
                                  : SizedBox(
                                      width: 0,
                                    ),
                              options.contains("spoiler")
                                  ? IconButton(
                                      icon: Icon(Icons.crop_square),
                                      onPressed: () {
                                        insertContent("[spoiler]" +
                                            FlutterI18n.translate(
                                                context, "spoiler_desc") +
                                            "[/spoiler]");
                                        setBottomSheetState(() {});
                                      })
                                  : SizedBox(
                                      width: 0,
                                    ),
                              (checkBoxConfig != null &&
                                      checkBoxConfig.containsKey("Label") &&
                                      checkBoxConfig.containsKey("Value"))
                                  ? GestureDetector(
                                      child: Chip(
                                        label: Text(checkBoxConfig["Label"]),
                                        avatar: Checkbox(
                                          value:
                                              checkBoxConfig["Value"] is bool &&
                                                  checkBoxConfig["Value"],
                                        ),
                                        backgroundColor: Colors.transparent,
                                      ),
                                      onTap: () {
                                        setBottomSheetState(() {
                                          checkBoxConfig["Value"] =
                                              !(checkBoxConfig["Value"]
                                                      is bool &&
                                                  checkBoxConfig["Value"]);
                                          if (checkBoxConfig
                                              .containsKey("OnCheck"))
                                            checkBoxConfig["OnCheck"](
                                                checkBoxConfig["Value"]);
                                        });
                                      },
                                    )
                                  : SizedBox(
                                      width: 0,
                                    ),
                            ],
                          ),
                          flex: 4,
                        ),
                        Flexible(
                          child: RaisedButton(
                            child: Text(buttonText != null
                                ? buttonText
                                : (tc.text.length > 0
                                    ? FlutterI18n.translate(context, "send")
                                    : FlutterI18n.translate(context, "quit"))),
                            onPressed: () {
                              tc.text.length > 0
                                  ? Navigator.pop(context1, tc.text)
                                  : Navigator.pop(context1);
                            },
                          ),
                          flex: 1,
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return res;
  }

  //举报/反馈窗口。由于举报功能挺普遍的，因此做一个这个窗口可以用在大多需要举报窗的界面上。
  reportWindow(String type, int id, {String message}) async {
    String content = await inputModal(
      hint: FlutterI18n.translate(
              _context,
              "input_" +
                  (type == "suggestion" ? "suggestion" : "report") +
                  "_content") +
          "(" +
          FlutterI18n.translate(_context, "with_no_more_than_three_images") +
          ")",
      options: ["image"],
    );
    if (content != null && content.length > 0) {
      List<String> images = [];

      content =
          content.replaceAllMapped(RegExp(r"!\[[^\]]*\]\(([^\)]+)\)"), (match) {
        if (images.length < 3) images.add(match.group(1));
        return "";
      });

      Map<String, dynamic> params = {
        "Target": type,
        "Content": content,
        "Images": jsonEncode(images)
      };

      if (message != null) params["AppendedMessage"] = message;

      requestHandler.manage(id, 9, "Report", (res) {
        Toast.show(
            FlutterI18n.translate(_context, "report_successfully_posted"),
            _context);
      }, params: params);
    }
  }

  //表情包选择器。
  Future<String> emojiPicker() async {
    Map<String, dynamic> ftEmoji = {
      "ActiveEmoji": ['dice'],
      "Ponies": [
        "lunateehee",
        "raritydaww",
        "ajsup",
        "ohcomeon",
        "raritynews",
        "lunawait",
        "twicrazy",
        "rarishock",
        "flutterfear",
        "abwut",
        "flutteryay",
        "rarityyell",
        "noooo",
        "spikepushy",
        "soawesome",
        "facehoof",
        "pinkamina",
        "joy",
        "lunagasp",
        "trixiesad",
        "rdscared",
        "lyra",
        "wahaha",
        "pinkiesad",
        "starlightrage",
        "flutterhay",
        "sgpopcorn",
        "celestiahurt",
        "sgsneaky",
        "celestiahappy",
        "lunagrump",
        "twieek",
        "appleroll",
        "tempestgaze",
        "twisheepish",
        "pinkiesugar",
        "sunsetgrump",
        "sunspicious",
        "silverstream",
        "cozyglow"
      ]
    };

    FocusScope.of(_context).requestFocus(FocusNode());

    String res = await showModalBottomSheet(
      context: _context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        List<Widget> contentList = [], tempItem;
        contentList.add(ListTile(
          title: Text(FlutterI18n.translate(context, "dynamic")),
        ));
        tempItem = [];
        ftEmoji["ActiveEmoji"].forEach((e) {
          tempItem.add(GestureDetector(
            onTap: () {
              Navigator.pop(context, ":ftemoji_" + e + ":");
            },
            child: FTEmoji(
              e,
              size: 24,
            ),
          ));
        });
        contentList.add(Container(
          margin: EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tempItem,
          ),
        ));

        contentList.add(ListTile(
          title: Text(FlutterI18n.translate(context, "ponies")),
        ));
        tempItem = [];
        ftEmoji["Ponies"].forEach((e) {
          tempItem.add(GestureDetector(
            onTap: () {
              Navigator.pop(context, ":ftemoji_" + e + ":");
            },
            child: FTEmoji(
              e,
              size: 24,
            ),
          ));
        });
        contentList.add(Container(
          margin: EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tempItem,
          ),
        ));

        contentList.add(ListTile(
          title: Text(FlutterI18n.translate(context, "traditional")),
        ));
        tempItem = [];
        EMOJI_MAP.forEach((key, value) {
          tempItem.add(GestureDetector(
            onTap: () {
              Navigator.pop(context, key);
            },
            child: Text(
              value,
              style: TextStyle(fontSize: 24),
            ),
          ));
        });
        contentList.add(Container(
          margin: EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tempItem,
          ),
        ));

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: contentList,
          ),
        );
      },
    );
    return res;
  }
}
