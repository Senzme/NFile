import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/file_manager_provider.dart';
import '../models/custom_shortcut_model.dart';

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
  static const String _keyShowFolderFileCount = 'show_folder_file_count';
  static const String _keyShowBottomActionBar = 'show_bottom_action_bar';

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

  static bool getShowFolderFileCount() {
    return _prefs?.getBool(_keyShowFolderFileCount) ?? false;
  }

  static Future<void> saveShowFolderFileCount(bool val) async {
    await _prefs?.setBool(_keyShowFolderFileCount, val);
  }

  static bool getShowBottomActionBar() {
    return _prefs?.getBool(_keyShowBottomActionBar) ?? false;
  }

  static Future<void> saveShowBottomActionBar(bool val) async {
    await _prefs?.setBool(_keyShowBottomActionBar, val);
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

  static const String _keyCustomShortcuts = 'custom_shortcuts';

  static List<CustomShortcutModel>? getCustomShortcuts() {
    final str = _prefs?.getString(_keyCustomShortcuts);
    if (str == null) return null;
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => CustomShortcutModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCustomShortcuts(List<CustomShortcutModel> list) async {
    final str = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs?.setString(_keyCustomShortcuts, str);
  }

  static const String _keyPinnedFolderShortcuts = 'pinned_folder_shortcuts';

  static List<CustomShortcutModel> getPinnedFolderShortcuts() {
    final str = _prefs?.getString(_keyPinnedFolderShortcuts);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => CustomShortcutModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> savePinnedFolderShortcuts(List<CustomShortcutModel> list) async {
    final str = jsonEncode(list.map((e) => e.toJson()).toList());
    await _prefs?.setString(_keyPinnedFolderShortcuts, str);
  }

  static const String _keyAccentColor = 'accent_color';

  static String getAccentColor() {
    return _prefs?.getString(_keyAccentColor) ?? 'blue';
  }

  static Future<void> saveAccentColor(String val) async {
    await _prefs?.setString(_keyAccentColor, val);
  }

  static Color getSeedColor(String name) {
    switch (name) {
      case 'orange': return const Color(0xFFFF6D00);
      case 'purple': return const Color(0xFF8E24AA);
      case 'green': return const Color(0xFF00C853);
      case 'red': return const Color(0xFFD50000);
      case 'gold': return const Color(0xFFFFD600);
      case 'blue': return const Color(0xFF369FE7);
      case 'dynamic':
      default:
        return const Color(0xFF369FE7);
    }
  }

  static const String _keyFolderIconStyle = 'folder_icon_style';

  static String getFolderIconStyle() {
    return _prefs?.getString(_keyFolderIconStyle) ?? 'broken';
  }

  static Future<void> saveFolderIconStyle(String val) async {
    await _prefs?.setString(_keyFolderIconStyle, val);
  }
}
