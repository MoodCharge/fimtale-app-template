import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

//小黑条，继承的是StatefulWidget（多状态组件），可以在组件内部切换不同的状态。
class Spoiler extends StatefulWidget {
  final String content;
  final TextStyle textStyle;

  const Spoiler({Key key, @required this.content, this.textStyle})
      : super(key: key);

  //多状态组件里面有一个createState函数，该函数用来生成状态。返回值为类型为该类的状态实例。
  @override
  _SpoilerState createState() => _SpoilerState(content, textStyle);
}

//在这里完成对其状态的实现
class _SpoilerState extends State<Spoiler> {
  String _content = "";
  TextStyle _textStyle;
  bool _isVisible = false;
  TapGestureRecognizer recognizer = TapGestureRecognizer();

  _SpoilerState(String content, TextStyle textStyle) {
    _content = content;
    _textStyle = textStyle;
  }

  //初始化状态
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    //手势探测器，可以完成多种手势操作。本次使用的是它的onTap参数，也就是单击时触发。
    return GestureDetector(
      onTap: () {
        if (mounted)
          setState(() {
            _isVisible = !_isVisible;
          }); //setState函数会更新它的状态，也就是在传入的闭包执行之后重新调用一遍build函数。
      }, //这个以参数形式传递的函数叫做闭包，闭包可以在后方加上小括号，在括号内部放入所需参数调用。
      child: Text(
        _isVisible ? _content : "▒" * _content.length,
        style: _textStyle,
      ),
    );
  }
}
