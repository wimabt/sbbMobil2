import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeState {
  const ThemeState({
    required this.mode,
  });

  final ThemeMode mode;
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const _key = 'theme';

  @override
  ThemeState build() {
    return const ThemeState(mode: ThemeMode.system);
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key) ?? 'system';

    switch (value) {
      case 'light':
        state = const ThemeState(mode: ThemeMode.light);
        break;
      case 'dark':
        state = const ThemeState(mode: ThemeMode.dark);
        break;
      default:
        state = const ThemeState(mode: ThemeMode.system);
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    late ThemeMode themeMode;
    late String value;

    switch (mode) {
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
        value = 'light';
        break;
      case AppThemeMode.dark:
        themeMode = ThemeMode.dark;
        value = 'dark';
        break;
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
        value = 'system';
        break;
    }

    state = ThemeState(mode: themeMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);



