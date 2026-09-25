import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'sendto.theme';

  AppThemeMode mode = AppThemeMode.system;
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString(_key);
    mode = AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode next) async {
    if (mode == next) return;
    mode = next;
    notifyListeners();
    await _prefs?.setString(_key, next.name);
  }

  ThemeData themeFor(Brightness platformBrightness) {
    switch (mode) {
      case AppThemeMode.light:
        return AppTheme.light();
      case AppThemeMode.dark:
        return AppTheme.dark();
      case AppThemeMode.oled:
        return AppTheme.oled();
      case AppThemeMode.system:
        return platformBrightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light();
    }
  }
}
