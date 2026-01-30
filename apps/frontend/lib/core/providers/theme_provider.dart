import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/neumorphism_theme.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to Dark Mode (true) if not set
    final isDark = prefs.getBool(_themeKey) ?? true;
    // CRITICAL: Update the static instance immediately so the first build has correct colors
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = mode;
    NeumorphismTheme.setThemeMode(mode);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    // ⚡ FIX: Update static theme FIRST so UI uses new colors immediately on rebuild
    NeumorphismTheme.setThemeMode(newMode);
    state = newMode;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, newMode == ThemeMode.dark);
  }
  
  Future<void> setDarkMode(bool isDark) async {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (state != newMode) {
      // ⚡ FIX: Update static theme FIRST
      NeumorphismTheme.setThemeMode(newMode);
      state = newMode;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isDark);
    }
  }
}
