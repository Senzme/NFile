import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/file_manager_provider.dart';

class PreferencesService {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyShowHiddenFiles = 'show_hidden_files';
  static const String _keyShowFloatingAddButton = 'show_floating_add_button';
  static const String _keyDefaultToBrowseScreen = 'default_to_browse_screen';
  static const String _keyIsGridView = 'is_grid_view';
  static const String _keyIconScale = 'icon_scale';
  static const String _keySortType = 'sort_type';
  static const String _keyCategoryOrder = 'category_order';
  static const String _keyActiveCategories = 'active_categories';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Theme Mode ---
  static ThemeMode getThemeMode() {
    final str = _prefs?.getString(_keyThemeMode) ?? 'system';
    if (str == 'light') return ThemeMode.light;
    if (str == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    String str = 'system';
    if (mode == ThemeMode.light) str = 'light';
    if (mode == ThemeMode.dark) str = 'dark';
    await _prefs?.setString(_keyThemeMode, str);
  }

  // --- File Manager Settings ---
  static bool getDefaultToBrowseScreen() {
    return _prefs?.getBool(_keyDefaultToBrowseScreen) ?? false;
  }

  static Future<void> saveDefaultToBrowseScreen(bool val) async {
    await _prefs?.setBool(_keyDefaultToBrowseScreen, val);
  }

  static bool getShowHiddenFiles() {
    return _prefs?.getBool(_keyShowHiddenFiles) ?? false;
  }

  static Future<void> saveShowHiddenFiles(bool val) async {
    await _prefs?.setBool(_keyShowHiddenFiles, val);
  }

  static bool getShowFloatingAddButton() {
    return _prefs?.getBool(_keyShowFloatingAddButton) ?? true;
  }

  static Future<void> saveShowFloatingAddButton(bool val) async {
    await _prefs?.setBool(_keyShowFloatingAddButton, val);
  }

  static bool getIsGridView() {
    return _prefs?.getBool(_keyIsGridView) ?? false;
  }

  static Future<void> saveIsGridView(bool val) async {
    await _prefs?.setBool(_keyIsGridView, val);
  }

  static double getIconScale() {
    return _prefs?.getDouble(_keyIconScale) ?? 1.0;
  }

  static Future<void> saveIconScale(double val) async {
    await _prefs?.setDouble(_keyIconScale, val);
  }

  static FileSortType getSortType() {
    final index = _prefs?.getInt(_keySortType) ?? 0;
    if (index >= 0 && index < FileSortType.values.length) {
      return FileSortType.values[index];
    }
    return FileSortType.nameAsc;
  }

  static Future<void> saveSortType(FileSortType type) async {
    await _prefs?.setInt(_keySortType, type.index);
  }

  // --- Home Screen Shortcuts ---
  static List<String>? getCategoryOrder() {
    return _prefs?.getStringList(_keyCategoryOrder);
  }

  static Future<void> saveCategoryOrder(List<String> list) async {
    await _prefs?.setStringList(_keyCategoryOrder, list);
  }

  static List<String>? getActiveCategories() {
    return _prefs?.getStringList(_keyActiveCategories);
  }

  static Future<void> saveActiveCategories(List<String> list) async {
    await _prefs?.setStringList(_keyActiveCategories, list);
  }

  static int getCategoryCount(String category) {
    return _prefs?.getInt('cat_count_$category') ?? 0;
  }

  static Future<void> saveCategoryCount(String category, int count) async {
    await _prefs?.setInt('cat_count_$category', count);
  }
}
