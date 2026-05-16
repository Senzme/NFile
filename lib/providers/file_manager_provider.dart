import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item_model.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import '../ui/screens/image_viewer_screen.dart';
import '../ui/screens/video_player_screen.dart';
import '../ui/screens/audio_player_screen.dart';
import '../ui/screens/text_editor_screen.dart';
import '../ui/screens/document_viewer_screen.dart';

class FileManagerProvider extends ChangeNotifier {
  List<FileItemModel> _currentFiles = [];
  List<FileItemModel> get currentFiles => _currentFiles;

  String _currentPath = '';
  String get currentPath => _currentPath;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _clipboardPath;
  bool _isCut = false;
  
  bool get hasClipboard => _clipboardPath != null;

  Future<void> init() async {
    // Start at external storage root if available, otherwise app doc dir
    if (Platform.isAndroid) {
      _currentPath = '/storage/emulated/0';
      if (!Directory(_currentPath).existsSync()) {
        final dir = await getExternalStorageDirectory();
        _currentPath = dir?.path ?? '/';
      }
    } else {
      final dir = await getApplicationDocumentsDirectory();
      _currentPath = dir.path;
    }
    await loadDirectory(_currentPath);
  }

  Future<void> loadDirectory(String path) async {
    _isLoading = true;
    _currentPath = path;
    notifyListeners();

    try {
      final dir = Directory(path);
      final entities = dir.listSync();
      _currentFiles = entities.map((e) => FileItemModel.fromEntity(e)).toList();
      
      // Sort: Directories first, then alphabetically
      _currentFiles.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } catch (e) {
      debugPrint('Error loading directory: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> goBack() async {
    final parent = Directory(_currentPath).parent.path;
    if (parent != _currentPath) {
      await loadDirectory(parent);
    }
  }

  void copyFile(String path) {
    _clipboardPath = path;
    _isCut = false;
    notifyListeners();
  }

  void cutFile(String path) {
    _clipboardPath = path;
    _isCut = true;
    notifyListeners();
  }

  Future<void> pasteFile() async {
    if (_clipboardPath == null) return;
    
    final sourceEntity = FileSystemEntity.typeSync(_clipboardPath!) == FileSystemEntityType.directory
        ? Directory(_clipboardPath!)
        : File(_clipboardPath!);
        
    final fileName = p.basename(_clipboardPath!);
    final destinationPath = p.join(_currentPath, fileName);

    try {
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
          await _copyDirectory(Directory(_clipboardPath!), Directory(destinationPath));
        }
      }
      
      if (_isCut) {
        _clipboardPath = null;
        _isCut = false;
      }
      
      await loadDirectory(_currentPath);
    } catch (e) {
      debugPrint('Error pasting file: $e');
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
      await loadDirectory(_currentPath);
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
      await loadDirectory(_currentPath);
    } catch (e) {
      debugPrint('Error renaming file: $e');
    }
  }

  Future<void> createFolder(String name) async {
    try {
      final newPath = p.join(_currentPath, name);
      await Directory(newPath).create();
      await loadDirectory(_currentPath);
    } catch (e) {
      debugPrint('Error creating folder: $e');
    }
  }

  Future<void> createFile(String name) async {
    try {
      final newPath = p.join(_currentPath, name);
      await File(newPath).create();
      await loadDirectory(_currentPath);
    } catch (e) {
      debugPrint('Error creating file: $e');
    }
  }

  Future<void> openFile(BuildContext context, String path) async {
    final mimeType = lookupMimeType(path) ?? '';
    final ext = p.extension(path).toLowerCase();
    const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.epub', '.odt'];
    if (mimeType.startsWith('image/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imagePath: path)));
    } else if (mimeType.startsWith('video/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoPath: path)));
    } else if (mimeType.startsWith('audio/')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AudioPlayerScreen(audioPath: path, title: p.basename(path))));
    } else if (mimeType.startsWith('text/') || path.endsWith('.md') || path.endsWith('.json') || path.endsWith('.xml')) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditorScreen(filePath: path)));
    } else if (docExts.contains(ext)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DocumentViewerScreen(filePath: path)));
    } else {
      await OpenFilex.open(path);
    }
  }
}
