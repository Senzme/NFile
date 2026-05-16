import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';

enum MediaSortOrder {
  newest,
  oldest,
  dateWise,
}

class ThumbnailCache {
  static final Map<String, Uint8List?> _cache = {};
  static final Map<String, Future<Uint8List?>> _pending = {};

  static Future<Uint8List?> get(AssetEntity asset) async {
    final key = asset.id;
    if (_cache.containsKey(key)) return _cache[key];
    if (_pending.containsKey(key)) return _pending[key];

    final future = asset.thumbnailDataWithSize(const ThumbnailSize.square(300));
    _pending[key] = future;
    final data = await future;
    _cache[key] = data;
    _pending.remove(key);
    return data;
  }

  static Uint8List? getCached(String id) => _cache[id];
  static bool hasCached(String id) => _cache.containsKey(id);

  static void clear() {
    _cache.clear();
    _pending.clear();
  }
}

class MediaProvider extends ChangeNotifier {
  List<AssetEntity> _images = [];
  List<AssetEntity> _videos = [];
  List<SongModel> _audios = [];
  List<FileSystemEntity> _documents = [];

  bool _isLoading = false;
  bool _isLoaded = false;
  MediaSortOrder _sortOrder = MediaSortOrder.newest;

  List<AssetEntity> get images => _images;
  List<AssetEntity> get videos => _videos;
  List<SongModel> get audios => _audios;
  List<FileSystemEntity> get documents => _documents;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  MediaSortOrder get sortOrder => _sortOrder;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<void> loadMedia({bool forceRefresh = false}) async {
    // Don't reload if already loaded (prevents repeated loading on navigation)
    if (_isLoaded && !forceRefresh) return;

    _isLoading = true;
    notifyListeners();

    // Request permissions
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      await _loadImagesAndVideos();
    }

    bool hasAudioPermission = await _audioQuery.permissionsStatus();
    if (!hasAudioPermission) {
      hasAudioPermission = await _audioQuery.permissionsRequest();
    }
    if (hasAudioPermission) {
      await _loadAudios();
    }

    await _loadDocuments();

    _applySort();
    _isLoading = false;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _loadImagesAndVideos() async {
    List<AssetPathEntity> albums =
        await PhotoManager.getAssetPathList(onlyAll: true);
    if (albums.isNotEmpty) {
      // Load in pages for fast initial display
      List<AssetEntity> allMedia =
          await albums[0].getAssetListPaged(page: 0, size: 10000);
      _images = allMedia.where((e) => e.type == AssetType.image).toList();
      _videos = allMedia.where((e) => e.type == AssetType.video).toList();
    }
  }

  Future<void> _loadAudios() async {
    _audios = await _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
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

    _documents.sort((a, b) {
      try {
        final aTime = (a as File).lastModifiedSync();
        final bTime = (b as File).lastModifiedSync();
        return _sortOrder == MediaSortOrder.oldest
            ? aTime.compareTo(bTime)
            : bTime.compareTo(aTime);
      } catch (_) {
        return 0;
      }
    });
  }
}
