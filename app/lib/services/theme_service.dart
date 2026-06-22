import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeSetting {
  light(ThemeMode.light, 'Light', Icons.light_mode),
  dark(ThemeMode.dark, 'Dark', Icons.dark_mode),
  system(ThemeMode.system, 'System', Icons.brightness_auto);

  final ThemeMode themeMode;
  final String displayName;
  final IconData icon;

  const ThemeSetting(this.themeMode, this.displayName, this.icon);

  String get storageValue => name;

  static ThemeSetting fromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeSetting.light;
      case 'dark':
        return ThemeSetting.dark;
      case 'system':
        return ThemeSetting.system;
      default:
        return ThemeSetting.system;
    }
  }
}

class ThemeService {
  static const _key = 'theme_mode';

  final StreamController<ThemeSetting> _controller =
      StreamController<ThemeSetting>.broadcast();

  Stream<ThemeSetting> get themeModeStream => _controller.stream;

  Future<ThemeSetting> getTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      return ThemeSetting.fromStorage(value);
    } catch (_) {
      return ThemeSetting.system;
    }
  }

  Future<void> setTheme(ThemeSetting setting) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, setting.storageValue);
    } catch (_) {
      // Persistence unavailable — still apply theme for this session
    }
    _controller.add(setting);
  }

  void dispose() {
    _controller.close();
  }
}
