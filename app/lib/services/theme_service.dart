import 'dart:async';

import 'package:flutter/material.dart';

import 'theme_store.dart';

enum ThemeSetting {
  mindPalace(
    'Mind Palace',
    Icons.language,
    Color(0xFF6750A4),
    Brightness.light,
    subtitle: 'Default',
  ),
  midnight(
    'Midnight',
    Icons.nightlight_round,
    Color(0xFF7C6FF7),
    Brightness.dark,
  ),
  warm('Warm', Icons.wb_sunny, Color(0xFFE63946), Brightness.light),
  neutral('Neutral', Icons.blur_on, Color(0xFF475569), Brightness.light);

  final String displayName;
  final IconData icon;
  final Color seedColor;
  final Brightness brightness;
  final String? subtitle;

  const ThemeSetting(
    this.displayName,
    this.icon,
    this.seedColor,
    this.brightness, {
    this.subtitle,
  });

  String get storageValue => name;

  static ThemeSetting fromStorage(String? value) {
    for (final setting in ThemeSetting.values) {
      if (setting.storageValue == value) return setting;
    }
    return ThemeSetting.mindPalace;
  }
}

class ThemeService {
  static const _key = 'theme_mode';
  final ThemeStore _store;

  final StreamController<ThemeSetting> _controller =
      StreamController<ThemeSetting>.broadcast();

  Stream<ThemeSetting> get themeModeStream => _controller.stream;

  ThemeService({ThemeStore? store}) : _store = store ?? createThemeStore();

  Future<ThemeSetting> getTheme() async {
    try {
      final value = await _store.read(_key);
      return ThemeSetting.fromStorage(value);
    } catch (_) {
      return ThemeSetting.mindPalace;
    }
  }

  Future<void> setTheme(ThemeSetting setting) async {
    try {
      await _store.write(_key, setting.storageValue);
    } catch (_) {
      // Persistence unavailable — still apply theme for this session
    }
    _controller.add(setting);
  }

  void dispose() {
    _controller.close();
  }
}
