import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:mime/mime.dart';
import 'package:photo_manager/photo_manager.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imagePath;
  final List<String>? siblingPaths;
  final List<AssetEntity>? siblingAssets;
  final String? initialAssetId;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
    this.siblingPaths,
    this.siblingAssets,
    this.initialAssetId,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  List<String> _imageList = [];
  int _currentIndex = 0;
  bool _showUI = true;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _findSiblings();
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _findSiblings() {
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
          if (mime != null && mime.startsWith('image/')) {
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalCount = widget.siblingAssets != null ? widget.siblingAssets!.length : _imageList.length;
    String currentTitle = 'Image';
    if (widget.siblingAssets != null && _currentIndex < widget.siblingAssets!.length) {
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
          key: ValueKey(_currentIndex),
          direction: _isZoomed ? DismissDirection.none : DismissDirection.vertical,
          onDismissed: (_) => Navigator.pop(context),
          dismissThresholds: const {
            DismissDirection.down: 0.2,
            DismissDirection.up: 0.2,
          },
          child: PageView.builder(
            controller: _pageController,
            physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
            itemCount: totalCount,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              if (widget.siblingAssets != null) {
                final asset = widget.siblingAssets![index];
                return FutureBuilder<File?>(
                  future: asset.file,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    return _buildPhotoView(snapshot.data!.path);
                  },
                );
              } else {
                final path = _imageList[index];
                return _buildPhotoView(path);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoView(String path) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showUI = !_showUI;
        });
      },
      child: PhotoView(
        imageProvider: FileImage(File(path)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4,
        heroAttributes: PhotoViewHeroAttributes(tag: path),
        scaleStateChangedCallback: (state) {
          setState(() {
            _isZoomed = state != PhotoViewScaleState.initial;
          });
        },
        onTapUp: (_, __, ___) {
          setState(() {
            _showUI = !_showUI;
          });
        },
      ),
    );
  }
}
