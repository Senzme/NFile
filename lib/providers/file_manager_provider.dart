import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item_model.dart';
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
    _showHiddenFiles = PreferencesService.getShowHiddenFiles();
    _showFloatingAddButton = PreferencesService.getShowFloatingAddButton();
    _defaultToBrowseScreen = PreferencesService.getDefaultToBrowseScreen();
    _showFolderFileCount = PreferencesService.getShowFolderFileCount();
    _accentColorOption = PreferencesService.getAccentColor();
    _folderIconOption = PreferencesService.getFolderIconStyle();
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
    final folders = _currentFiles.where((e) => e.isDirectory).toList();
    final files = _currentFiles.where((e) => !e.isDirectory).toList();
    _sortList(folders);
    _sortList(files);
    _currentFiles = [...folders, ...files];
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
    if (_currentPath.isNotEmpty) {
      loadDirectory(_currentPath, showLoading: false);
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

  List<FileItemModel> _currentFiles = [];
  List<FileItemModel> get currentFiles => _currentFiles;

  String _currentPath = '';
  String get currentPath => _currentPath;
  bool _isLoading = false;
  bool get isLoading => _isLoading;

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

  final Set<String> _selectedPaths = {};
  Set<String> get selectedPaths => _selectedPaths;
  bool get isSelectionMode => _selectedPaths.isNotEmpty;

  String _rootPath = '';
  String get rootPath => _rootPath;

  final Map<String, double> _scrollOffsets = {};

  bool get canGoBack {
    if (_currentPath.isEmpty || _rootPath.isEmpty) return false;
    if (_currentPath == _rootPath || _currentPath == '/' || p.dirname(_currentPath) == _currentPath) {
      return false;
    }
    return true;
  }

  void saveScrollOffset(double offset) {
    if (_currentPath.isNotEmpty) {
      _scrollOffsets[_currentPath] = offset;
    }
  }

  double getSavedScrollOffset(String path) {
    return _scrollOffsets[path] ?? 0.0;
  }

  List<StorageVolume> _storageVolumes = [];
  List<StorageVolume> get storageVolumes => _storageVolumes;

  void setRootPath(String path) {
    _rootPath = path;
    _currentPath = path;
    notifyListeners();
  }

  Future<void> _detectStorageVolumes() async {
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
    if (Platform.isAndroid) {
      _currentPath = '/storage/emulated/0';
      if (!Directory(_currentPath).existsSync()) {
        final dir = await getExternalStorageDirectory();
        _currentPath = dir?.path ?? '/';
      }
      _rootPath = _currentPath;
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _currentPath = dir.path;
      _rootPath = _currentPath;
    }
    await _detectStorageVolumes();
    await loadDirectory(_currentPath, showLoading: false);
  }

  Future<void> loadDirectory(String path, {bool showLoading = true}) async {
    if (_storageVolumes.isEmpty) {
      _detectStorageVolumes();
    }

    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        _currentPath = path;
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

        _currentFiles = [...folders, ...files];
      }
    } catch (e) {
      debugPrint('Error loading directory: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> goBack() async {
    if (!canGoBack) return false;
    final parent = p.dirname(_currentPath);
    await loadDirectory(parent, showLoading: false);
    return true;
  }

  void toggleSelection(String path) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedPaths.clear();
    _selectedPaths.addAll(_currentFiles.map((f) => f.path));
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  void copyFile(String path) {
    setClipboard([path], isCut: false);
  }

  void cutFile(String path) {
    setClipboard([path], isCut: true);
  }

  void copySelected() {
    if (_selectedPaths.isEmpty) return;
    setClipboard(_selectedPaths.toList(), isCut: false);
    _selectedPaths.clear();
    notifyListeners();
  }

  void cutSelected() {
    if (_selectedPaths.isEmpty) return;
    setClipboard(_selectedPaths.toList(), isCut: true);
    _selectedPaths.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedPaths.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      for (final path in _selectedPaths) {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting selected files: $e');
    }

    _selectedPaths.clear();
    _isLoading = false;
    await loadDirectory(_currentPath, showLoading: false);
  }

  Future<void> pasteFile() async {
    if (_clipboardPaths.isEmpty) return;

    try {
      for (final srcPath in _clipboardPaths) {
        final sourceEntity = FileSystemEntity.typeSync(srcPath) == FileSystemEntityType.directory
            ? Directory(srcPath)
            : File(srcPath);
            
        final fileName = p.basename(srcPath);
        final destinationPath = p.join(_currentPath, fileName);

        if (sourceEntity is File) {
          if (_isCut) {
            await sourceEntity.rename(destinationPath);
          } else {
            await sourceEntity.copy(destinationPath);
          }
        } else if (sourceEntity is Directory) {
          if (_isCut) {
            await sourceEntity.rename(destinationPath);
          } else {
            await _copyDirectory(Directory(srcPath), Directory(destinationPath));
          }
        }
      }

      if (_isCut && _sourceArchiveForCut != null && _internalSourcePathsForCut != null) {
        await ArchiveService.deleteItemsFromArchive(
          archivePath: _sourceArchiveForCut!,
          internalPathsToDelete: _internalSourcePathsForCut!,
        );
      }
      
      clearClipboard();
      await loadDirectory(_currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error pasting file: $e');
      clearClipboard();
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (var entity in source.list(recursive: false)) {
      if (entity is Directory) {
        var newDirectory = Directory(p.join(destination.absolute.path, p.basename(entity.path)));
        await newDirectory.create();
        await _copyDirectory(entity.absolute, newDirectory);
      } else if (entity is File) {
        await entity.copy(p.join(destination.path, p.basename(entity.path)));
      }
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else {
        await File(path).delete();
      }
      await loadDirectory(_currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Future<void> renameFile(String oldPath, String newName) async {
    try {
      final newPath = p.join(p.dirname(oldPath), newName);
      final type = FileSystemEntity.typeSync(oldPath);
      if (type == FileSystemEntityType.directory) {
        await Directory(oldPath).rename(newPath);
      } else {
        await File(oldPath).rename(newPath);
      }
      await loadDirectory(_currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
  }

  Future<void> createFolder(String name) async {
    try {
      final newPath = p.join(_currentPath, name);
      await Directory(newPath).create();
      await loadDirectory(_currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error creating folder: $e');
    }
  }

  Future<void> createFile(String name) async {
    try {
      final newPath = p.join(_currentPath, name);
      await File(newPath).create();
      await loadDirectory(_currentPath, showLoading: false);
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
    final paths = targetPaths ?? (_selectedPaths.isNotEmpty ? _selectedPaths.toList() : [_currentPath]);
    _isLoading = true;
    notifyListeners();

    try {
      await ArchiveService.createArchive(
        sourcePaths: paths,
        destinationDir: _currentPath,
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

    _selectedPaths.clear();
    await loadDirectory(_currentPath, showLoading: false);
  }

  Future<void> extractArchiveDirectly(BuildContext context, String path) async {
    final destDir = p.join(_currentPath, p.basenameWithoutExtension(path));
    final res = await ExtractArchiveDialog.show(context, archiveName: p.basename(path), defaultDestDir: destDir);
    if (res != null && context.mounted) {
      _isLoading = true;
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
      await loadDirectory(_currentPath, showLoading: false);
    }
  }

  Future<void> openFile(BuildContext context, String path) async {
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
