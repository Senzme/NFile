import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:mime/mime.dart';

class ImageViewerScreen extends StatefulWidget {
  final String imagePath;
  final List<String>? siblingPaths;

  const ImageViewerScreen({super.key, required this.imagePath, this.siblingPaths});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  List<String> _imageList = [];
  int _currentIndex = 0;
  bool _showUI = true;

  @override
  void initState() {
    super.initState();
    _findSiblings();
    _pageController = PageController(initialPage: _currentIndex);
  }

  void _findSiblings() {
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
    final currentPath = _imageList[_currentIndex];
    final filename = currentPath.split('/').last.split('\\').last;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _showUI 
          ? AppBar(
              backgroundColor: Colors.black.withOpacity(0.6),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    filename, 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_currentIndex + 1} of ${_imageList.length}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            )
          : null,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showUI = !_showUI;
          });
        },
        child: PageView.builder(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          itemCount: _imageList.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final path = _imageList[index];
            return PhotoView(
              imageProvider: FileImage(File(path)),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(tag: path),
              onTapUp: (_, __, ___) {
                setState(() {
                  _showUI = !_showUI;
                });
              },
            );
          },
        ),
      ),
    );
  }
}
