import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

//解析Base64图片。
//TODO:完善它。

class Base64Image {
  String _mime = "", _content = "";

  String get appendix => _mime;

  bool get isValid => _mime.length > 0 && _content.length > 0;

  Base64Image(String str) {
    print("image:" + str);
    str.replaceAllMapped(RegExp(r"^data\:image\/([^;]*);base64,(.*)$"),
        (match) {
      _mime = match.group(1);
      _content = match.group(2);
      print('aaaaa');
      print(_mime);
      print(_content);
      return match.group(0);
    });
  }

  Uint8List decode() {
    return Base64Decoder().convert(_content);
  }

  Widget widget() {
    return Image.memory(decode());
  }
}
