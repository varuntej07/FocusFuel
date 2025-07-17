import 'package:flutter/material.dart';
import '../Services/shared_prefs_service.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

    // Save preference
    final prefsService = await SharedPreferencesService.getInstance();
    await prefsService.saveThemeMode(_themeMode == ThemeMode.dark);

    notifyListeners();
  }

  void loadTheme() async {
    final prefsService = await SharedPreferencesService.getInstance();
    final isDark = prefsService.getThemeMode() ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}