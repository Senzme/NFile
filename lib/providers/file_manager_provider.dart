import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item_model.dart';
import '../models/folder_tab_model.dart';
import '../models/file_filter_type.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import '../ui/screens/image_viewer_screen.dart';
import '../ui/screens/video_player/video_player_screen.dart';
import '../ui/screens/audio_player/audio_player_screen.dart';
import '../ui/screens/text_editor_screen.dart';
import '../ui/screens/document_viewer_screen.dart';
import '../ui/screens/archive_viewer_screen.dart';
import '../ui/screens/database_reader_screen.dart';
import '../services/archive_service.dart';
import '../services/apk_installer_service.dart';
import '../ui/widgets/extract_archive_dialog.dart';
import '../core/utils.dart';
import '../services/preferences_service.dart';
import '../models/custom_shortcut_model.dart';
import '../services/root_shizuku_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../core/icon_fonts/broken_icons.dart';
import '../ui/widgets/open_with_sheet.dart';
import '../ui/widgets/conflict_dialog.dart';

enum FileSortType {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  sizeLargest,
  sizeSmallest,
  type,
}

class StorageVolume {
  final String name;
  final String path;
  final bool isInternal;

  StorageVolume({required this.name, required this.path, required this.isInternal});
}

class FileManagerProvider extends ChangeNotifier {
  FileManagerProvider() {
    _sortType = PreferencesService.getSortType();
    _isGridView = PreferencesService.getIsGridView();
    _iconScale = PreferencesService.getIconScale();
    _itemPaddingMultiplier = PreferencesService.getItemPaddingMultiplier();
    _showHiddenFiles = PreferencesService.getShowHiddenFiles();
    _showFloatingAddButton = PreferencesService.getShowFloatingAddButton();
    _defaultToBrowseScreen = PreferencesService.getDefaultToBrowseScreen();
    _showFolderFileCount = PreferencesService.getShowFolderFileCount();
    _showBottomActionBar = PreferencesService.getShowBottomActionBar();
    _showHomeBrowseNav = PreferencesService.getShowHomeBrowseNav();
    _showMediaPreviews = PreferencesService.getShowMediaPreviews();
    _enableMultipleTabs = PreferencesService.getEnableMultipleTabs();
    _enableSplitScreen = PreferencesService.getEnableSplitScreen();
    _accentColorOption = PreferencesService.getAccentColor();
    _fontFamilyOption = PreferencesService.getFontFamily();
    _folderIconOption = PreferencesService.getFolderIconStyle();
    _pinnedFolderShortcuts = PreferencesService.getPinnedFolderShortcuts();
    _hideNavigationBar = PreferencesService.getHideNavigationBar();
    _skipOpenWithDialog = PreferencesService.getSkipOpenWithDialog();
    _showAddressBar = PreferencesService.getShowAddressBar();
    _amoledMode = PreferencesService.getAmoledMode();
    _showRecentFiles = PreferencesService.getShowRecentFiles();
    _enableFolderHighlight = PreferencesService.getEnableFolderHighlight();
    _folderSortTypes = PreferencesService.getFolderSortTypes();
    _enableDragDrop = PreferencesService.getEnableDragDrop();
  }

  final ValueNotifier<FileOperationProgress?> progressNotifier = ValueNotifier<FileOperationProgress?>(null);
  bool _isOperationCancelled = false;

  void cancelOperation() {
    _isOperationCancelled = true;
  }

  List<CustomShortcutModel> _pinnedFolderShortcuts = [];
  List<CustomShortcutModel> get pinnedFolderShortcuts => _pinnedFolderShortcuts;

  void addPinnedFolderShortcut(String path, String label) {
    if (_pinnedFolderShortcuts.any((e) => e.path == path)) return;
    final shortcut = CustomShortcutModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      path: path,
      isDirectory: true,
    );
    _pinnedFolderShortcuts.add(shortcut);
    PreferencesService.savePinnedFolderShortcuts(_pinnedFolderShortcuts);
    notifyListeners();
  }

  void removePinnedFolderShortcut(String id) {
    _pinnedFolderShortcuts.removeWhere((e) => e.id == id);
    PreferencesService.savePinnedFolderShortcuts(_pinnedFolderShortcuts);
    notifyListeners();
  }

  String _accentColorOption = 'blue';
  String get accentColorOption => _accentColorOption;

  void setAccentColorOption(String val) {
    if (_accentColorOption == val) return;
    _accentColorOption = val;
    PreferencesService.saveAccentColor(val);
    notifyListeners();
  }

  String _fontFamilyOption = 'default';
  String get fontFamilyOption => _fontFamilyOption;

  void setFontFamilyOption(String val) {
    if (_fontFamilyOption == val) return;
    _fontFamilyOption = val;
    PreferencesService.saveFontFamily(val);
    notifyListeners();
  }

  String _folderIconOption = 'broken';
  String get folderIconOption => _folderIconOption;

  void setFolderIconOption(String val) {
    if (_folderIconOption == val) return;
    _folderIconOption = val;
    PreferencesService.saveFolderIconStyle(val);
    notifyListeners();
  }

  FileSortType _sortType = FileSortType.nameAsc;
  FileSortType get sortType => _sortType;

  Map<String, FileSortType> _folderSortTypes = {};
  Map<String, FileSortType> get folderSortTypes => _folderSortTypes;

  bool isFolderOverrideEnabled(String path) {
    return _folderSortTypes.containsKey(path);
  }

  void setFolderOverrideEnabled(String path, bool enabled) {
    if (enabled) {
      _folderSortTypes[path] = getSortTypeForPath(path);
    } else {
      _folderSortTypes.remove(path);
    }
    PreferencesService.saveFolderSortTypes(_folderSortTypes);
    
    if (_tabs.isNotEmpty && currentPath == path) {
      final folders = currentFiles.where((e) => e.isDirectory).toList();
      final files = currentFiles.where((e) => !e.isDirectory).toList();
      _sortList(folders, path);
      _sortList(files, path);
      activeTab.currentFiles = [...folders, ...files];
    }
    notifyListeners();
  }

  FileSortType getSortTypeForPath(String path) {
    return _folderSortTypes[path] ?? _sortType;
  }

  void setSortType(FileSortType type) {
    final path = currentPath;
    final hasOverride = isFolderOverrideEnabled(path);
    
    if (hasOverride) {
      if (_folderSortTypes[path] == type) return;
      _folderSortTypes[path] = type;
      PreferencesService.saveFolderSortTypes(_folderSortTypes);
    } else {
      if (_sortType == type) return;
      _sortType = type;
      PreferencesService.saveSortType(_sortType);
    }
    
    if (_tabs.isNotEmpty) {
      final folders = currentFiles.where((e) => e.isDirectory).toList();
      final files = currentFiles.where((e) => !e.isDirectory).toList();
      _sortList(folders, path);
      _sortList(files, path);
      activeTab.currentFiles = [...folders, ...files];
    }
    notifyListeners();
  }

  FileFilterType _filterType = FileFilterType.all;
  FileFilterType get filterType => _filterType;

  void setFilterType(FileFilterType type) {
    if (_filterType == type) return;
    _filterType = type;
    loadDirectory(currentPath, showLoading: false);
    notifyListeners();
  }

  bool _hideFoldersInFilter = false;
  bool get hideFoldersInFilter => _hideFoldersInFilter;

  void toggleHideFoldersInFilter() {
    _hideFoldersInFilter = !_hideFoldersInFilter;
    if (_tabs.isNotEmpty) {
      loadDirectory(currentPath, showLoading: false);
    }
    notifyListeners();
  }

  static bool matchesFilterForType(String path, FileFilterType filter) {
    switch (filter) {
      case FileFilterType.all:
        return true;
      case FileFilterType.documents:
        final lower = path.toLowerCase();
        const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv', '.odt', '.ods', '.odp', '.rtf', '.epub'];
        return docExts.any((ext) => lower.endsWith(ext)) || FileUtils.isTextOrCode(path);
      case FileFilterType.images:
        return FileUtils.isImage(path);
      case FileFilterType.audio:
        return FileUtils.isAudio(path);
      case FileFilterType.videos:
        return FileUtils.isVideo(path);
      case FileFilterType.archives:
        return FileUtils.isArchive(path);
    }
  }

  bool _matchesFilter(String path) {
    return matchesFilterForType(path, _filterType);
  }

  final Map<String, int> _folderMatchingFileCounts = {};

  Future<int> getMatchingFileCount(String folderPath, FileFilterType filter) async {
    final cacheKey = '$folderPath:${filter.name}';
    if (_folderMatchingFileCounts.containsKey(cacheKey)) {
      return _folderMatchingFileCounts[cacheKey]!;
    }

    int count = 0;
    try {
      final dir = Directory(folderPath);
      if (await dir.exists()) {
        final List<FileSystemEntity> entities = await dir.list().toList();
        for (var entity in entities) {
          if (entity is File) {
            if (matchesFilterForType(entity.path, filter)) {
              count++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error counting matching files in $folderPath: $e');
    }

    _folderMatchingFileCounts[cacheKey] = count;
    return count;
  }

  String getFilterTypeName(FileFilterType filter, int count) {
    switch (filter) {
      case FileFilterType.all:
        return '';
      case FileFilterType.documents:
        return count == 1 ? 'document' : 'documents';
      case FileFilterType.images:
        return count == 1 ? 'image' : 'images';
      case FileFilterType.audio:
        return count == 1 ? 'audio' : 'audios';
      case FileFilterType.videos:
        return count == 1 ? 'video' : 'videos';
      case FileFilterType.archives:
        return count == 1 ? 'archive' : 'archives';
    }
  }

  bool _isGridView = false;
  bool get isGridView => _isGridView;

  void setGridView(bool value) {
    if (_isGridView == value) return;
    _isGridView = value;
    PreferencesService.saveIsGridView(_isGridView);
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    PreferencesService.saveIsGridView(_isGridView);
    notifyListeners();
  }

  double _iconScale = 1.0;
  double get iconScale => _iconScale;

  void setIconScale(double scale) {
    final clamped = scale.clamp(0.7, 1.5);
    if (_iconScale == clamped) return;
    _iconScale = clamped;
    PreferencesService.saveIconScale(_iconScale);
    notifyListeners();
  }

  double _itemPaddingMultiplier = 1.0;
  double get itemPaddingMultiplier => _itemPaddingMultiplier;

  void setItemPaddingMultiplier(double mult) {
    final clamped = mult.clamp(0.4, 2.0);
    if (_itemPaddingMultiplier == clamped) return;
    _itemPaddingMultiplier = clamped;
    PreferencesService.saveItemPaddingMultiplier(_itemPaddingMultiplier);
    notifyListeners();
  }

  void _sortList(List<FileItemModel> items, String path) {
    final activeSort = getSortTypeForPath(path);
    switch (activeSort) {
      case FileSortType.nameAsc:
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case FileSortType.nameDesc:
        items.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case FileSortType.dateNewest:
        items.sort((a, b) => b.modified.compareTo(a.modified));
        break;
      case FileSortType.dateOldest:
        items.sort((a, b) => a.modified.compareTo(b.modified));
        break;
      case FileSortType.sizeLargest:
        items.sort((a, b) => b.size.compareTo(a.size));
        break;
      case FileSortType.sizeSmallest:
        items.sort((a, b) => a.size.compareTo(b.size));
        break;
      case FileSortType.type:
        items.sort((a, b) {
          final extA = p.extension(a.name).toLowerCase();
          final extB = p.extension(b.name).toLowerCase();
          return extA.compareTo(extB);
        });
        break;
    }
  }

  bool _showHiddenFiles = false;
  bool get showHiddenFiles => _showHiddenFiles;

  void toggleHiddenFiles() {
    _showHiddenFiles = !_showHiddenFiles;
    PreferencesService.saveShowHiddenFiles(_showHiddenFiles);
    notifyListeners();
    if (_tabs.isNotEmpty && currentPath.isNotEmpty) {
      loadDirectory(currentPath, showLoading: false);
    }
  }

  bool _showFloatingAddButton = true;
  bool get showFloatingAddButton => _showFloatingAddButton;

  void toggleFloatingAddButton() {
    _showFloatingAddButton = !_showFloatingAddButton;
    PreferencesService.saveShowFloatingAddButton(_showFloatingAddButton);
    notifyListeners();
  }

  bool _defaultToBrowseScreen = false;
  bool get defaultToBrowseScreen => _defaultToBrowseScreen;

  void toggleDefaultToBrowseScreen() {
    _defaultToBrowseScreen = !_defaultToBrowseScreen;
    PreferencesService.saveDefaultToBrowseScreen(_defaultToBrowseScreen);
    notifyListeners();
  }

  bool _showFolderFileCount = false;
  bool get showFolderFileCount => _showFolderFileCount;

  void toggleFolderFileCount() {
    _showFolderFileCount = !_showFolderFileCount;
    PreferencesService.saveShowFolderFileCount(_showFolderFileCount);
    notifyListeners();
  }

  bool _showBottomActionBar = false;
  bool get showBottomActionBar => _showBottomActionBar;

  void toggleBottomActionBar() {
    _showBottomActionBar = !_showBottomActionBar;
    PreferencesService.saveShowBottomActionBar(_showBottomActionBar);
    notifyListeners();
  }

  bool _showHomeBrowseNav = true;
  bool get showHomeBrowseNav => _showHomeBrowseNav;

  void toggleShowHomeBrowseNav() {
    _showHomeBrowseNav = !_showHomeBrowseNav;
    PreferencesService.saveShowHomeBrowseNav(_showHomeBrowseNav);
    notifyListeners();
  }

  bool _hideNavigationBar = false;
  bool get hideNavigationBar => _hideNavigationBar;

  void toggleHideNavigationBar() {
    _hideNavigationBar = !_hideNavigationBar;
    PreferencesService.saveHideNavigationBar(_hideNavigationBar);
    if (_hideNavigationBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    notifyListeners();
  }

  bool _showMediaPreviews = true;
  bool get showMediaPreviews => _showMediaPreviews;

  void toggleMediaPreviews() {
    _showMediaPreviews = !_showMediaPreviews;
    PreferencesService.saveShowMediaPreviews(_showMediaPreviews);
    notifyListeners();
  }

  bool _skipOpenWithDialog = true;
  bool get skipOpenWithDialog => _skipOpenWithDialog;

  void toggleSkipOpenWithDialog() {
    _skipOpenWithDialog = !_skipOpenWithDialog;
    PreferencesService.saveSkipOpenWithDialog(_skipOpenWithDialog);
    notifyListeners();
  }

  bool _showAddressBar = true;
  bool get showAddressBar => _showAddressBar;

  void toggleShowAddressBar() {
    _showAddressBar = !_showAddressBar;
    PreferencesService.saveShowAddressBar(_showAddressBar);
    notifyListeners();
  }

  bool _amoledMode = false;
  bool get amoledMode => _amoledMode;

  void toggleAmoledMode() {
    _amoledMode = !_amoledMode;
    PreferencesService.saveAmoledMode(_amoledMode);
    notifyListeners();
  }

  void setAmoledMode(bool val) {
    if (_amoledMode == val) return;
    _amoledMode = val;
    PreferencesService.saveAmoledMode(val);
    notifyListeners();
  }

  bool _showRecentFiles = false;
  bool get showRecentFiles => _showRecentFiles;

  void toggleShowRecentFiles() {
    _showRecentFiles = !_showRecentFiles;
    PreferencesService.saveShowRecentFiles(_showRecentFiles);
    notifyListeners();
  }

  bool _enableFolderHighlight = false;
  bool get enableFolderHighlight => _enableFolderHighlight;

  void toggleEnableFolderHighlight() {
    _enableFolderHighlight = !_enableFolderHighlight;
    PreferencesService.saveEnableFolderHighlight(_enableFolderHighlight);
    notifyListeners();
  }

  bool _enableDragDrop = false;
  bool get enableDragDrop => _enableDragDrop;

  void toggleEnableDragDrop() {
    _enableDragDrop = !_enableDragDrop;
    PreferencesService.saveEnableDragDrop(_enableDragDrop);
    notifyListeners();
  }

  bool _enableMultipleTabs = false;
  bool get enableMultipleTabs => _enableMultipleTabs;

  void toggleMultipleTabs() {
    _enableMultipleTabs = !_enableMultipleTabs;
    PreferencesService.saveEnableMultipleTabs(_enableMultipleTabs);
    if (!_enableMultipleTabs) {
      closeOtherTabs();
    }
    notifyListeners();
  }

  bool _enableSplitScreen = false;
  bool get enableSplitScreen => _enableSplitScreen;

  void toggleSplitScreen() {
    _enableSplitScreen = !_enableSplitScreen;
    PreferencesService.saveEnableSplitScreen(_enableSplitScreen);
    
    if (_enableSplitScreen) {
      if (_tabs.length < 2) {
        final initialPath = _rootPath.isNotEmpty ? _rootPath : '/';
        final newTab = FolderTab(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          currentPath: initialPath,
        );
        _tabs.add(newTab);
      }
      loadDirectoryForTab(0, _tabs[0].currentPath, showLoading: false);
      loadDirectoryForTab(1, _tabs[1].currentPath, showLoading: false);
    } else {
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = 0;
      }
    }
    notifyListeners();
  }

  Future<void> loadDirectoryForTab(int tabIndex, String path, {bool showLoading = true}) async {
    if (tabIndex >= 0 && tabIndex < _tabs.length) {
      final oldIndex = _activeTabIndex;
      _activeTabIndex = tabIndex;
      await loadDirectory(path, showLoading: showLoading);
      _activeTabIndex = oldIndex;
    }
  }

  // --- Tab Management ---
  List<FolderTab> _tabs = [];
  int _activeTabIndex = 0;

  List<FolderTab> get tabs => _tabs;
  int get activeTabIndex => _activeTabIndex;

  FolderTab get activeTab {
    if (_tabs.isEmpty) {
      _tabs = [FolderTab(id: 'default', currentPath: _rootPath.isNotEmpty ? _rootPath : '/')];
    }
    return _tabs[_activeTabIndex];
  }

  void addTab(String path) {
    final newTab = FolderTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      currentPath: path,
    );
    _tabs.add(newTab);
    _activeTabIndex = _tabs.length - 1;
    notifyListeners();
    loadDirectory(path);
  }

  void closeTab(int index) {
    if (_tabs.length <= 1) return;
    _tabs.removeAt(index);
    if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.length - 1;
    } else if (_activeTabIndex == index) {
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
    } else if (_activeTabIndex > index) {
      _activeTabIndex--;
    }
    notifyListeners();
  }

  void closeOtherTabs() {
    if (_tabs.length <= 1) return;
    final active = activeTab;
    _tabs = [active];
    _activeTabIndex = 0;
    notifyListeners();
  }

  void duplicateActiveTab() {
    if (_tabs.isEmpty) return;
    final active = activeTab;
    final dup = FolderTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      currentPath: active.currentPath,
      currentFiles: List.from(active.currentFiles),
      isRestrictedMode: active.isRestrictedMode,
      needsPermission: active.needsPermission,
      useRootMode: active.useRootMode,
      useShizukuMode: active.useShizukuMode,
      isRootAvailable: active.isRootAvailable,
      scrollPositions: Map.from(active.scrollPositions),
    );
    _tabs.add(dup);
    _activeTabIndex = _tabs.length - 1;
    notifyListeners();
  }

  void setActiveTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  // --- Active Tab Delegations ---
  List<FileItemModel> get currentFiles => activeTab.currentFiles;
  String get currentPath => activeTab.currentPath;
  bool get isLoading => activeTab.isLoading;
  bool get isRestrictedMode => activeTab.isRestrictedMode;
  bool get needsPermission => activeTab.needsPermission;
  bool get useRootMode => activeTab.useRootMode;
  bool get useShizukuMode => activeTab.useShizukuMode;
  bool get isRootAvailable => activeTab.isRootAvailable;
  Set<String> get selectedPaths => activeTab.selectedPaths;
  bool get isSelectionMode => selectedPaths.isNotEmpty;

  // --- Global Clipboard ---
  final List<String> _clipboardPaths = [];
  bool _isCut = false;
  String? _sourceArchiveForCut;
  List<String>? _internalSourcePathsForCut;

  bool get hasClipboard => _clipboardPaths.isNotEmpty;
  List<String> get clipboardPaths => _clipboardPaths;
  bool get isCut => _isCut;

  void setClipboard(List<String> paths, {required bool isCut, String? sourceArchive, List<String>? internalSourcePaths}) {
    _clipboardPaths.clear();
    _clipboardPaths.addAll(paths);
    _isCut = isCut;
    _sourceArchiveForCut = sourceArchive;
    _internalSourcePathsForCut = internalSourcePaths;
    notifyListeners();
  }

  void clearClipboard() {
    _clipboardPaths.clear();
    _isCut = false;
    _sourceArchiveForCut = null;
    _internalSourcePathsForCut = null;
    notifyListeners();
  }

  final Set<String> _highlightedPaths = {};
  Set<String> get highlightedPaths => _highlightedPaths;

  bool _shouldScrollToHighlight = false;
  bool get shouldScrollToHighlight => _shouldScrollToHighlight;

  void resetScrollToHighlight() {
    _shouldScrollToHighlight = false;
  }

  String _rootPath = '';
  String get rootPath => _rootPath;

  bool get canGoBack {
    final path = currentPath;
    if (path.isEmpty || _rootPath.isEmpty) return false;
    if (path == _rootPath || path == '/' || p.dirname(path) == path) {
      return false;
    }
    return true;
  }

  void saveScrollOffset(String path, double offset) {
    if (path.isNotEmpty) {
      activeTab.scrollPositions[path] = offset;
    }
  }

  double getSavedScrollOffset(String path) {
    return activeTab.scrollPositions[path] ?? 0.0;
  }

  List<StorageVolume> _storageVolumes = [];
  List<StorageVolume> get storageVolumes => _storageVolumes;

  int _totalStorageBytes = 0;
  int _usedStorageBytes = 0;

  int get totalStorageBytes => _totalStorageBytes;
  int get usedStorageBytes => _usedStorageBytes;
  double get storageUsedPercentage => _totalStorageBytes == 0 ? 0.0 : (_usedStorageBytes / _totalStorageBytes);

  Future<void> updateStorageSpace() async {
    final space = await RootShizukuService.getStorageSpace();
    if (space != null) {
      final rawTotal = space['totalBytes'] ?? 0;
      final rawUsed = space['usedBytes'] ?? 0;

      if (rawTotal > 0) {
        final double rawTotalGb = rawTotal / (1024 * 1024 * 1024);
        double marketingGb = rawTotalGb;

        if (rawTotalGb <= 8) {
          marketingGb = 8.0;
        } else if (rawTotalGb <= 16) {
          marketingGb = 16.0;
        } else if (rawTotalGb <= 32) {
          marketingGb = 32.0;
        } else if (rawTotalGb <= 64) {
          marketingGb = 64.0;
        } else if (rawTotalGb <= 128) {
          marketingGb = 128.0;
        } else if (rawTotalGb <= 256) {
          marketingGb = 256.0;
        } else if (rawTotalGb <= 512) {
          marketingGb = 512.0;
        } else if (rawTotalGb <= 1024) {
          marketingGb = 1024.0;
        } else if (rawTotalGb <= 2048) {
          marketingGb = 2048.0;
        } else {
          marketingGb = rawTotalGb.roundToDouble();
        }

        final int marketingTotalBytes = (marketingGb * 1024 * 1024 * 1024).toInt();
        final int systemReservedBytes = marketingTotalBytes - rawTotal;
        final int adjustedUsedBytes = rawUsed + systemReservedBytes;

        _totalStorageBytes = marketingTotalBytes;
        _usedStorageBytes = adjustedUsedBytes;
      } else {
        _totalStorageBytes = 0;
        _usedStorageBytes = 0;
      }
      notifyListeners();
    }
  }

  void setRootPath(String path) {
    _rootPath = path;
    if (_tabs.isNotEmpty) {
      activeTab.currentPath = path;
    }
    notifyListeners();
  }

  Future<void> _detectStorageVolumes() async {
    updateStorageSpace();
    final volumes = <StorageVolume>[];
    if (Platform.isAndroid) {
      volumes.add(StorageVolume(name: 'Internal Storage', path: '/storage/emulated/0', isInternal: true));

      try {
        final extDirs = await getExternalStorageDirectories();
        if (extDirs != null) {
          for (final dir in extDirs) {
            final path = dir.path;
            if (path.contains('/Android/')) {
              final root = path.substring(0, path.indexOf('/Android/'));
              if (root != '/storage/emulated/0' && root != '/storage/emulated') {
                final name = root.contains('-') ? 'SD Card (${p.basename(root)})' : 'SD Card / USB';
                if (!volumes.any((v) => v.path == root)) {
                  volumes.add(StorageVolume(name: name, path: root, isInternal: false));
                }
              }
            }
          }
        }
      } catch (_) {}

      try {
        final storageDir = Directory('/storage');
        if (storageDir.existsSync()) {
          final list = storageDir.listSync();
          for (final entity in list) {
            if (entity is Directory) {
              final base = p.basename(entity.path);
              if (base != 'emulated' && base != 'self' && base != 'enterprise') {
                if (!volumes.any((v) => v.path == entity.path)) {
                  final name = base.contains('-') ? 'SD Card ($base)' : 'SD Card / USB ($base)';
                  volumes.add(StorageVolume(name: name, path: entity.path, isInternal: false));
                }
              }
            }
          }
        }
      } catch (_) {}
    } else {
      final dir = await getApplicationDocumentsDirectory();
      volumes.add(StorageVolume(name: 'Documents', path: dir.path, isInternal: true));
    }
    _storageVolumes = volumes;
    notifyListeners();
  }

  Future<void> init() async {
    String initialPath = '/';
    if (Platform.isAndroid) {
      initialPath = '/storage/emulated/0';
      if (!Directory(initialPath).existsSync()) {
        final dir = await getExternalStorageDirectory();
        initialPath = dir?.path ?? '/';
      }
      _rootPath = initialPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      initialPath = dir.path;
      _rootPath = initialPath;
    }
    
    // Initialize primary default tab
    _tabs = [
      FolderTab(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        currentPath: initialPath,
      )
    ];
    if (_enableSplitScreen) {
      _tabs.add(FolderTab(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        currentPath: initialPath,
      ));
    }
    _activeTabIndex = 0;

    await _detectStorageVolumes();
    await loadDirectory(initialPath, showLoading: false);
    if (_enableSplitScreen) {
      await loadDirectoryForTab(1, initialPath, showLoading: false);
    }
  }

  bool isRestrictedPath(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('/android/data') || lower.contains('/android/obb')) {
      return true;
    }
    // Only /data (excluding /data/media) is strictly restricted by default
    if (path == '/data' || (path.startsWith('/data/') && !path.startsWith('/data/media'))) {
      return true;
    }
    return false;
  }

  Future<void> enableRootMode() async {
    activeTab.useRootMode = true;
    activeTab.useShizukuMode = false;
    activeTab.needsPermission = false;
    notifyListeners();
    await loadDirectory(currentPath, showLoading: true);
  }

  Future<void> enableShizukuMode() async {
    final granted = await RootShizukuService.requestShizukuPermission();
    if (granted) {
      activeTab.useShizukuMode = true;
      activeTab.useRootMode = false;
      activeTab.needsPermission = false;
      notifyListeners();
      await loadDirectory(currentPath, showLoading: true);
    }
  }

  Future<void> loadDirectory(String path, {bool showLoading = true}) async {
    if (currentPath != path) {
      _highlightedPaths.clear();
    }
    if (_storageVolumes.isEmpty) {
      _detectStorageVolumes();
    }

    if (showLoading) {
      activeTab.isLoading = true;
      notifyListeners();
    }

    activeTab.isRestrictedMode = isRestrictedPath(path);

    if (activeTab.isRestrictedMode) {
      final status = await RootShizukuService.checkStatus();
      activeTab.isRootAvailable = status.isRootAvailable;
      if (status.isRootAvailable && (activeTab.useRootMode || !status.isShizukuAvailable)) {
        activeTab.useRootMode = true;
        activeTab.useShizukuMode = false;
        activeTab.needsPermission = false;
      } else if (status.isShizukuAvailable && status.shizukuPermissionGranted) {
        activeTab.useShizukuMode = true;
        activeTab.useRootMode = false;
        activeTab.needsPermission = false;
      } else {
        activeTab.needsPermission = true;
        activeTab.currentPath = path;
        activeTab.currentFiles = [];
        activeTab.isLoading = false;
        notifyListeners();
        return;
      }

      try {
        activeTab.currentPath = path;
        final items = await RootShizukuService.listFiles(path, useRoot: activeTab.useRootMode, showHiddenFiles: _showHiddenFiles);
        final folders = items.where((e) => e.isDirectory).toList();
        final files = items.where((e) => !e.isDirectory).toList();

        final filteredFiles = _filterType == FileFilterType.all
            ? files
            : files.where((e) => _matchesFilter(e.path)).toList();
        final filteredFolders = (_filterType != FileFilterType.all && _hideFoldersInFilter) ? <FileItemModel>[] : folders;

        _sortList(filteredFolders, path);
        _sortList(filteredFiles, path);
        activeTab.currentFiles = [...filteredFolders, ...filteredFiles];
      } catch (e) {
        debugPrint('Error loading restricted directory: $e');
        activeTab.currentFiles = [];
      }
      activeTab.isLoading = false;
      notifyListeners();
      return;
    }

    activeTab.needsPermission = false;
    activeTab.useRootMode = false;
    activeTab.useShizukuMode = false;

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        activeTab.currentPath = path;
        final entities = await dir.list().toList();
        
        final folders = <FileItemModel>[];
        final files = <FileItemModel>[];

        final items = await Future.wait(entities.map((e) => FileItemModel.fromEntityAsync(e)));

        for (var item in items) {
          if (!_showHiddenFiles && item.isHidden) {
            continue;
          }
          if (item.isDirectory) {
            folders.add(item);
          } else {
            files.add(item);
          }
        }

        final filteredFiles = _filterType == FileFilterType.all
            ? files
            : files.where((e) => _matchesFilter(e.path)).toList();
        final filteredFolders = (_filterType != FileFilterType.all && _hideFoldersInFilter) ? <FileItemModel>[] : folders;

        _sortList(filteredFolders, path);
        _sortList(filteredFiles, path);

        activeTab.currentFiles = [...filteredFolders, ...filteredFiles];
      }
    } catch (e) {
      debugPrint('Error loading directory: $e. Fallback to restricted mode.');
      // Auto fallback to restricted mode
      activeTab.isRestrictedMode = true;
      final status = await RootShizukuService.checkStatus();
      activeTab.isRootAvailable = status.isRootAvailable;
      if (status.isRootAvailable && (activeTab.useRootMode || !status.isShizukuAvailable)) {
        activeTab.useRootMode = true;
        activeTab.useShizukuMode = false;
        activeTab.needsPermission = false;
      } else if (status.isShizukuAvailable && status.shizukuPermissionGranted) {
        activeTab.useShizukuMode = true;
        activeTab.useRootMode = false;
        activeTab.needsPermission = false;
      } else {
        activeTab.needsPermission = true;
        activeTab.currentPath = path;
        activeTab.currentFiles = [];
        activeTab.isLoading = false;
        notifyListeners();
        return;
      }

      try {
        activeTab.currentPath = path;
        final items = await RootShizukuService.listFiles(path, useRoot: activeTab.useRootMode, showHiddenFiles: _showHiddenFiles);
        final folders = items.where((e) => e.isDirectory).toList();
        final files = items.where((e) => !e.isDirectory).toList();

        final filteredFiles = _filterType == FileFilterType.all
            ? files
            : files.where((e) => _matchesFilter(e.path)).toList();
        final filteredFolders = (_filterType != FileFilterType.all && _hideFoldersInFilter) ? <FileItemModel>[] : folders;

        _sortList(filteredFolders, path);
        _sortList(filteredFiles, path);
        activeTab.currentFiles = [...filteredFolders, ...filteredFiles];
      } catch (err) {
        debugPrint('Error loading restricted directory fallback: $err');
        activeTab.currentFiles = [];
      }
    }

    activeTab.isLoading = false;
    notifyListeners();
  }

  Future<bool> goBack() async {
    if (!canGoBack) return false;
    final exitedPath = currentPath;
    final parent = p.dirname(currentPath);
    await loadDirectory(parent, showLoading: false);
    _highlightedPaths.clear();
    _highlightedPaths.add(exitedPath);
    notifyListeners();
    Timer(const Duration(milliseconds: 2000), () {
      if (_highlightedPaths.remove(exitedPath)) {
        notifyListeners();
      }
    });
    return true;
  }

  void toggleSelection(String path) {
    if (selectedPaths.contains(path)) {
      selectedPaths.remove(path);
    } else {
      selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    selectedPaths.clear();
    selectedPaths.addAll(currentFiles.map((f) => f.path));
    notifyListeners();
  }

  void clearSelection() {
    selectedPaths.clear();
    notifyListeners();
  }

  void copyFile(String path) {
    setClipboard([path], isCut: false);
  }

  void cutFile(String path) {
    setClipboard([path], isCut: true);
  }

  void copySelected() {
    if (selectedPaths.isEmpty) return;
    setClipboard(selectedPaths.toList(), isCut: false);
    selectedPaths.clear();
    notifyListeners();
  }

  void cutSelected() {
    if (selectedPaths.isEmpty) return;
    setClipboard(selectedPaths.toList(), isCut: true);
    selectedPaths.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (selectedPaths.isEmpty) return;

    activeTab.isLoading = true;
    notifyListeners();

    try {
      for (final path in selectedPaths) {
        if (isRestrictedPath(path)) {
          await RootShizukuService.deleteItem(path, useRoot: useRootMode);
        } else {
          final type = FileSystemEntity.typeSync(path);
          if (type == FileSystemEntityType.directory) {
            await Directory(path).delete(recursive: true);
          } else {
            await File(path).delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error deleting selected files: $e');
    }

    selectedPaths.clear();
    activeTab.isLoading = false;
    await loadDirectory(currentPath, showLoading: false);
  }

  Future<void> pasteFile(BuildContext context, {bool clearAfterPaste = true}) async {
    if (_clipboardPaths.isEmpty) return;

    _isOperationCancelled = false;
    activeTab.isLoading = true;
    notifyListeners();

    try {
      // 1. Calculate total size and gather all files
      int totalBytes = 0;
      final List<Map<String, dynamic>> itemsToProcess = [];

      for (final srcPath in _clipboardPaths) {
        final type = FileSystemEntity.typeSync(srcPath);
        if (type == FileSystemEntityType.file) {
          final file = File(srcPath);
          final size = file.lengthSync();
          totalBytes += size;
          itemsToProcess.add({
            'source': file,
            'destPath': p.join(currentPath, p.basename(srcPath)),
            'size': size,
            'isDir': false,
          });
        } else if (type == FileSystemEntityType.directory) {
          final dir = Directory(srcPath);
          final parentPath = p.dirname(srcPath);
          
          itemsToProcess.add({
            'source': dir,
            'destPath': p.join(currentPath, p.basename(srcPath)),
            'size': 0,
            'isDir': true,
          });

          try {
            final entities = dir.listSync(recursive: true, followLinks: false);
            for (final entity in entities) {
              final relPath = p.relative(entity.path, from: parentPath);
              final destPath = p.join(currentPath, relPath);
              
              if (entity is Directory) {
                itemsToProcess.add({
                  'source': entity,
                  'destPath': destPath,
                  'size': 0,
                  'isDir': true,
                });
              } else if (entity is File) {
                final size = entity.lengthSync();
                totalBytes += size;
                itemsToProcess.add({
                  'source': entity,
                  'destPath': destPath,
                  'size': size,
                  'isDir': false,
                });
              }
            }
          } catch (_) {}
        }
      }

      // 2. Initialize progress tracking variables
      int bytesProcessed = 0;
      final stopwatch = Stopwatch()..start();
      final totalFiles = itemsToProcess.length;

      progressNotifier.value = FileOperationProgress(
        totalFiles: totalFiles,
        currentFileIndex: 1,
        currentFileName: 'Starting...',
        percentage: 0.0,
        speedMBs: 0.0,
        eta: Duration.zero,
        totalBytes: totalBytes > 0 ? totalBytes : 1,
        bytesProcessed: 0,
      );

      ConflictResult? cachedResolution;
      final Set<String> skippedPaths = {};
      final List<String> finalTopLevelDestPaths = [];

      // 3. Process items sequentially
      for (int i = 0; i < itemsToProcess.length; i++) {
        if (_isOperationCancelled) {
          throw Exception('Cancelled');
        }

        final item = itemsToProcess[i];
        final source = item['source'];
        String destPath = item['destPath'];
        final int size = item['size'];
        final bool isDir = item['isDir'];

        final fileName = p.basename(source.path);

        // Check if this item is within a skipped directory tree
        bool isSkipped = false;
        for (final skipped in skippedPaths) {
          if (p.isWithin(skipped, destPath) || destPath == skipped) {
            isSkipped = true;
            break;
          }
        }

        if (isSkipped) {
          if (!isDir) {
            totalBytes -= size;
          }
          continue;
        }

        String finalDestPath = destPath;
        bool shouldProcess = true;

        // Check if there is a conflict
        final destExists = FileSystemEntity.typeSync(destPath) != FileSystemEntityType.notFound;
        if (destExists) {
          ConflictDialogResponse? response;
          ConflictResult? resolution = cachedResolution;

          if (resolution == null) {
            if (context.mounted) {
              response = await ConflictDialog.show(
                context,
                fileName: fileName,
                sourceFile: File(source.path),
                destFile: File(destPath),
              );

              if (response != null) {
                resolution = response.result;
                if (response.applyToAll &&
                    (resolution == ConflictResult.overwrite ||
                     resolution == ConflictResult.keepBoth ||
                     resolution == ConflictResult.skip)) {
                  cachedResolution = resolution;
                }
              } else {
                resolution = ConflictResult.cancel;
              }
            } else {
              resolution = ConflictResult.cancel;
            }
          }

          if (resolution == ConflictResult.cancel) {
            throw Exception('Cancelled');
          } else if (resolution == ConflictResult.skip) {
            shouldProcess = false;
            skippedPaths.add(destPath);
          } else if (resolution == ConflictResult.keepBoth) {
            finalDestPath = _getUniquePath(destPath, isDir);
            if (isDir) {
              _updateSubsequentDestPaths(itemsToProcess, i + 1, destPath, finalDestPath);
            }
          } else if (resolution == ConflictResult.rename) {
            final customName = response?.customName ?? fileName;
            finalDestPath = p.join(p.dirname(destPath), customName);
            finalDestPath = _getUniquePath(finalDestPath, isDir);
            if (isDir) {
              _updateSubsequentDestPaths(itemsToProcess, i + 1, destPath, finalDestPath);
            }
          } else if (resolution == ConflictResult.overwrite) {
            // Overwrite: we do nothing to the path. If it's a file, it will overwrite it.
            // If it's a folder, it will merge it.
          }
        }

        if (!shouldProcess) {
          if (!isDir) {
            totalBytes -= size;
          }
          continue;
        }

        final isTopLevel = _clipboardPaths.contains(source.path);
        if (isTopLevel) {
          finalTopLevelDestPaths.add(finalDestPath);
        }

        double basePercent = totalBytes > 0 ? (bytesProcessed / totalBytes) : (i / totalFiles);
        progressNotifier.value = FileOperationProgress(
          totalFiles: totalFiles,
          currentFileIndex: i + 1,
          currentFileName: fileName,
          percentage: basePercent,
          speedMBs: stopwatch.elapsedMilliseconds > 0 
              ? (bytesProcessed / (1024 * 1024)) / (stopwatch.elapsed.inMilliseconds / 1000.0)
              : 0.0,
          eta: Duration.zero,
          totalBytes: totalBytes > 0 ? totalBytes : 1,
          bytesProcessed: bytesProcessed,
        );

        if (isDir) {
          final destDir = Directory(finalDestPath);
          if (!destDir.existsSync()) {
            await destDir.create(recursive: true);
          }
        } else {
          final parentDir = Directory(p.dirname(finalDestPath));
          if (!parentDir.existsSync()) {
            await parentDir.create(recursive: true);
          }

          final srcFile = source as File;
          final destFile = File(finalDestPath);

          if (_isCut) {
            try {
              if (destFile.existsSync()) {
                await destFile.delete();
              }
              await srcFile.rename(finalDestPath);
              bytesProcessed += size;
            } catch (_) {
              await _copyFileWithProgress(
                srcFile,
                destFile,
                onChunkCopied: (chunkSize) {
                  bytesProcessed += chunkSize;
                  final elapsedSeconds = stopwatch.elapsed.inMilliseconds / 1000.0;
                  final speed = elapsedSeconds > 0 ? (bytesProcessed / (1024 * 1024)) / elapsedSeconds : 0.0;
                  final remainingBytes = totalBytes - bytesProcessed;
                  final etaSeconds = speed > 0 ? (remainingBytes / (1024 * 1024)) / speed : 0.0;

                  progressNotifier.value = FileOperationProgress(
                    totalFiles: totalFiles,
                    currentFileIndex: i + 1,
                    currentFileName: fileName,
                    percentage: totalBytes > 0 ? (bytesProcessed / totalBytes) : (i / totalFiles),
                    speedMBs: speed,
                    eta: Duration(seconds: etaSeconds.round()),
                    totalBytes: totalBytes > 0 ? totalBytes : 1,
                    bytesProcessed: bytesProcessed,
                  );
                },
              );
              await srcFile.delete();
            }
          } else {
            await _copyFileWithProgress(
              srcFile,
              destFile,
              onChunkCopied: (chunkSize) {
                bytesProcessed += chunkSize;
                final elapsedSeconds = stopwatch.elapsed.inMilliseconds / 1000.0;
                final speed = elapsedSeconds > 0 ? (bytesProcessed / (1024 * 1024)) / elapsedSeconds : 0.0;
                final remainingBytes = totalBytes - bytesProcessed;
                final etaSeconds = speed > 0 ? (remainingBytes / (1024 * 1024)) / speed : 0.0;

                progressNotifier.value = FileOperationProgress(
                  totalFiles: totalFiles,
                  currentFileIndex: i + 1,
                  currentFileName: fileName,
                  percentage: totalBytes > 0 ? (bytesProcessed / totalBytes) : (i / totalFiles),
                  speedMBs: speed,
                  eta: Duration(seconds: etaSeconds.round()),
                  totalBytes: totalBytes > 0 ? totalBytes : 1,
                  bytesProcessed: bytesProcessed,
                );
              },
            );
          }
        }
      }

      if (_isCut) {
        for (final srcPath in _clipboardPaths) {
          final type = FileSystemEntity.typeSync(srcPath);
          if (type == FileSystemEntityType.directory) {
            final dir = Directory(srcPath);
            if (dir.existsSync()) {
              await dir.delete(recursive: true);
            }
          }
        }
      }

      if (_isCut && _sourceArchiveForCut != null && _internalSourcePathsForCut != null) {
        await ArchiveService.deleteItemsFromArchive(
          archivePath: _sourceArchiveForCut!,
          internalPathsToDelete: _internalSourcePathsForCut!,
        );
      }
      
      if (clearAfterPaste) {
        clearClipboard();
      }
      
      _highlightedPaths.clear();
      _highlightedPaths.addAll(finalTopLevelDestPaths);
      _shouldScrollToHighlight = true;

      Timer(const Duration(milliseconds: 2000), () {
        bool changed = false;
        for (final path in finalTopLevelDestPaths) {
          if (_highlightedPaths.remove(path)) {
            changed = true;
          }
        }
        if (changed) {
          notifyListeners();
        }
      });

    } catch (e) {
      debugPrint('Error pasting file: $e');
    } finally {
      progressNotifier.value = null;
      activeTab.isLoading = false;
      await loadDirectory(currentPath, showLoading: false);
      notifyListeners();
    }
  }

  String _getUniquePath(String destPath, bool isDir) {
    if (isDir) {
      if (!Directory(destPath).existsSync()) return destPath;
      int counter = 1;
      String parent = p.dirname(destPath);
      String base = p.basename(destPath);
      while (true) {
        final candidate = p.join(parent, '$base ($counter)');
        if (!Directory(candidate).existsSync()) {
          return candidate;
        }
        counter++;
      }
    } else {
      if (!File(destPath).existsSync()) return destPath;
      int counter = 1;
      String parent = p.dirname(destPath);
      String ext = p.extension(destPath);
      String base = p.basenameWithoutExtension(destPath);
      while (true) {
        final candidate = p.join(parent, '$base ($counter)$ext');
        if (!File(candidate).existsSync()) {
          return candidate;
        }
        counter++;
      }
    }
  }

  void _updateSubsequentDestPaths(List<Map<String, dynamic>> items, int startIndex, String oldParentPath, String newParentPath) {
    for (int j = startIndex; j < items.length; j++) {
      final subDest = items[j]['destPath'] as String;
      if (p.isWithin(oldParentPath, subDest) || subDest == oldParentPath) {
        final relativePart = p.relative(subDest, from: oldParentPath);
        items[j]['destPath'] = p.join(newParentPath, relativePart);
      }
    }
  }

  Future<void> _copyFileWithProgress(
    File source,
    File destination, {
    required Function(int chunkSize) onChunkCopied,
  }) async {
    final reader = source.openRead();
    final writer = destination.openWrite();

    try {
      await for (final chunk in reader) {
        if (_isOperationCancelled) {
          await writer.close();
          if (await destination.exists()) {
            await destination.delete();
          }
          throw Exception('Cancelled');
        }
        writer.add(chunk);
        onChunkCopied(chunk.length);
      }
    } finally {
      await writer.close();
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      if (isRestrictedPath(path)) {
        await RootShizukuService.deleteItem(path, useRoot: useRootMode);
      } else {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      }
      await loadDirectory(currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Future<void> renameFile(String oldPath, String newName) async {
    try {
      if (isRestrictedPath(oldPath)) {
        await RootShizukuService.renameItem(oldPath, newName, useRoot: useRootMode);
      } else {
        final newPath = p.join(p.dirname(oldPath), newName);
        final type = FileSystemEntity.typeSync(oldPath);
        if (type == FileSystemEntityType.directory) {
          await Directory(oldPath).rename(newPath);
        } else {
          await File(oldPath).rename(newPath);
        }
      }
      await loadDirectory(currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
  }

  Future<String?> createFolder(String name) async {
    try {
      String finalName = name;
      final targetPath = p.join(currentPath, name);
      if (FileSystemEntity.typeSync(targetPath) != FileSystemEntityType.notFound) {
        final uniquePath = _getUniquePath(targetPath, true);
        finalName = p.basename(uniquePath);
      }
      if (isRestrictedPath(currentPath)) {
        await RootShizukuService.createFolder(currentPath, finalName, useRoot: useRootMode);
      } else {
        final newPath = p.join(currentPath, finalName);
        await Directory(newPath).create();
      }
      await loadDirectory(currentPath, showLoading: false);
      return finalName;
    } catch (e) {
      debugPrint('Error creating folder: $e');
      return null;
    }
  }

  Future<String?> createFile(String name) async {
    try {
      String finalName = name;
      final targetPath = p.join(currentPath, name);
      if (FileSystemEntity.typeSync(targetPath) != FileSystemEntityType.notFound) {
        final uniquePath = _getUniquePath(targetPath, false);
        finalName = p.basename(uniquePath);
      }
      if (isRestrictedPath(currentPath)) {
        await RootShizukuService.createFile(currentPath, finalName, useRoot: useRootMode);
      } else {
        final newPath = p.join(currentPath, finalName);
        await File(newPath).create();
      }
      await loadDirectory(currentPath, showLoading: false);
      return finalName;
    } catch (e) {
      debugPrint('Error creating file: $e');
      return null;
    }
  }

  Future<void> createArchive({
    required String archiveName,
    required String format,
    required int compressionLevel,
    String? password,
    int? splitSizeMB,
    required bool deleteSource,
    required bool separateArchives,
    List<String>? targetPaths,
  }) async {
    final paths = targetPaths ?? (selectedPaths.isNotEmpty ? selectedPaths.toList() : [currentPath]);
    activeTab.isLoading = true;
    notifyListeners();

    try {
      await ArchiveService.createArchive(
        sourcePaths: paths,
        destinationDir: currentPath,
        archiveName: archiveName,
        format: format,
        compressionLevel: compressionLevel,
        password: password,
        splitSizeMB: splitSizeMB,
        deleteSource: deleteSource,
        separateArchives: separateArchives,
      );
    } catch (e) {
      debugPrint('Error creating archive: $e');
    }

    selectedPaths.clear();
    await loadDirectory(currentPath, showLoading: false);
  }

  Future<void> extractArchiveDirectly(BuildContext context, String path) async {
    final destDir = p.join(currentPath, p.basenameWithoutExtension(path));
    final res = await ExtractArchiveDialog.show(context, archiveName: p.basename(path), defaultDestDir: destDir);
    if (res != null && context.mounted) {
      activeTab.isLoading = true;
      notifyListeners();
      try {
        await ArchiveService.extractArchive(archivePath: path, destinationDir: res.destinationDir, password: res.password);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Archive extracted successfully')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extraction failed: $e')));
        }
      }
      await loadDirectory(currentPath, showLoading: false);
    }
  }

  bool hasNativeViewer(String path) {
    final mimeType = lookupMimeType(path) ?? '';
    final ext = p.extension(path).toLowerCase();
    const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];
    
    if (FileUtils.isArchive(path)) return true;
    if (mimeType.startsWith('image/')) return true;
    if (mimeType.startsWith('video/')) return true;
    if (mimeType.startsWith('audio/')) return true;
    if (FileUtils.isTextOrCode(path)) return true;
    if (const ['.db', '.sqlite', '.sqlite3', '.db3'].contains(ext)) return true;
    if (docExts.contains(ext)) return true;
    if (ApkInstallerService.isApk(path)) return true;
    return false;
  }

  Future<void> openFileNatively(BuildContext context, String path) async {
    final mimeType = lookupMimeType(path) ?? '';
    final ext = p.extension(path).toLowerCase();
    const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];

    if (FileUtils.isArchive(path)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArchiveViewerScreen(archivePath: path),
        ),
      );
      return;
    }

    if (mimeType.startsWith('image/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imagePath: path)));
    } else if (mimeType.startsWith('video/')) {
      final folderVideoFiles = activeTab.currentFiles
          .where((f) => !f.isDirectory && (lookupMimeType(f.path)?.startsWith('video/') == true || FileUtils.isVideo(f.path)))
          .map((f) => f.path)
          .toList();
      int initialIndex = folderVideoFiles.indexOf(path);
      if (initialIndex == -1) initialIndex = 0;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            videoPath: path,
            playlist: folderVideoFiles.isNotEmpty ? folderVideoFiles : [path],
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (mimeType.startsWith('audio/')) {
      final folderAudioFiles = activeTab.currentFiles
          .where((f) => !f.isDirectory && (lookupMimeType(f.path)?.startsWith('audio/') == true))
          .toList();
      
      List<SongModel>? allSongs;
      int initialIndex = 0;

      if (folderAudioFiles.isNotEmpty && folderAudioFiles.any((f) => f.path == path)) {
        allSongs = [];
        for (int i = 0; i < folderAudioFiles.length; i++) {
          final file = folderAudioFiles[i];
          final songMap = {
            '_id': i,
            '_data': file.path,
            'title': p.basenameWithoutExtension(file.path),
            'artist': 'Unknown Artist',
            'album': 'Local Folder',
            'duration': 0,
            'size': file.size,
            'display_name': p.basename(file.path),
            'display_name_wo_ext': p.basenameWithoutExtension(file.path),
            'is_music': true,
          };
          allSongs.add(SongModel(songMap));
          if (file.path == path) {
            initialIndex = i;
          }
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioPlayerScreen(
            audioPath: path,
            title: p.basename(path),
            allSongs: allSongs,
            initialIndex: initialIndex,
          ),
        ),
      );
    } else if (FileUtils.isTextOrCode(path)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditorScreen(filePath: path)));
    } else if (const ['.db', '.sqlite', '.sqlite3', '.db3'].contains(ext)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DatabaseReaderScreen(filePath: path)));
    } else if (docExts.contains(ext)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(filePath: path)));
    } else if (ApkInstallerService.isApk(path)) {
      await ApkInstallerService.installApk(context, path);
    } else {
      await OpenFilex.open(path);
    }
  }

  Future<void> openFile(BuildContext context, String path, {bool showOpenWithPopup = false}) async {
    _highlightedPaths.clear();
    _highlightedPaths.add(path);
    notifyListeners();
    Timer(const Duration(milliseconds: 2000), () {
      if (_highlightedPaths.remove(path)) {
        notifyListeners();
      }
    });

    final ext = p.extension(path).toLowerCase();

    // Universal default action check
    if (hasNativeViewer(path)) {
      final defaultAction = PreferencesService.getDefaultOpenAction(ext);
      if (defaultAction == 'native') {
        await openFileNatively(context, path);
        return;
      } else if (defaultAction == 'external') {
        await OpenFilex.open(path);
        return;
      }
    }

    if (showOpenWithPopup && !_skipOpenWithDialog && hasNativeViewer(path)) {
      if (!context.mounted) return;
      
      final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => OpenWithSheet(
          fileName: p.basename(path),
          fileExtension: ext,
        ),
      );

      if (result == null) return;

      if (result.startsWith('always_')) {
        final selectedType = result.substring('always_'.length);
        await PreferencesService.saveDefaultOpenAction(ext, selectedType);
        if (selectedType == 'native') {
          await openFileNatively(context, path);
        } else {
          await OpenFilex.open(path);
        }
      } else if (result.startsWith('just_once_')) {
        final selectedType = result.substring('just_once_'.length);
        if (selectedType == 'native') {
          await openFileNatively(context, path);
        } else {
          await OpenFilex.open(path);
        }
      }
      return;
    }

    await openFileNatively(context, path);
  }

  Future<void> moveItem(BuildContext context, String sourcePath, String destFolderPath) async {
    final name = p.basename(sourcePath);
    final destPath = p.join(destFolderPath, name);

    if (sourcePath == destPath || destFolderPath.startsWith(sourcePath + p.separator)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot move a folder inside itself or same location')),
      );
      return;
    }

    activeTab.isLoading = true;
    notifyListeners();

    try {
      final isDir = FileSystemEntity.isDirectorySync(sourcePath);
      if (isRestrictedPath(sourcePath) || isRestrictedPath(destFolderPath)) {
        await RootShizukuService.moveItem(sourcePath, destPath, useRoot: activeTab.useRootMode);
      } else {
        if (isDir) {
          final sourceDir = Directory(sourcePath);
          final destDir = Directory(destPath);
          if (!destDir.existsSync()) {
            await destDir.create(recursive: true);
          }
          try {
            await sourceDir.rename(destPath);
          } catch (e) {
            await _copyDirectory(sourceDir, destDir);
            await sourceDir.delete(recursive: true);
          }
        } else {
          final sourceFile = File(sourcePath);
          final destFile = File(destPath);
          try {
            if (destFile.existsSync()) {
              await destFile.delete();
            }
            await sourceFile.rename(destPath);
          } catch (e) {
            await sourceFile.copy(destPath);
            await sourceFile.delete();
          }
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved $name successfully')),
      );
    } catch (e) {
      debugPrint('Error moving item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move item: $e')),
      );
    }

    await loadDirectory(currentPath, showLoading: false);
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        final newDirectory = Directory(p.join(destination.absolute.path, p.basename(entity.path)));
        await newDirectory.create();
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }
}

class FileOperationProgress {
  final int totalFiles;
  final int currentFileIndex;
  final String currentFileName;
  final double percentage; // 0.0 to 1.0
  final double speedMBs; // MB/s
  final Duration eta;
  final int totalBytes;
  final int bytesProcessed;

  FileOperationProgress({
    required this.totalFiles,
    required this.currentFileIndex,
    required this.currentFileName,
    required this.percentage,
    required this.speedMBs,
    required this.eta,
    required this.totalBytes,
    required this.bytesProcessed,
  });
}
