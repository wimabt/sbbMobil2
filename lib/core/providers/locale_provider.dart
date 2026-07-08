import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_events.dart';
import '../services/analytics_service.dart';

/// Key for storing the selected language in SharedPreferences
const String _kLocalePrefsKey = 'app_locale';

/// Supported locales for the application
const List<Locale> supportedLocales = [
  Locale('tr'), // Turkish (default)
  Locale('en'), // English
];

/// State class for locale management
class LocaleState {
  final Locale locale;
  final bool isLoading;

  const LocaleState({
    required this.locale,
    this.isLoading = false,
  });

  LocaleState copyWith({
    Locale? locale,
    bool? isLoading,
  }) {
    return LocaleState(
      locale: locale ?? this.locale,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier for managing application locale state
class LocaleNotifier extends Notifier<LocaleState> {
  @override
  LocaleState build() {
    // Return default state, actual loading happens in loadLocale()
    return const LocaleState(locale: Locale('tr'));
  }

  /// Load the saved locale from SharedPreferences on app start
  Future<void> loadLocale() async {
    state = state.copyWith(isLoading: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLocale = prefs.getString(_kLocalePrefsKey);

      if (savedLocale != null && savedLocale.isNotEmpty) {
        // Use saved locale if available
        final locale = Locale(savedLocale);
        if (_isSupported(locale)) {
          state = LocaleState(locale: locale, isLoading: false);
          return;
        }
      }

      // Try to use device locale if supported
      final deviceLocale = _getDeviceLocale();
      if (_isSupported(deviceLocale)) {
        state = LocaleState(locale: deviceLocale, isLoading: false);
        return;
      }

      // Fallback to Turkish
      state = const LocaleState(locale: Locale('tr'), isLoading: false);
    } catch (e) {
      // On error, default to Turkish
      state = const LocaleState(locale: Locale('tr'), isLoading: false);
    }
  }

  /// Change the application locale and persist the choice
  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale)) {
      return;
    }

    final previousLocale = state.locale.languageCode;
    state = state.copyWith(isLoading: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalePrefsKey, locale.languageCode);
      state = LocaleState(locale: locale, isLoading: false);
      // mobile_analytics_todo.md §2.13 — language_changed (sadece gerçek değişimde)
      if (previousLocale != locale.languageCode) {
        ref.read(analyticsServiceProvider).track(
          AnalyticsEvents.languageChanged,
          properties: {'from': previousLocale, 'to': locale.languageCode},
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggle between Turkish and English
  Future<void> toggleLocale() async {
    final newLocale = state.locale.languageCode == 'tr' 
        ? const Locale('en') 
        : const Locale('tr');
    await setLocale(newLocale);
  }

  /// Check if a locale is supported
  bool _isSupported(Locale locale) {
    return supportedLocales.any((l) => l.languageCode == locale.languageCode);
  }

  /// Get the device's current locale
  Locale _getDeviceLocale() {
    try {
      final localeName = Platform.localeName;
      final parts = localeName.split('_');
      return Locale(parts.first);
    } catch (e) {
      return const Locale('tr');
    }
  }
}

/// Provider for locale state management
final localeProvider = NotifierProvider<LocaleNotifier, LocaleState>(() {
  return LocaleNotifier();
});

/// Extension for easy access to current locale
extension LocaleStateX on LocaleState {
  /// Returns the current language code (e.g., 'tr' or 'en')
  String get languageCode => locale.languageCode;

  /// Returns true if the current locale is Turkish
  bool get isTurkish => locale.languageCode == 'tr';

  /// Returns true if the current locale is English
  bool get isEnglish => locale.languageCode == 'en';

  /// Returns the language name in its native form
  String get languageName {
    switch (locale.languageCode) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      default:
        return locale.languageCode;
    }
  }

  /// Returns the flag emoji for the current locale
  String get flagEmoji {
    switch (locale.languageCode) {
      case 'tr':
        return '🇹🇷';
      case 'en':
        return '🇬🇧';
      default:
        return '🌍';
    }
  }
}
