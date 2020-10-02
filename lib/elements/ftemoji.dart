import 'package:flutter/cupertino.dart';

//FTEmoji类，用于显示FimTale专属的表情图标，继承的是StatelessWidget，即单状态组件，组件内部的状态无法被该组件自身更新。
class FTEmoji extends StatelessWidget {
  String _code = ""; //表情代码。就是":ftemoji_"后":"之前的部分。
  double _size = 14; //尺寸，默认为14px，也就是显示的字体尺寸。

  FTEmoji(String code, {double size}) {
    _code = code;
    if (size != null) _size = size;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1.5 * _size,
      height: 1.5 * _size, //和网站上的缩放大小一致（1.5倍）
      child: Image.network(
        "https://fimtale.com/static/img/ftemoji/" + _code + ".png",
        fit: BoxFit.fill,
      ), //根据code去调取对应的图片。
    );
  }
}
