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
import '../ui/widgets/extract_archive_dialog.dart';
import '../core/utils.dart';

class FileManagerProvider extends ChangeNotifier {
  List<FileItemModel> _currentFiles = [];
  List<FileItemModel> get currentFiles => _currentFiles;

  String _currentPath = '';
  String get currentPath => _currentPath;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  final List<String> _clipboardPaths = [];
  bool _isCut = false;
  bool get hasClipboard => _clipboardPaths.isNotEmpty;
  List<String> get clipboardPaths => _clipboardPaths;
  bool get isCut => _isCut;

  void clearClipboard() {
    _clipboardPaths.clear();
    _isCut = false;
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
    await loadDirectory(_currentPath);
  }

  Future<void> loadDirectory(String path, {bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _currentPath = path;
    _selectedPaths.clear();

    try {
      final dir = Directory(path);
      final entities = dir.listSync();
      _currentFiles = entities.map((e) => FileItemModel.fromEntity(e)).toList();
      
      _currentFiles.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } catch (e) {
      debugPrint('Error loading directory: $e');
    }

    if (showLoading) {
      _isLoading = false;
    }
    notifyListeners();
  }

  Future<bool> goBack() async {
    if (isSelectionMode) {
      clearSelection();
      return true;
    }
    if (canGoBack) {
      final parent = Directory(_currentPath).parent.path;
      if (parent != _currentPath) {
        await loadDirectory(parent);
        return true;
      }
    }
    return false;
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
    _selectedPaths.addAll(_currentFiles.map((e) => e.path));
    notifyListeners();
  }

  void clearSelection() {
    _selectedPaths.clear();
    notifyListeners();
  }

  void copyFile(String path) {
    _clipboardPaths.clear();
    _clipboardPaths.add(path);
    _isCut = false;
    notifyListeners();
  }

  void cutFile(String path) {
    _clipboardPaths.clear();
    _clipboardPaths.add(path);
    _isCut = true;
    notifyListeners();
  }

  void copySelected() {
    if (_selectedPaths.isEmpty) return;
    _clipboardPaths.clear();
    _clipboardPaths.addAll(_selectedPaths);
    _isCut = false;
    _selectedPaths.clear();
    notifyListeners();
  }

  void cutSelected() {
    if (_selectedPaths.isEmpty) return;
    _clipboardPaths.clear();
    _clipboardPaths.addAll(_selectedPaths);
    _isCut = true;
    _selectedPaths.clear();
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (_selectedPaths.isEmpty) return;

    try {
      for (final path in _selectedPaths) {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          await Directory(path).delete(recursive: true);
        } else if (type == FileSystemEntityType.file) {
          await File(path).delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting selected files: $e');
    }

    _selectedPaths.clear();
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
      
      _clipboardPaths.clear();
      _isCut = false;
      
      await loadDirectory(_currentPath, showLoading: false);
    } catch (e) {
      debugPrint('Error pasting file: $e');
      _clipboardPaths.clear();
      _isCut = false;
      notifyListeners();
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
    } else {
      await OpenFilex.open(path);
    }
  }
}
