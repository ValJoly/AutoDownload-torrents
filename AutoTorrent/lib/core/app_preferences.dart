import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultAccentColor = Color(0xFFEAA4BD);

final appPreferences = AppPreferences();

class AppPreferences extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';
  static const _accentColorKey = 'accent_color';

  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = defaultAccentColor;
  Future<void>? _initialization;

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _themeMode = switch (preferences.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _accentColor = Color(
      preferences.getInt(_accentColorKey) ?? defaultAccentColor.toARGB32(),
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == _themeMode) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    _themeMode = value;
    notifyListeners();
  }

  Future<void> setAccentColor(Color value) async {
    if (value == _accentColor) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_accentColorKey, value.toARGB32());
    _accentColor = value;
    notifyListeners();
  }
}
