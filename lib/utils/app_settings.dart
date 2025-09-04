// lib/utils/app_settings.dart
import 'package:flutter/material.dart';

/// Global app settings (simple, package-free).
/// Call AppSettings.setTheme(...) / setLocale(...) to apply instantly across the app.
class AppSettings {
  /// Current theme mode for the whole app.
  static final ValueNotifier<ThemeMode> themeMode =
  ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Current locale for the whole app. `null` means “follow system”.
  static final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  /// Update theme (ThemeMode.system / ThemeMode.light / ThemeMode.dark).
  static void setTheme(ThemeMode m) => themeMode.value = m;

  /// Update locale by language code: 'en' | 'si' | 'ta' | '' (empty => system).
  static void setLocale(String code) =>
      locale.value = code.isEmpty ? null : Locale(code);
}
