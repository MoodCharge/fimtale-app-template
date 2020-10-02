import 'dart:convert';

import 'package:fimtale/library/consts.dart';
import 'package:flutter/material.dart';
import 'package:sp_util/sp_util.dart';

class AppInfoProvider with ChangeNotifier {
  bool _isReady = false;
  Map _currentUser = {}, _userPreference = {}, _badges = {}, _tags = {};

  int get UserID => getUserInfo("ID", defValue: 0);

  String get UserName => getUserInfo("UserName", defValue: "");

  Map get UserInfo => _currentUser;

  Map get UserPreference => _userPreference;

  Map get tags => _tags;

  Map get badges => _badges;

  int get UserRole => getUserInfo("UserRole", defValue: 0);

  Locale get locale => _getLocale();

  String get themeColor => _getThemeColor();

  bool get isDataReady => _isReady;

  @override
  void notifyListeners() {
    super.notifyListeners();
  }

  setReady(bool isReady) {
    _isReady = isReady;
    print("已准备充足");
    notifyListeners();
  }

  setSystemProperties(Map badges, Map tags) {
    _badges = badges;
    _tags = tags;
    print(_badges);
    print("设置徽章和标签");
  }

  int getBadgeColor(String index, {int defValue}) {
    return _badges.containsKey(index) ? _badges[index] : defValue;
  }

  List<int> getTagColor(String index, {List<int> defValue}) {
    return _tags.containsKey(index)
        ? List<int>.from([_tags[index][1], _tags[index][2]])
        : defValue;
  }

  String getEmoji(String index, {String defValue}) {
    return EMOJI_MAP.containsKey(index) ? EMOJI_MAP[index] : defValue;
  }

  bool _hasTheme() {
    return _currentUser.containsKey("Theme") &&
        _currentUser["Theme"] != null &&
        _currentUser["Theme"] is String &&
        _currentUser["Theme"].length > 0;
  }

  String _getThemeColor() {
    return _hasTheme() ? _currentUser["Theme"] : "";
  }

  Locale _getLocale() {
    List<String> curLang =
        getUserPreference("Lang", defValue: "zh_CN").split("_");
    return curLang.length > 1
        ? Locale(curLang[0], curLang[1])
        : Locale(curLang[0]);
  }

  getUserInfo(String key, {dynamic defValue}) {
    return _currentUser.containsKey(key) ? _currentUser[key] : defValue;
  }

  setUserInfo(String key, dynamic value) {
    _currentUser[key] = value;
    notifyListeners();
  }

  loadUserInfo() async {
    Map userInfo =
        jsonDecode(SpUtil.getString("current_user_info", defValue: "{}"));
    if (userInfo == null) userInfo = {};
    initUserInfo(userInfo, notify: false);
  }

  initUserInfo(Map userInfo, {bool notify = true}) {
    final int formerUserID = UserID;
    final String formerTheme = _getThemeColor();
    _currentUser = userInfo;
    if (!_hasTheme()) _currentUser["Theme"] = "default";
    if (notify && (UserID != formerUserID || _getThemeColor() != formerTheme))
      notifyListeners();
  }

  saveUserInfo() async {
    if (_currentUser == null) _currentUser = {};
    SpUtil.putString("current_user_info", jsonEncode(_currentUser));
  }

  getUserPreference(String key, {dynamic defValue}) {
    return _userPreference.containsKey(key) ? _userPreference[key] : defValue;
  }

  setUserPreference(String key, dynamic value) {
    _userPreference[key] = value;
    notifyListeners();
  }

  loadUserPreference() async {
    Map userPreference =
        jsonDecode(SpUtil.getString("current_user_preference", defValue: "{}"));
    if (userPreference == null) userPreference = {};
    initUserPreference(userPreference, notify: false);
  }

  initUserPreference(Map preference, {bool notify = true}) {
    _userPreference = preference;
    if (notify) notifyListeners();
  }

  saveUserPreference() async {
    if (_userPreference == null) _userPreference = {};
    SpUtil.putString("current_user_preference", jsonEncode(_userPreference));
  }
}
