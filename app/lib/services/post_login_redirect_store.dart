import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class PostLoginRedirectStore {
  static const _key = 'post_login_redirect';
  static String? _pendingPath;

  static String? get pendingPath => _pendingPath;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingPath = prefs.getString(_key);
  }

  static Future<void> set(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.isEmpty) {
      _pendingPath = null;
      await prefs.remove(_key);
      return;
    }
    _pendingPath = path;
    await prefs.setString(_key, path);
  }

  static String? take() {
    final path = _pendingPath;
    _pendingPath = null;
    unawaited(
      SharedPreferences.getInstance().then((prefs) => prefs.remove(_key)),
    );
    return path;
  }
}
