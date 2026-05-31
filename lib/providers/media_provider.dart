import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:device_info_plus/device_info_plus.dart';
import '../services/preferences_service.dart';
import '../models/custom_shortcut_model.dart';
import '../models/file_item_model.dart';

enum MediaSortOrder {
  newest,
  oldest,
  dateWise,
  newestGrouped,
  oldestGrouped,
  sizeLargest,
  sizeSmallest,
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
      try {
        final files = folder.listSync();
        for (final f in files) {
          if (f is File && f.path.endsWith('.thumb')) {
            final key = f.path.split('/').last.split('\\').last.replaceAll('.thumb', '');
            if (!_cache.containsKey(key)) {
              _cache[key] = f.readAsBytesSync();
            }
          }
        }
      } catch (_) {}
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
  MediaProvider() {
    final savedOrder = PreferencesService.getCategoryOrder();
    if (savedOrder != null && savedOrder.isNotEmpty) {
      _categoryOrder = savedOrder;
      if (!_categoryOrder.contains('Apps')) {
        _categoryOrder.add('Apps');
        PreferencesService.saveCategoryOrder(_categoryOrder);
      }
    }
    final savedActive = PreferencesService.getActiveCategories();
    if (savedActive != null && savedActive.isNotEmpty) {
      _activeCategories = savedActive;
    }
    final savedCustom = PreferencesService.getCustomShortcuts();
    if (savedCustom != null) {
      _customShortcuts = savedCustom;
    }
  }

  List<AssetEntity> _images = [];
  List<AssetEntity> _videos = [];
  List<SongModel> _audios = [];
  List<FileSystemEntity> _documents = [];
  List<FileSystemEntity> _archives = [];
  List<FileSystemEntity> _downloads = [];
  List<FileSystemEntity> _apks = [];
  List<AssetEntity> _screenshots = [];
  List<FileItemModel> _recentFiles = [];
  List<CustomShortcutModel> _customShortcuts = [];
  List<AssetPathEntity> _imageAlbums = [];
  List<AssetPathEntity> _videoAlbums = [];

  // Android 10 (API <= 29) native MediaStore paths
  // These are populated instead of _images/_videos/_audios on API <= 29
  List<String> _nativeImagePaths = [];
  List<String> _nativeVideoPaths = [];
  List<String> _nativeAudioPaths = [];
  bool _usingNativeMediaStore = false;

  // Native folders: folder path -> list of file paths
  Map<String, List<String>> _nativeImageFolders = {};
  Map<String, List<String>> _nativeVideoFolders = {};

  List<AssetPathEntity> get imageAlbums => _imageAlbums;
  List<AssetPathEntity> get videoAlbums => _videoAlbums;

  // Getters that return native paths on Android 10, AssetEntity list on API 30+
  bool get usingNativeMediaStore => _usingNativeMediaStore;
  List<String> get nativeImagePaths => _nativeImagePaths;
  List<String> get nativeVideoPaths => _nativeVideoPaths;
  List<String> get nativeAudioPaths => _nativeAudioPaths;
  Map<String, List<String>> get nativeImageFolders => _nativeImageFolders;
  Map<String, List<String>> get nativeVideoFolders => _nativeVideoFolders;

  // For count display - works for both native and photo_manager
  int get imageCount => _usingNativeMediaStore ? _nativeImagePaths.length : _images.length;
  int get videoCount => _usingNativeMediaStore ? _nativeVideoPaths.length : _videos.length;
  int get audioCount => _usingNativeMediaStore ? _nativeAudioPaths.length : _audios.length;

  List<String> _categoryOrder = [
    'Images',
    'Videos',
    'Audio',
    'Documents',
    'Archives',
    'Downloads',
    'APKs',
    'Screenshots',
    'Apps',
  ];

  List<String> _activeCategories = [
    'Images',
    'Videos',
    'Audio',
    'Documents',
    'Archives',
    'Downloads',
    'APKs',
    'Screenshots',
  ];


  bool _isLoading = false;
  bool _isLoaded = false;
  MediaSortOrder _sortOrder = MediaSortOrder.newest;

  List<AssetEntity> get images => _images;
  List<AssetEntity> get videos => _videos;
  List<SongModel> get audios => _audios;
  List<FileSystemEntity> get documents => _documents;
  List<FileSystemEntity> get archives => _archives;
  List<FileSystemEntity> get downloads => _downloads;
  List<FileSystemEntity> get apks => _apks;
  List<AssetEntity> get screenshots => _screenshots;
  List<FileItemModel> get recentFiles => _recentFiles;
  List<CustomShortcutModel> get customShortcuts => _customShortcuts;
  List<String> get categoryOrder => _categoryOrder;
  List<String> get activeCategories => _activeCategories;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  MediaSortOrder get sortOrder => _sortOrder;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  void toggleCategory(String label) {
    if (_activeCategories.contains(label)) {
      if (_activeCategories.length > 1) {
        _activeCategories.remove(label);
      }
    } else {
      _activeCategories.add(label);
    }
    PreferencesService.saveActiveCategories(_activeCategories);
    _saveCache();
    notifyListeners();
  }

  void reorderCategory(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = _categoryOrder.removeAt(oldIndex);
    _categoryOrder.insert(newIndex, item);
    PreferencesService.saveCategoryOrder(_categoryOrder);
    _saveCache();
    notifyListeners();
  }

  void addCustomShortcut(String path) {
    final label = p.basename(path);
    final id = 'custom_$path';
    if (_categoryOrder.contains(id)) return;

    final isDir = FileSystemEntity.isDirectorySync(path);
    final cs = CustomShortcutModel(id: id, label: label, path: path, isDirectory: isDir);
    _customShortcuts.add(cs);
    _categoryOrder.add(id);
    _activeCategories.add(id);

    PreferencesService.saveCustomShortcuts(_customShortcuts);
    PreferencesService.saveCategoryOrder(_categoryOrder);
    PreferencesService.saveActiveCategories(_activeCategories);
    _saveCache();
    notifyListeners();
  }

  void removeCustomShortcut(String id) {
    _customShortcuts.removeWhere((cs) => cs.id == id);
    _categoryOrder.remove(id);
    _activeCategories.remove(id);

    PreferencesService.saveCustomShortcuts(_customShortcuts);
    PreferencesService.saveCategoryOrder(_categoryOrder);
    PreferencesService.saveActiveCategories(_activeCategories);
    _saveCache();
    notifyListeners();
  }

  int getCategoryItemCount(String category) {
    if (_isLoaded) {
      switch (category) {
        case 'Images': return imageCount;   // uses _nativeImagePaths.length on API <= 29
        case 'Videos': return videoCount;   // uses _nativeVideoPaths.length on API <= 29
        case 'Audio': return audioCount;    // uses _nativeAudioPaths.length on API <= 29
        case 'Documents': return _documents.length;
        case 'Archives': return _archives.length;
        case 'Downloads': return _downloads.length;
        case 'APKs': return _apks.length;
        case 'Screenshots':
          return _usingNativeMediaStore
              ? _nativeImagePaths.where((p) => p.toLowerCase().contains('screenshot')).length
              : _screenshots.length;
        case 'Apps': return 0;
      }
    }
    return PreferencesService.getCategoryCount(category);
  }

  Future<void> _loadFromDiskCache() async {
    try {
      final dir = await getTemporaryDirectory();
      final cacheFile = File('${dir.path}/media_meta_cache.json');
      if (await cacheFile.exists()) {
        final jsonStr = await cacheFile.readAsString();
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (map.containsKey('categoryOrder')) {
          _categoryOrder = List<String>.from(map['categoryOrder'] ?? _categoryOrder);
          if (!_categoryOrder.contains('Apps')) {
            _categoryOrder.add('Apps');
          }
        }
        if (map.containsKey('activeCategories')) {
          _activeCategories = List<String>.from(map['activeCategories'] ?? _activeCategories);
        }

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

        if (map.containsKey('apks')) {
          final apkPaths = List<String>.from(map['apks'] ?? []);
          final cachedApks = <FileSystemEntity>[];
          for (final p in apkPaths) {
            final f = File(p);
            if (f.existsSync()) cachedApks.add(f);
          }
          if (cachedApks.isNotEmpty && _apks.isEmpty) {
            _apks = cachedApks;
          }
        }

        if (map.containsKey('recentFiles')) {
          final paths = List<Map<String, dynamic>>.from(
            (map['recentFiles'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
          );
          final cached = <FileItemModel>[];
          for (final entry in paths) {
            try {
              final path = entry['path'] as String?;
              if (path == null) continue;
              final f = File(path);
              if (!f.existsSync()) continue;
              cached.add(FileItemModel(
                entity: f,
                name: p.basename(path),
                path: path,
                isDirectory: false,
                size: (entry['size'] as num?)?.toInt() ?? 0,
                modified: DateTime.fromMillisecondsSinceEpoch(
                  (entry['modified'] as num?)?.toInt() ?? 0,
                ),
              ));
            } catch (_) {}
          }
          if (cached.isNotEmpty && _recentFiles.isEmpty) {
            _recentFiles = cached;
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
        'categoryOrder': _categoryOrder,
        'activeCategories': _activeCategories,
        'documents': _documents.map((e) => e.path).toList(),
        'archives': _archives.map((e) => e.path).toList(),
        'downloads': _downloads.map((e) => e.path).toList(),
        'apks': _apks.map((e) => e.path).toList(),
        'recentFiles': _recentFiles.take(30).map((e) => {
          'path': e.path,
          'size': e.size,
          'modified': e.modified.millisecondsSinceEpoch,
        }).toList(),
      };
      await cacheFile.writeAsString(jsonEncode(map), flush: true);
    } catch (_) {}
  }

  // Native MediaStore channel - bypasses photo_manager / on_audio_query on Android 10
  static const _mediaStoreChannel = MethodChannel('com.rubex.nfile/media_store');

  Future<void> loadMedia({bool forceRefresh = false}) async {
    if (_isLoaded && !forceRefresh) return;

    _isLoading = true;
    notifyListeners();

    // Fast initial load from disk cache
    await _loadFromDiskCache();

    // Detect Android SDK once and share it throughout this call
    int? sdk;
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        sdk = info.version.sdkInt;
      } catch (_) {}
    }

    // On Android 10 (API 29) and below, photo_manager and on_audio_query require
    // separate media permissions (READ_MEDIA_IMAGES etc.) that do NOT EXIST on
    // Android 10 - those were only added in API 33.  The only permission that
    // exists on API 29 is READ_EXTERNAL_STORAGE (already granted at startup).
    // So on API <= 29 we talk to our native MediaStore channel directly, just
    // like the Prism File Explorer does.
    final useNative = Platform.isAndroid && sdk != null && sdk < 30;

    if (!useNative) {
      // API 30+ or non-Android: let photo_manager handle images/videos.
      try { PhotoManager.setIgnorePermissionCheck(true); } catch (_) {}
    }

    final futures = <Future<void>>[
      _loadImagesAndVideos(useNative: useNative),
      _loadAudios(useNative: useNative),
      _loadDocuments(),
      _loadArchivesDownloadsAndApks(),
    ];

    if (!useNative) {
      try { PhotoManager.clearFileCache(); } catch (_) {}
    }

    await Future.wait(futures);

    // Scan recent files after all media is loaded so it can merge from providers
    await _scanRecentFiles();

    await _saveCache();

    _applySort();

    PreferencesService.saveCategoryCount('Images', imageCount);
    PreferencesService.saveCategoryCount('Videos', videoCount);
    PreferencesService.saveCategoryCount('Audio', audioCount);
    PreferencesService.saveCategoryCount('Documents', _documents.length);
    PreferencesService.saveCategoryCount('Archives', _archives.length);
    PreferencesService.saveCategoryCount('Downloads', _downloads.length);
    PreferencesService.saveCategoryCount('APKs', _apks.length);
    PreferencesService.saveCategoryCount('Screenshots',
        _usingNativeMediaStore
            ? _nativeImagePaths.where((p) => p.toLowerCase().contains('screenshot')).length
            : _screenshots.length);

    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _loadImagesAndVideos({bool useNative = false}) async {
    if (useNative) {
      // Android 10 path — same 2-strategy approach as audio:
      // Strategy 1: Native MediaStore channel
      // Strategy 2: Dart-side filesystem scan (guaranteed, READ_EXTERNAL_STORAGE is enough)

      const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.heif', '.avif', '.tiff', '.tif'};
      const _videoExtensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.3gp', '.ts', '.m4v', '.mpeg', '.mpg'};

      final imgFound = <String>{};
      final vidFound = <String>{};

      // Strategy 1: MediaStore channel
      try {
        final imgPaths = await _mediaStoreChannel.invokeListMethod<String>(
          'queryMedia', {'mediaType': 1},  // MEDIA_TYPE_IMAGE
        ) ?? [];
        imgFound.addAll(imgPaths.where((p) => p.isNotEmpty));
      } catch (e) { debugPrint('[NFile] Native image channel error: $e'); }

      try {
        final vidPaths = await _mediaStoreChannel.invokeListMethod<String>(
          'queryMedia', {'mediaType': 3},  // MEDIA_TYPE_VIDEO
        ) ?? [];
        vidFound.addAll(vidPaths.where((p) => p.isNotEmpty));
      } catch (e) { debugPrint('[NFile] Native video channel error: $e'); }

      // Strategy 2: Dart filesystem scan
      const imgScanDirs = [
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Images',
        '/storage/emulated/0/Telegram/Telegram Images',
        '/storage/emulated/0/Instagram',
      ];
      const vidScanDirs = [
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Movies',
        '/storage/emulated/0/Videos',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Video',
        '/storage/emulated/0/Telegram/Telegram Video',
      ];

      for (final dirPath in imgScanDirs) {
        try {
          final dir = Directory(dirPath);
          if (dir.existsSync()) {
            await for (final entity in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final ext = entity.path.contains('.')
                    ? '.${entity.path.split('.').last.toLowerCase()}'
                    : '';
                if (_imageExtensions.contains(ext)) imgFound.add(entity.path);
              }
            }
          }
        } catch (e) { debugPrint('[NFile] Image scan error $dirPath: $e'); }
      }

      for (final dirPath in vidScanDirs) {
        try {
          final dir = Directory(dirPath);
          if (dir.existsSync()) {
            await for (final entity in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final ext = entity.path.contains('.')
                    ? '.${entity.path.split('.').last.toLowerCase()}'
                    : '';
                if (_videoExtensions.contains(ext)) vidFound.add(entity.path);
              }
            }
          }
        } catch (e) { debugPrint('[NFile] Video scan error $dirPath: $e'); }
      }

      // Sort newest-first, build results
      _nativeImagePaths = imgFound.toList()
        ..sort((a, b) => File(b).statSync().modified.compareTo(File(a).statSync().modified));
      _nativeVideoPaths = vidFound.toList()
        ..sort((a, b) => File(b).statSync().modified.compareTo(File(a).statSync().modified));
      _nativeAudioPaths = []; // will be filled by _loadAudios
      _usingNativeMediaStore = true;

      // Build folder groups for the Folders tab
      _nativeImageFolders = _groupPathsByFolder(_nativeImagePaths);
      _nativeVideoFolders = _groupPathsByFolder(_nativeVideoPaths);

      // Screenshots = images whose path contains 'screenshot'
      _screenshots = [];
      _images = [];
      _videos = [];
      return;
    }

    // API 30+ path: use photo_manager as before
    try {
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(onlyAll: false);
      List<AssetEntity> allScreenshots = [];
      for (final album in albums) {
        if (album.name.toLowerCase().contains('screenshot')) {
          allScreenshots = await album.getAssetListPaged(page: 0, size: 5000);
          break;
        }
      }

      if (albums.isNotEmpty) {
        List<AssetEntity> allMedia = await albums[0].getAssetListPaged(page: 0, size: 10000);
        _images = allMedia.where((e) => e.type == AssetType.image).toList();
        _videos = allMedia.where((e) => e.type == AssetType.video).toList();
        if (allScreenshots.isEmpty) {
          _screenshots = _images.where((e) => (e.title ?? '').toLowerCase().contains('screenshot') || (e.relativePath ?? '').toLowerCase().contains('screenshot')).toList();
        } else {
          _screenshots = allScreenshots;
        }
      }

      // Fetch distinct image albums
      final imgAlbums = await PhotoManager.getAssetPathList(type: RequestType.image);
      final filteredImgAlbums = <AssetPathEntity>[];
      for (final album in imgAlbums) {
        final count = await album.assetCountAsync;
        if (count > 0) {
          filteredImgAlbums.add(album);
        }
      }
      _imageAlbums = filteredImgAlbums;

      // Fetch distinct video albums
      final vidAlbums = await PhotoManager.getAssetPathList(type: RequestType.video);
      final filteredVidAlbums = <AssetPathEntity>[];
      for (final album in vidAlbums) {
        final count = await album.assetCountAsync;
        if (count > 0) {
          filteredVidAlbums.add(album);
        }
      }
      _videoAlbums = filteredVidAlbums;
    } catch (_) {}
  }

  Future<void> _loadAudios({bool useNative = false}) async {
    if (useNative) {
      final found = <String>{};

      // Strategy 1: Try native MediaStore channel
      try {
        final paths = await _mediaStoreChannel.invokeListMethod<String>(
          'queryMedia', {'mediaType': 2},
        ) ?? [];
        found.addAll(paths.where((p) => p.isNotEmpty));
      } catch (e) {
        debugPrint('[NFile] Native audio channel error: $e');
      }

      // Strategy 2: Dart-side filesystem scan of common audio dirs
      // Works 100% on Android 10 with READ_EXTERNAL_STORAGE permission
      const _audioExtensions = {
        '.mp3', '.m4a', '.aac', '.ogg', '.opus', '.flac',
        '.wav', '.wma', '.amr', '.3gp', '.mid', '.midi'
      };
      const scanDirs = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Ringtones',
        '/storage/emulated/0/Alarms',
        '/storage/emulated/0/Notifications',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
        '/storage/emulated/0/Telegram/Telegram Audio',
      ];
      for (final dirPath in scanDirs) {
        try {
          final dir = Directory(dirPath);
          if (dir.existsSync()) {
            await for (final entity in dir.list(recursive: true, followLinks: false)) {
              if (entity is File) {
                final ext = entity.path.contains('.')
                    ? '.${entity.path.split('.').last.toLowerCase()}'
                    : '';
                if (_audioExtensions.contains(ext)) {
                  found.add(entity.path);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[NFile] Audio scan error for $dirPath: $e');
        }
      }

      _nativeAudioPaths = found.toList()
        ..sort((a, b) => File(b).statSync().modified.compareTo(File(a).statSync().modified));
      _audios = [];
      return;
    }

    // API 30+ path: use on_audio_query as before
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

  /// Groups a flat list of file paths by their parent folder name.
  /// Returns Map<folderName, [paths]> — used for Folders tab on Android 10.
  Map<String, List<String>> _groupPathsByFolder(List<String> paths) {
    final map = <String, List<String>>{};
    for (final path in paths) {
      final parts = path.split('/');
      if (parts.length >= 2) {
        final folderName = parts[parts.length - 2]; // parent dir name
        map.putIfAbsent(folderName, () => []).add(path);
      }
    }
    return map;
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

  Future<List<String>> _getUserSearchDirs() async {
    final searchDirs = <String>[];
    try {
      final rootDir = Directory('/storage/emulated/0');
      if (await rootDir.exists()) {
        await for (final entity in rootDir.list(recursive: false)) {
          try {
            if (entity is Directory) {
              final name = p.basename(entity.path);
              if (name != 'Android' && !name.startsWith('.')) {
                searchDirs.add(entity.path);
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (searchDirs.isEmpty) {
      searchDirs.addAll([
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/Telegram',
        '/storage/emulated/0/WhatsApp/Media',
      ]);
    }
    return searchDirs;
  }

  Future<void> _scanDirectoryRecursively(
    String startPath,
    bool Function(String ext) shouldInclude,
    void Function(File file) onFound,
  ) async {
    final queue = <String>[startPath];
    while (queue.isNotEmpty) {
      final currentPath = queue.removeAt(0);
      final dir = Directory(currentPath);
      try {
        await for (final entity in dir.list(recursive: false)) {
          try {
            if (entity is Directory) {
              final name = p.basename(entity.path);
              if (!name.startsWith('.') && name != 'Android') {
                queue.add(entity.path);
              }
            } else if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();
              if (shouldInclude(ext)) {
                onFound(entity);
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  Future<void> _loadDocuments() async {
    final docs = <FileSystemEntity>[];
    final searchDirs = await _getUserSearchDirs();

    for (final dirPath in searchDirs) {
      await _scanDirectoryRecursively(
        dirPath,
        (ext) => _docExtensions.contains(ext),
        (file) => docs.add(file),
      );
    }

    _documents = docs;
  }

  static const List<String> _archiveExtensions = ['.zip', '.tar', '.gz', '.bz2', '.rar', '.7z'];
  static const List<String> _apkExtensions = ['.apk', '.xapk', '.apks', '.aab'];

  Future<void> _loadArchivesDownloadsAndApks() async {
    final arch = <FileSystemEntity>[];
    final dl = <FileSystemEntity>[];
    final apkList = <FileSystemEntity>[];

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

    final searchDirs = await _getUserSearchDirs();

    for (final dirPath in searchDirs) {
      await _scanDirectoryRecursively(
        dirPath,
        (ext) => _archiveExtensions.contains(ext) || _apkExtensions.contains(ext),
        (file) {
          final ext = p.extension(file.path).toLowerCase();
          if (_archiveExtensions.contains(ext)) {
            arch.add(file);
          } else if (_apkExtensions.contains(ext)) {
            apkList.add(file);
          }
        },
      );
    }

    _downloads = dl;
    _archives = arch;
    _apks = apkList;
  }

  Future<void> _scanRecentFiles() async {
    final list = <FileSystemEntity>[];
    final seen = <String>{};

    final rootDir = Directory('/storage/emulated/0');
    if (await rootDir.exists()) {
      try {
        final List<String> pathsToScan = [];
        final rootEntities = await rootDir.list(recursive: false).toList();
        for (final entity in rootEntities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && name != 'Android') {
              pathsToScan.add(entity.path);
            }
          }
        }
        pathsToScan.addAll([
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
        ]);

        await Future.wait(pathsToScan.map((path) async {
          final dir = Directory(path);
          if (!await dir.exists()) return;
          try {
            final entities = await dir.list(recursive: false).toList();
            for (final entity in entities) {
              if (!seen.contains(entity.path)) {
                seen.add(entity.path);
                list.add(entity);
              }
              if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
                try {
                  final sub = await entity.list(recursive: false).toList();
                  for (final s in sub) {
                    if (!seen.contains(s.path)) {
                      seen.add(s.path);
                      list.add(s);
                    }
                  }
                } catch (_) {}
              }
            }
          } catch (_) {}
        }));
      } catch (_) {}
    }

    void addFromList(List<FileSystemEntity> src) {
      for (final e in src) {
        if (!seen.contains(e.path)) {
          seen.add(e.path);
          list.add(e);
        }
      }
    }

    addFromList(_downloads);
    addFromList(_documents);
    addFromList(_archives);
    addFromList(_apks);

    for (final song in _audios) {
      final path = song.data;
      if (!seen.contains(path)) {
        seen.add(path);
        try {
          final f = File(path);
          if (await f.exists()) list.add(f);
        } catch (_) {}
      }
    }

    // Filter: remove parent dirs if a child also exists in the list
    final filteredList = <FileSystemEntity>[];
    for (final entity in list) {
      if (entity is Directory) {
        bool hasChild = list.any((o) => o.path != entity.path && p.isWithin(entity.path, o.path));
        if (hasChild) continue;
      }
      filteredList.add(entity);
    }

    final items = <FileItemModel>[];
    await Future.wait(filteredList.map((f) async {
      try {
        if (f is Directory) return;
        final name = p.basename(f.path);
        if (name.startsWith('.')) return;
        final stat = await f.stat();
        items.add(FileItemModel(
          entity: f,
          name: name,
          path: f.path,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
        ));
      } catch (_) {}
    }));

    items.sort((a, b) => b.modified.compareTo(a.modified));
    _recentFiles = items;
  }

  void setSortOrder(MediaSortOrder order) {
    _sortOrder = order;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    if (_sortOrder == MediaSortOrder.newest ||
        _sortOrder == MediaSortOrder.newestGrouped ||
        _sortOrder == MediaSortOrder.dateWise) {
      _images.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _videos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _screenshots.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _audios.sort(
          (a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    } else if (_sortOrder == MediaSortOrder.oldest ||
               _sortOrder == MediaSortOrder.oldestGrouped) {
      _images.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _videos.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _screenshots.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _audios.sort(
          (a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
    } else if (_sortOrder == MediaSortOrder.sizeLargest ||
               _sortOrder == MediaSortOrder.sizeSmallest) {
      final isSmallest = _sortOrder == MediaSortOrder.sizeSmallest;
      _images.sort((a, b) {
        final aRes = a.width * a.height;
        final bRes = b.width * b.height;
        return isSmallest ? aRes.compareTo(bRes) : bRes.compareTo(aRes);
      });
      _videos.sort((a, b) {
        final aRes = a.width * a.height;
        final bRes = b.width * b.height;
        return isSmallest ? aRes.compareTo(bRes) : bRes.compareTo(aRes);
      });
      _screenshots.sort((a, b) {
        final aRes = a.width * a.height;
        final bRes = b.width * b.height;
        return isSmallest ? aRes.compareTo(bRes) : bRes.compareTo(aRes);
      });
      _audios.sort((a, b) {
        final aSize = a.size;
        final bSize = b.size;
        return isSmallest ? aSize.compareTo(bSize) : bSize.compareTo(aSize);
      });
    }

    int fileSort(FileSystemEntity a, FileSystemEntity b) {
      try {
        final isSmallest = _sortOrder == MediaSortOrder.sizeSmallest;
        final isLargest = _sortOrder == MediaSortOrder.sizeLargest;

        if (isSmallest || isLargest) {
          final aSize = (a as File).lengthSync();
          final bSize = (b as File).lengthSync();
          return isSmallest ? aSize.compareTo(bSize) : bSize.compareTo(aSize);
        }

        final aTime = (a as File).lastModifiedSync();
        final bTime = (b as File).lastModifiedSync();
        return (_sortOrder == MediaSortOrder.oldest || _sortOrder == MediaSortOrder.oldestGrouped)
            ? aTime.compareTo(bTime)
            : bTime.compareTo(aTime);
      } catch (_) {
        return 0;
      }
    }

    _documents.sort(fileSort);
    _archives.sort(fileSort);
    _downloads.sort(fileSort);
    _apks.sort(fileSort);
  }

  Future<void> deleteMediaItems({
    required List<String> filePaths,
    required List<String> assetIds,
  }) async {
    if (assetIds.isNotEmpty) {
      try {
        await PhotoManager.editor.deleteWithIds(assetIds);
      } catch (e) {
        debugPrint('Error deleting assets: $e');
      }
    }
    for (final path in filePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          f.deleteSync();
        }
      } catch (_) {}
    }

    // Local List Optimization - instant updates without full-disk scans
    if (assetIds.isNotEmpty) {
      _images.removeWhere((item) => assetIds.contains(item.id));
      _videos.removeWhere((item) => assetIds.contains(item.id));
      _screenshots.removeWhere((item) => assetIds.contains(item.id));
    }

    if (filePaths.isNotEmpty) {
      // In case any image/video matches by path/title
      _images.removeWhere((item) => filePaths.contains(item.title));
      _videos.removeWhere((item) => filePaths.contains(item.title));
      _screenshots.removeWhere((item) => filePaths.contains(item.title));

      _audios.removeWhere((item) => filePaths.contains(item.data));
      _documents.removeWhere((item) => filePaths.contains(item.path));
      _archives.removeWhere((item) => filePaths.contains(item.path));
      _downloads.removeWhere((item) => filePaths.contains(item.path));
      _apks.removeWhere((item) => filePaths.contains(item.path));
    }

    // Update Counts and Cache
    PreferencesService.saveCategoryCount('Images', _images.length);
    PreferencesService.saveCategoryCount('Videos', _videos.length);
    PreferencesService.saveCategoryCount('Audio', _audios.length);
    PreferencesService.saveCategoryCount('Documents', _documents.length);
    PreferencesService.saveCategoryCount('Archives', _archives.length);
    PreferencesService.saveCategoryCount('Downloads', _downloads.length);
    PreferencesService.saveCategoryCount('APKs', _apks.length);
    PreferencesService.saveCategoryCount('Screenshots', _screenshots.length);

    await _saveCache();
    notifyListeners();
  }
}
