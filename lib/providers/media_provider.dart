import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

enum MediaSortOrder {
  newest,
  oldest,
  dateWise,
}

class ThumbnailCache {
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _pending = {};
  static String? _cacheDir;

  static Future<void> init() async {
    if (_cacheDir != null) return;
    try {
      final dir = await getTemporaryDirectory();
      final folder = Directory('${dir.path}/nfile_thumbnails');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }
      _cacheDir = folder.path;
    } catch (_) {}
  }

  static Future<Uint8List?> get(AssetEntity asset) async {
    final key = asset.id;
    if (_cache.containsKey(key) && _cache[key] != null) return _cache[key];
    if (_pending.containsKey(key)) return _pending[key];

    final completer = Completer<Uint8List?>();
    _pending[key] = completer.future;

    try {
      await init();
      if (_cacheDir != null) {
        final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final file = File('$_cacheDir/$sanitizedKey.thumb');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            _cache[key] = bytes;
            _pending.remove(key);
            completer.complete(bytes);
            return bytes;
          }
        }
      }

      final data = await asset.thumbnailDataWithSize(const ThumbnailSize.square(300));
      if (data != null && data.isNotEmpty) {
        _cache[key] = data;
        if (_cacheDir != null) {
          final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          final file = File('$_cacheDir/$sanitizedKey.thumb');
          await file.writeAsBytes(data, flush: true);
        }
      }
      _pending.remove(key);
      completer.complete(data);
      return data;
    } catch (e) {
      _pending.remove(key);
      completer.complete(null);
      return null;
    }
  }

  static Uint8List? getCached(String id) => _cache[id];
  static bool hasCached(String id) => _cache.containsKey(id) && _cache[id] != null;

  static void clear() {
    _cache.clear();
    _pending.clear();
    if (_cacheDir != null) {
      try {
        Directory(_cacheDir!).deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

class MediaProvider extends ChangeNotifier {
  List<AssetEntity> _images = [];
  List<AssetEntity> _videos = [];
  List<SongModel> _audios = [];
  List<FileSystemEntity> _documents = [];
  List<FileSystemEntity> _archives = [];
  List<FileSystemEntity> _downloads = [];

  bool _isLoading = false;
  bool _isLoaded = false;
  MediaSortOrder _sortOrder = MediaSortOrder.newest;

  List<AssetEntity> get images => _images;
  List<AssetEntity> get videos => _videos;
  List<SongModel> get audios => _audios;
  List<FileSystemEntity> get documents => _documents;
  List<FileSystemEntity> get archives => _archives;
  List<FileSystemEntity> get downloads => _downloads;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  MediaSortOrder get sortOrder => _sortOrder;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<void> _loadFromDiskCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheFile = File('${dir.path}/media_meta_cache.json');
      if (await cacheFile.exists()) {
        final jsonStr = await cacheFile.readAsString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (map.containsKey('documents')) {
          final docPaths = List<String>.from(map['documents'] ?? []);
          final cachedDocs = <FileSystemEntity>[];
          for (final p in docPaths) {
            final f = File(p);
            if (f.existsSync()) cachedDocs.add(f);
          }
          if (cachedDocs.isNotEmpty && _documents.isEmpty) {
            _documents = cachedDocs;
          }
        }

        if (map.containsKey('archives')) {
          final archPaths = List<String>.from(map['archives'] ?? []);
          final cachedArch = <FileSystemEntity>[];
          for (final p in archPaths) {
            final f = File(p);
            if (f.existsSync()) cachedArch.add(f);
          }
          if (cachedArch.isNotEmpty && _archives.isEmpty) {
            _archives = cachedArch;
          }
        }

        if (map.containsKey('downloads')) {
          final dlPaths = List<String>.from(map['downloads'] ?? []);
          final cachedDl = <FileSystemEntity>[];
          for (final p in dlPaths) {
            final f = File(p);
            if (f.existsSync()) cachedDl.add(f);
          }
          if (cachedDl.isNotEmpty && _downloads.isEmpty) {
            _downloads = cachedDl;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheFile = File('${dir.path}/media_meta_cache.json');
      final map = {
        'documents': _documents.map((e) => e.path).toList(),
        'archives': _archives.map((e) => e.path).toList(),
        'downloads': _downloads.map((e) => e.path).toList(),
      };
      await cacheFile.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
  }

  Future<void> loadMedia({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) return;

    _isLoading = true;
    notifyListeners();

    // Fast initial load from disk cache
    await _loadFromDiskCache();

    PermissionState ps = PermissionState.denied;
    try {
      ps = await PhotoManager.requestPermissionExtend();
    } catch (_) {}

    bool hasAudioPermission = false;
    try {
      hasAudioPermission = await _audioQuery.permissionsStatus();
      if (!hasAudioPermission) {
        hasAudioPermission = await _audioQuery.permissionsRequest();
      }
    } catch (_) {}

    final futures = <Future<void>>[];
    if (ps.isAuth) {
      futures.add(_loadImagesAndVideos());
    }
    if (hasAudioPermission) {
      futures.add(_loadAudios());
    }
    futures.add(_loadDocuments());
    futures.add(_loadArchivesAndDownloads());

    await Future.wait(futures);
    await _saveCache();

    _applySort();
    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _loadImagesAndVideos() async {
    try {
      List<AssetPathEntity> albums =
          await PhotoManager.getAssetPathList(onlyAll: true);
      if (albums.isNotEmpty) {
        List<AssetEntity> allMedia =
            await albums[0].getAssetListPaged(page: 0, size: 10000);
        _images = allMedia.where((e) => e.type == AssetType.image).toList();
        _videos = allMedia.where((e) => e.type == AssetType.video).toList();
      }
    } catch (_) {}
  }

  Future<void> _loadAudios() async {
    try {
      _audios = await _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
    } catch (_) {
      _audios = [];
    }
  }

  static const List<String> _docExtensions = [
    '.pdf',
    '.doc',
    '.docx',
    '.xls',
    '.xlsx',
    '.ppt',
    '.pptx',
    '.txt',
    '.csv',
    '.odt',
    '.ods',
    '.odp',
    '.rtf',
    '.epub',
  ];

  Future<void> _loadDocuments() async {
    final docs = <FileSystemEntity>[];

    final searchDirs = [
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
    ];

    for (final dirPath in searchDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              final ext = entity.path
                  .substring(entity.path.lastIndexOf('.'))
                  .toLowerCase();
              if (_docExtensions.contains(ext)) {
                docs.add(entity);
              }
            }
          }
        } catch (_) {}
      }
    }

    _documents = docs;
  }

  static const List<String> _archiveExtensions = ['.zip', '.tar', '.gz', '.bz2', '.rar', '.7z'];

  Future<void> _loadArchivesAndDownloads() async {
    final arch = <FileSystemEntity>[];
    final dl = <FileSystemEntity>[];

    // For downloads
    final dlDirs = ['/storage/emulated/0/Download', '/storage/emulated/0/Downloads'];
    for (final dirPath in dlDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: false)) {
            if (entity is File) {
              dl.add(entity);
            }
          }
        } catch (_) {}
      }
    }

    // For archives, scan standard user directories
    final searchDirs = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Telegram',
      '/storage/emulated/0/WhatsApp/Media',
    ];

    for (final dirPath in searchDirs) {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              final ext = entity.path.contains('.') ? entity.path.substring(entity.path.lastIndexOf('.')).toLowerCase() : '';
              if (_archiveExtensions.contains(ext)) {
                arch.add(entity);
              }
            }
          }
        } catch (_) {}
      }
    }

    _downloads = dl;
    _archives = arch;
  }

  void setSortOrder(MediaSortOrder order) {
    _sortOrder = order;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    if (_sortOrder == MediaSortOrder.newest ||
        _sortOrder == MediaSortOrder.dateWise) {
        _images.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        _videos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
        _audios.sort(
            (a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    } else if (_sortOrder == MediaSortOrder.oldest) {
        _images.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        _videos.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
        _audios.sort(
            (a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
    }

    int fileSort(FileSystemEntity a, FileSystemEntity b) {
      try {
        final aTime = (a as File).lastModifiedSync();
        final bTime = (b as File).lastModifiedSync();
        return _sortOrder == MediaSortOrder.oldest
            ? aTime.compareTo(bTime)
            : bTime.compareTo(aTime);
      } catch (_) {
        return 0;
      }
    }

    _documents.sort(fileSort);
    _archives.sort(fileSort);
    _downloads.sort(fileSort);
  }
}
