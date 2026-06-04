import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:mime/mime.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_avif/flutter_avif.dart';
import '../../providers/media_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';

final Uint8List _kTransparentImage = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

class ImageViewerScreen extends StatefulWidget {
  final String imagePath;
  final List<String>? siblingPaths;
  final List<AssetEntity>? siblingAssets;
  final List<dynamic>? siblingItems;
  final String? initialAssetId;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
    this.siblingPaths,
    this.siblingAssets,
    this.siblingItems,
    this.initialAssetId,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  List<String> _imageList = [];
  final Map<int, File?> _fileCache = {};
  int _currentIndex = 0;
  bool _showUI = true;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _findSiblings();
    _pageController = PageController(initialPage: _currentIndex);
    _preloadAdjacent(_currentIndex);
  }

  void _findSiblings() {
    if (widget.siblingItems != null && widget.siblingItems!.isNotEmpty) {
      _currentIndex = widget.siblingItems!.indexWhere((e) {
        if (e is AssetEntity) return e.id == widget.initialAssetId;
        if (e is FileSystemEntity) return e.path == widget.imagePath;
        return false;
      });
      if (_currentIndex == -1) _currentIndex = 0;
      return;
    }

    if (widget.siblingAssets != null && widget.siblingAssets!.isNotEmpty) {
      _currentIndex = widget.siblingAssets!.indexWhere((e) => e.id == widget.initialAssetId);
      if (_currentIndex == -1) _currentIndex = 0;
      return;
    }

    if (widget.siblingPaths != null && widget.siblingPaths!.isNotEmpty) {
      _imageList = widget.siblingPaths!;
      _currentIndex = _imageList.indexOf(widget.imagePath);
      if (_currentIndex == -1) _currentIndex = 0;
      return;
    }

    try {
      final file = File(widget.imagePath);
      final parent = file.parent;
      final files = parent.listSync();
      final images = <String>[];
      for (final f in files) {
        if (f is File) {
          final mime = lookupMimeType(f.path);
          if ((mime != null && mime.startsWith('image/')) || f.path.toLowerCase().endsWith('.avif')) {
            images.add(f.path);
          }
        }
      }
      images.sort((a, b) => a.compareTo(b));
      _imageList = images;
      _currentIndex = _imageList.indexOf(widget.imagePath);
      if (_currentIndex == -1) {
        _imageList.insert(0, widget.imagePath);
        _currentIndex = 0;
      }
    } catch (_) {
      _imageList = [widget.imagePath];
      _currentIndex = 0;
    }
  }

  void _preloadAdjacent(int index) {
    if (widget.siblingItems == null && widget.siblingAssets == null) return;
    _loadAssetFile(index);
    _loadAssetFile(index - 1);
    _loadAssetFile(index + 1);
  }

  Future<void> _loadAssetFile(int index) async {
    final length = widget.siblingItems != null
        ? widget.siblingItems!.length
        : (widget.siblingAssets != null ? widget.siblingAssets!.length : 0);
    if (index < 0 || index >= length) return;
    if (_fileCache.containsKey(index) && _fileCache[index] != null) return;

    if (widget.siblingItems != null) {
      final item = widget.siblingItems![index];
      if (item is AssetEntity) {
        final file = await item.file;
        if (mounted && file != null) {
          setState(() {
            _fileCache[index] = file;
          });
        }
      } else if (item is FileSystemEntity) {
        setState(() {
          _fileCache[index] = File(item.path);
        });
      }
    } else if (widget.siblingAssets != null) {
      final asset = widget.siblingAssets![index];
      final file = await asset.file;
      if (mounted && file != null) {
        setState(() {
          _fileCache[index] = file;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = widget.siblingItems != null
        ? widget.siblingItems!.length
        : (widget.siblingAssets != null ? widget.siblingAssets!.length : _imageList.length);
    String currentTitle = 'Image';
    if (widget.siblingItems != null && _currentIndex < widget.siblingItems!.length) {
      final item = widget.siblingItems![_currentIndex];
      if (item is AssetEntity) {
        currentTitle = item.title ?? 'Image';
      } else if (item is FileSystemEntity) {
        currentTitle = item.path.split('/').last.split('\\').last;
      }
    } else if (widget.siblingAssets != null && _currentIndex < widget.siblingAssets!.length) {
      currentTitle = widget.siblingAssets![_currentIndex].title ?? 'Image';
    } else if (_imageList.isNotEmpty && _currentIndex < _imageList.length) {
      currentTitle = _imageList[_currentIndex].split('/').last.split('\\').last;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: _showUI 
            ? AppBar(
                backgroundColor: Colors.black.withValues(alpha: 0.55),
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTitle, 
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentIndex + 1} of $totalCount',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : null,
        body: Dismissible(
          key: const ValueKey('image_viewer_dismissible'),
          direction: _isZoomed ? DismissDirection.none : DismissDirection.vertical,
          onDismissed: (_) => Navigator.pop(context),
          dismissThresholds: const {
            DismissDirection.down: 0.2,
            DismissDirection.up: 0.2,
          },
          child: GestureDetector(
            onTap: () {
              setState(() {
                _showUI = !_showUI;
              });
            },
            child: PhotoViewGallery.builder(
              scrollPhysics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
              pageController: _pageController,
              itemCount: totalCount,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
                _preloadAdjacent(index);
              },
              scaleStateChangedCallback: (state) {
                setState(() {
                  _isZoomed = state != PhotoViewScaleState.initial;
                });
              },
              builder: (context, index) {
                File? imgFile;
                Uint8List? thumbData;
                String tagKey = 'img_$index';

                if (widget.siblingItems != null) {
                  final item = widget.siblingItems![index];
                  if (item is AssetEntity) {
                    tagKey = item.id;
                    imgFile = _fileCache[index];
                    thumbData = ThumbnailCache.getCached(item.id);
                  } else if (item is FileSystemEntity) {
                    tagKey = item.path;
                    imgFile = File(item.path);
                  }
                } else if (widget.siblingAssets != null) {
                  final asset = widget.siblingAssets![index];
                  tagKey = asset.id;
                  imgFile = _fileCache[index];
                  thumbData = ThumbnailCache.getCached(asset.id);
                } else {
                  final path = _imageList[index];
                  tagKey = path;
                  imgFile = File(path);
                }

                final bool isValidFile = imgFile != null && imgFile.existsSync() && imgFile.lengthSync() > 16;
                final bool isAvif = imgFile != null && imgFile.path.toLowerCase().endsWith('.avif');

                final ImageProvider provider = isValidFile
                    ? (isAvif ? FileAvifImage(imgFile) : FileImage(imgFile)) as ImageProvider
                    : (thumbData != null ? MemoryImage(thumbData) : MemoryImage(_kTransparentImage));

                return PhotoViewGalleryPageOptions(
                  imageProvider: provider,
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  heroAttributes: PhotoViewHeroAttributes(tag: tagKey),
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Broken.image, size: 64, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  },
                  onTapUp: (context, details, controllerValue) {
                    setState(() {
                      _showUI = !_showUI;
                    });
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
