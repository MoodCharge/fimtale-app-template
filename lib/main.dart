import 'package:fimtale/views/lists/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:provider/provider.dart';
import 'package:fimtale/views/others/launching_page.dart';
import 'package:fimtale/library/app_provider.dart';
import 'package:fimtale/library/consts.dart';

//dart程序和c++程序差不多，程序运行时会执行main函数。Flutter App中默认执行的是main.dart的main函数。
void main() {
  //runApp为函数，将MyApp类作为参数传入可以启动该应用。
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  //定义MyApp类中的全局变量，这些都是存储主题对应颜色的变量
  String _colorKey;
  Color _themeColor, _accentColor, _indicatorColor, _lightColor;

  @override
  Widget build(BuildContext context) {
    //provider用于更新全局信息，适合在一个应用内所有route共同传递同一信息时使用。
    return MultiProvider(
      providers: [ChangeNotifierProvider.value(value: AppInfoProvider())],
      child: Consumer<AppInfoProvider>(
        builder: (context, appInfo, _) {
          _colorKey = appInfo
              .themeColor; //这是存取在provider里的信息，使用themeColor来调取。详情见library/app_provider.dart
          if (themeColorMap[_colorKey] == null) _colorKey = "default";
          _themeColor = themeColorMap[_colorKey]["ThemeColor"];
          _accentColor = themeColorMap[_colorKey]["AccentColor"];
          _indicatorColor = themeColorMap[_colorKey]["IndicatorColor"];
          _lightColor = themeColorMap[_colorKey]
              ["LightColor"]; //上面的这些全都是应用主题的表达式，将提取出来的主题信息分别赋值给各变量。

          print("更新");
          print(appInfo.isDataReady);

          //构造App主体。
          return MaterialApp(
            title: 'FimTale',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: _themeColor,
              accentColor: _accentColor,
              indicatorColor: _indicatorColor,
              tabBarTheme: TabBarTheme(
                  labelColor: _indicatorColor,
                  unselectedLabelColor: _lightColor),
              floatingActionButtonTheme:
                  FloatingActionButtonThemeData(backgroundColor: _themeColor),
            ),
            //应用ThemeData来更换主题。
            home: LaunchingPage(),
            //先打开启动页面，然后再通过启动页面进入主页
            localizationsDelegates: [
              FlutterI18nDelegate(
                translationLoader: FileTranslationLoader(
                  basePath: "assets/lang",
                  useCountryCode: true,
                  forcedLocale: appInfo.locale,
                  fallbackFile: "zh_CN",
                  decodeStrategies: [JsonDecodeStrategy()],
                ),
                missingTranslationHandler: (key, locale) {
                  print(
                      "[FlutterI18n] Missing Key: $key, languageCode: ${locale.languageCode}");
                },
              ),
            ],
            builder: FlutterI18n.rootAppBuilder(), //加载国际化（多语言）模块，以适应不同语言。
          );
        },
      ),
    );
  }
}
