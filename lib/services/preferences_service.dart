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
  static const String _keyItemPaddingMultiplier = 'item_padding_multiplier';
  static const String _keySortType = 'sort_type';
  static const String _keyCategoryOrder = 'category_order';
  static const String _keyActiveCategories = 'active_categories';
  static const String _keyShowFolderFileCount = 'show_folder_file_count';
  static const String _keyShowBottomActionBar = 'show_bottom_action_bar';
  static const String _keyEnableMultipleTabs = 'enable_multiple_tabs';
  static const String _keyEnableSplitScreen = 'enable_split_screen';
  static const String _keyShowAddressBar = 'show_address_bar';
  static const String _keyAmoledMode = 'amoled_mode';
  static const String _keyFolderSortTypes = 'folder_sort_types';

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

  // --- Amoled Mode ---
  static bool getAmoledMode() {
    return _prefs?.getBool(_keyAmoledMode) ?? false;
  }

  static Future<void> saveAmoledMode(bool val) async {
    await _prefs?.setBool(_keyAmoledMode, val);
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

  static const String _keyShowHomeBrowseNav = 'show_home_browse_nav';

  static bool getShowHomeBrowseNav() {
    return _prefs?.getBool(_keyShowHomeBrowseNav) ?? true;
  }

  static Future<void> saveShowHomeBrowseNav(bool val) async {
    await _prefs?.setBool(_keyShowHomeBrowseNav, val);
  }

  static const String _keyShowMediaPreviews = 'show_media_previews';

  static bool getShowMediaPreviews() {
    return _prefs?.getBool(_keyShowMediaPreviews) ?? true;
  }

  static Future<void> saveShowMediaPreviews(bool val) async {
    await _prefs?.setBool(_keyShowMediaPreviews, val);
  }

  static bool getEnableMultipleTabs() {
    return _prefs?.getBool(_keyEnableMultipleTabs) ?? false;
  }

  static Future<void> saveEnableMultipleTabs(bool val) async {
    await _prefs?.setBool(_keyEnableMultipleTabs, val);
  }

  static bool getEnableSplitScreen() {
    return _prefs?.getBool(_keyEnableSplitScreen) ?? false;
  }

  static Future<void> saveEnableSplitScreen(bool val) async {
    await _prefs?.setBool(_keyEnableSplitScreen, val);
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

  static double getItemPaddingMultiplier() {
    return _prefs?.getDouble(_keyItemPaddingMultiplier) ?? 1.0;
  }

  static Future<void> saveItemPaddingMultiplier(double val) async {
    await _prefs?.setDouble(_keyItemPaddingMultiplier, val);
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

  static Map<String, FileSortType> getFolderSortTypes() {
    final str = _prefs?.getString(_keyFolderSortTypes);
    if (str == null) return {};
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return map.map((key, value) {
        final idx = value as int;
        if (idx >= 0 && idx < FileSortType.values.length) {
          return MapEntry(key, FileSortType.values[idx]);
        }
        return MapEntry(key, FileSortType.nameAsc);
      });
    } catch (e) {
      debugPrint('Error loading folder sort types: $e');
      return {};
    }
  }

  static Future<void> saveFolderSortTypes(Map<String, FileSortType> map) async {
    final jsonMap = map.map((key, value) => MapEntry(key, value.index));
    await _prefs?.setString(_keyFolderSortTypes, jsonEncode(jsonMap));
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
  static const String _keyFontFamily = 'font_family';

  static String getAccentColor() {
    return _prefs?.getString(_keyAccentColor) ?? 'blue';
  }

  static Future<void> saveAccentColor(String val) async {
    await _prefs?.setString(_keyAccentColor, val);
  }

  static String getFontFamily() {
    return _prefs?.getString(_keyFontFamily) ?? 'default';
  }

  static Future<void> saveFontFamily(String val) async {
    await _prefs?.setString(_keyFontFamily, val);
  }

  static Color getSeedColor(String name) {
    switch (name) {
      case 'orange': return const Color(0xFFFF6D00);
      case 'purple': return const Color(0xFF8E24AA);
      case 'green': return const Color(0xFF00C853);
      case 'red': return const Color(0xFFD50000);
      case 'gold': return const Color(0xFFFFD600);
      case 'pink': return const Color(0xFFFF2E93);
      case 'sapphire': return const Color(0xFF0F52BA);
      case 'forest': return const Color(0xFF228B22);
      case 'peach': return const Color(0xFFFF7F50);
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

  // --- Preferred Media Category default view & Open With preferences ---
  static const String _keyPreferFoldersInMedia = 'prefer_folders_in_media';
  static const String _keyHideNavigationBar = 'hide_navigation_bar';
  static const String _keyDefaultOpenActionPrefix = 'default_open_action_';
  static const String _keySkipOpenWithDialog = 'skip_open_with_dialog';

  static bool getPreferFoldersInMedia() {
    return _prefs?.getBool(_keyPreferFoldersInMedia) ?? false;
  }

  static Future<void> savePreferFoldersInMedia(bool val) async {
    await _prefs?.setBool(_keyPreferFoldersInMedia, val);
  }

  static bool getHideNavigationBar() {
    return _prefs?.getBool(_keyHideNavigationBar) ?? false;
  }

  static Future<void> saveHideNavigationBar(bool val) async {
    await _prefs?.setBool(_keyHideNavigationBar, val);
  }

  static bool getSkipOpenWithDialog() {
    return _prefs?.getBool(_keySkipOpenWithDialog) ?? true;
  }

  static Future<void> saveSkipOpenWithDialog(bool val) async {
    await _prefs?.setBool(_keySkipOpenWithDialog, val);
  }

  static String? getDefaultOpenAction(String ext) {
    final sanitizedExt = ext.toLowerCase().replaceAll('.', '');
    return _prefs?.getString('$_keyDefaultOpenActionPrefix$sanitizedExt');
  }

  static Future<void> saveDefaultOpenAction(String ext, String action) async {
    final sanitizedExt = ext.toLowerCase().replaceAll('.', '');
    await _prefs?.setString('$_keyDefaultOpenActionPrefix$sanitizedExt', action);
  }

  static Future<void> clearAllDefaultOpenActions() async {
    final keys = _prefs?.getKeys() ?? {};
    final keysToRemove = keys.where((k) => k.startsWith(_keyDefaultOpenActionPrefix)).toList();
    for (final key in keysToRemove) {
      await _prefs?.remove(key);
    }
  }

  // --- Address Bar Settings ---
  static bool getShowAddressBar() {
    return _prefs?.getBool(_keyShowAddressBar) ?? true;
  }

  static Future<void> saveShowAddressBar(bool val) async {
    await _prefs?.setBool(_keyShowAddressBar, val);
  }

  static const String _keyShowRecentFiles = 'show_recent_files';
  static const String _keyEnableFolderHighlight = 'enable_folder_highlight';

  static bool getShowRecentFiles() {
    return _prefs?.getBool(_keyShowRecentFiles) ?? true;
  }

  static Future<void> saveShowRecentFiles(bool val) async {
    await _prefs?.setBool(_keyShowRecentFiles, val);
  }

  static bool getEnableFolderHighlight() {
    return _prefs?.getBool(_keyEnableFolderHighlight) ?? false;
  }

  static Future<void> saveEnableFolderHighlight(bool val) async {
    await _prefs?.setBool(_keyEnableFolderHighlight, val);
  }

  static const String _keyEnableDragDrop = 'enable_drag_drop';

  static bool getEnableDragDrop() {
    return _prefs?.getBool(_keyEnableDragDrop) ?? false;
  }

  static Future<void> saveEnableDragDrop(bool val) async {
    await _prefs?.setBool(_keyEnableDragDrop, val);
  }

  static const String _keyUse24HourFormat = 'use_24_hour_format';
  static const String _keyHideTimeAndDate = 'hide_time_and_date';
  static const String _keyShowFolderContentsCount = 'show_folder_contents_count';

  static bool getUse24HourFormat() {
    return _prefs?.getBool(_keyUse24HourFormat) ?? false;
  }

  static Future<void> saveUse24HourFormat(bool val) async {
    await _prefs?.setBool(_keyUse24HourFormat, val);
  }

  static bool getHideTimeAndDate() {
    return _prefs?.getBool(_keyHideTimeAndDate) ?? false;
  }

  static Future<void> saveHideTimeAndDate(bool val) async {
    await _prefs?.setBool(_keyHideTimeAndDate, val);
  }

  static bool getShowFolderContentsCount() {
    return _prefs?.getBool(_keyShowFolderContentsCount) ?? false;
  }

  static Future<void> saveShowFolderContentsCount(bool val) async {
    await _prefs?.setBool(_keyShowFolderContentsCount, val);
  }

  static const String _keyShowFolderSizes = 'show_folder_sizes';

  static bool getShowFolderSizes() {
    return _prefs?.getBool(_keyShowFolderSizes) ?? false;
  }

  static Future<void> saveShowFolderSizes(bool val) async {
    await _prefs?.setBool(_keyShowFolderSizes, val);
  }

  static const String _keyCachedTotalStorage = 'cached_total_storage';
  static const String _keyCachedUsedStorage = 'cached_used_storage';

  static int getCachedTotalStorage() {
    return _prefs?.getInt(_keyCachedTotalStorage) ?? 0;
  }

  static Future<void> saveCachedTotalStorage(int val) async {
    await _prefs?.setInt(_keyCachedTotalStorage, val);
  }

  static int getCachedUsedStorage() {
    return _prefs?.getInt(_keyCachedUsedStorage) ?? 0;
  }

  static Future<void> saveCachedUsedStorage(int val) async {
    await _prefs?.setInt(_keyCachedUsedStorage, val);
  }

  static const String _keyAdaptiveMultiLineNames = 'adaptive_multiline_names';

  static bool getAdaptiveMultiLineNames() {
    return _prefs?.getBool(_keyAdaptiveMultiLineNames) ?? false;
  }

  static Future<void> saveAdaptiveMultiLineNames(bool val) async {
    await _prefs?.setBool(_keyAdaptiveMultiLineNames, val);
  }

  static const String _keyHideActionMenuButtons = 'hide_action_menu_buttons';

  static bool getHideActionMenuButtons() {
    return _prefs?.getBool(_keyHideActionMenuButtons) ?? false;
  }

  static Future<void> saveHideActionMenuButtons(bool val) async {
    await _prefs?.setBool(_keyHideActionMenuButtons, val);
  }
}
