import 'package:flutter/material.dart';
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;
  void setMode(ThemeMode mode) { if (_mode == mode) return; _mode = mode; notifyListeners(); }
}
class AppTheme {
  static ThemeData light() => ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF5B8CFF), brightness: Brightness.light);
  static ThemeData dark()  => ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF5B8CFF), brightness: Brightness.dark);
}