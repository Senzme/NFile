import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item_model.dart';
import '../models/folder_tab_model.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import '../ui/screens/image_viewer_screen.dart';
import '../ui/screens/video_player/video_player_screen.dart';
import '../ui/screens/audio_player/audio_player_screen.dart';
import '../ui/screens/text_editor_screen.dart';
import '../ui/screens/document_viewer_screen.dart';
import '../ui/screens/archive_viewer_screen.dart';
import '../services/archive_service.dart';
import '../services/apk_installer_service.dart';
import '../ui/widgets/extract_archive_dialog.dart';
import '../core/utils.dart';
import '../services/preferences_service.dart';
import '../models/custom_shortcut_model.dart';
import '../services/root_shizuku_service.dart';

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
    _accentColorOption = PreferencesService.getAccentColor();
    _folderIconOption = PreferencesService.getFolderIconStyle();
    _pinnedFolderShortcuts = PreferencesService.getPinnedFolderShortcuts();
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

  void setSortType(FileSortType type) {
    if (_sortType == type) return;
    _sortType = type;
    PreferencesService.saveSortType(_sortType);
    if (_tabs.isNotEmpty) {
      final folders = currentFiles.where((e) => e.isDirectory).toList();
      final files = currentFiles.where((e) => !e.isDirectory).toList();
      _sortList(folders);
      _sortList(files);
      activeTab.currentFiles = [...folders, ...files];
    }
    notifyListeners();
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

  void _sortList(List<FileItemModel> items) {
    switch (_sortType) {
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

  bool _showMediaPreviews = true;
  bool get showMediaPreviews => _showMediaPreviews;

  void toggleMediaPreviews() {
    _showMediaPreviews = !_showMediaPreviews;
    PreferencesService.saveShowMediaPreviews(_showMediaPreviews);
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
    _activeTabIndex = 0;

    await _detectStorageVolumes();
    await loadDirectory(initialPath, showLoading: false);
  }

  bool isRestrictedPath(String path) {
    final lower = path.toLowerCase();
    return lower.contains('/android/data') || lower.contains('/android/obb');
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

        _sortList(folders);
        _sortList(files);
        activeTab.currentFiles = [...folders, ...files];
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

        for (var entity in entities) {
          final item = FileItemModel.fromEntity(entity);
          if (!_showHiddenFiles && item.isHidden) {
            continue;
          }
          if (item.isDirectory) {
            folders.add(item);
          } else {
            files.add(item);
          }
        }

        _sortList(folders);
        _sortList(files);

        activeTab.currentFiles = [...folders, ...files];
      }
    } catch (e) {
      debugPrint('Error loading directory: $e');
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

  Future<void> pasteFile({bool clearAfterPaste = true}) async {
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

      // 3. Process items sequentially
      for (int i = 0; i < itemsToProcess.length; i++) {
        if (_isOperationCancelled) {
          throw Exception('Cancelled');
        }

        final item = itemsToProcess[i];
        final source = item['source'];
        final String destPath = item['destPath'];
        final int size = item['size'];
        final bool isDir = item['isDir'];

        final fileName = p.basename(source.path);
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
          final destDir = Directory(destPath);
          if (!destDir.existsSync()) {
            await destDir.create(recursive: true);
          }
        } else {
          final parentDir = Directory(p.dirname(destPath));
          if (!parentDir.existsSync()) {
            await parentDir.create(recursive: true);
          }

          final srcFile = source as File;
          final destFile = File(destPath);

          if (_isCut) {
            try {
              await srcFile.rename(destPath);
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

      final pastedPaths = _clipboardPaths.map((srcPath) {
        final fileName = p.basename(srcPath);
        return p.join(currentPath, fileName);
      }).toList();

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
      _highlightedPaths.addAll(pastedPaths);
      _shouldScrollToHighlight = true;

      Timer(const Duration(milliseconds: 2000), () {
        bool changed = false;
        for (final path in pastedPaths) {
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

  Future<void> createFolder(String name) async {
    try {
      if (isRestrictedPath(currentPath)) {
        await RootShizukuService.createFolder(currentPath, name, useRoot: useRootMode);
      } else {
        final newPath = p.join(currentPath, name);
        await Directory(newPath).create();
      }
      await loadDirectory(currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error creating folder: $e');
    }
  }

  Future<void> createFile(String name) async {
    try {
      if (isRestrictedPath(currentPath)) {
        await RootShizukuService.createFile(currentPath, name, useRoot: useRootMode);
      } else {
        final newPath = p.join(currentPath, name);
        await File(newPath).create();
      }
      await loadDirectory(currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error creating file: $e');
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

  Future<void> openFile(BuildContext context, String path) async {
    _highlightedPaths.clear();
    _highlightedPaths.add(path);
    notifyListeners();
    Timer(const Duration(milliseconds: 2000), () {
      if (_highlightedPaths.remove(path)) {
        notifyListeners();
      }
    });

    if (FileUtils.isArchive(path)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArchiveViewerScreen(archivePath: path),
        ),
      );
      return;
    }

    final mimeType = lookupMimeType(path) ?? '';
    final ext = p.extension(path).toLowerCase();
    const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];
    if (mimeType.startsWith('image/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imagePath: path)));
    } else if (mimeType.startsWith('video/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoPath: path)));
    } else if (mimeType.startsWith('audio/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AudioPlayerScreen(audioPath: path, title: p.basename(path))));
    } else if (FileUtils.isTextOrCode(path)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditorScreen(filePath: path)));
    } else if (docExts.contains(ext)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(filePath: path)));
    } else if (ApkInstallerService.isApk(path)) {
      await ApkInstallerService.installApk(context, path);
    } else {
      await OpenFilex.open(path);
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
