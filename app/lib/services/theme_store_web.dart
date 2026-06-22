// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html';

import 'theme_store.dart';

class ThemeStoreImpl implements ThemeStore {
  @override
  Future<String?> read(String key) async {
    return window.localStorage[key];
  }

  @override
  Future<void> write(String key, String value) async {
    window.localStorage[key] = value;
  }
}
