import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';

enum MediaSortOrder {
  newest,
  oldest,
  dateWise
}

class MediaProvider extends ChangeNotifier {
  List<AssetEntity> _images = [];
  List<AssetEntity> _videos = [];
  List<SongModel> _audios = [];
  
  bool _isLoading = false;
  MediaSortOrder _sortOrder = MediaSortOrder.newest;
  
  List<AssetEntity> get images => _images;
  List<AssetEntity> get videos => _videos;
  List<SongModel> get audios => _audios;
  bool get isLoading => _isLoading;
  MediaSortOrder get sortOrder => _sortOrder;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<void> loadMedia() async {
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

    _applySort();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadImagesAndVideos() async {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(onlyAll: true);
    if (albums.isNotEmpty) {
      List<AssetEntity> allMedia = await albums[0].getAssetListPaged(page: 0, size: 10000);
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

  void setSortOrder(MediaSortOrder order) {
    _sortOrder = order;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    if (_sortOrder == MediaSortOrder.newest || _sortOrder == MediaSortOrder.dateWise) {
      _images.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _videos.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));
      _audios.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
    } else if (_sortOrder == MediaSortOrder.oldest) {
      _images.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _videos.sort((a, b) => a.createDateTime.compareTo(b.createDateTime));
      _audios.sort((a, b) => (a.dateAdded ?? 0).compareTo(b.dateAdded ?? 0));
    }
  }
}
