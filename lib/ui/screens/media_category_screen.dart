import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../providers/media_provider.dart';
import 'image_viewer_screen.dart';
import 'video_player/video_player_screen.dart';
import 'audio_player/audio_player_screen.dart';
import 'document_viewer_screen.dart';
import '../../core/icon_fonts/broken_icons.dart';

enum MediaType { images, videos, audios, documents }

class MediaCategoryScreen extends StatefulWidget {
  final MediaType mediaType;

  const MediaCategoryScreen({super.key, required this.mediaType});

  @override
  State<MediaCategoryScreen> createState() => _MediaCategoryScreenState();
}

class _MediaCategoryScreenState extends State<MediaCategoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use cached data if available, no forced reload
      context.read<MediaProvider>().loadMedia();
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.mediaType) {
      case MediaType.images:
        return 'Images';
      case MediaType.videos:
        return 'Videos';
      case MediaType.audios:
        return 'Audios';
      case MediaType.documents:
        return 'Documents';
    }
  }

  IconData get _emptyIcon {
    switch (widget.mediaType) {
      case MediaType.images:
        return Broken.image;
      case MediaType.videos:
        return Broken.video;
      case MediaType.audios:
        return Broken.music;
      case MediaType.documents:
        return Broken.document;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (widget.mediaType != MediaType.documents)
            Consumer<MediaProvider>(
              builder: (context, provider, child) {
                return PopupMenuButton<MediaSortOrder>(
                  icon: const Icon(Icons.sort),
                  onSelected: (order) => provider.setSortOrder(order),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem(
                      value: MediaSortOrder.newest,
                      checked: provider.sortOrder == MediaSortOrder.newest,
                      child: const Text('Newest First'),
                    ),
                    CheckedPopupMenuItem(
                      value: MediaSortOrder.oldest,
                      checked: provider.sortOrder == MediaSortOrder.oldest,
                      child: const Text('Oldest First'),
                    ),
                    CheckedPopupMenuItem(
                      value: MediaSortOrder.dateWise,
                      checked: provider.sortOrder == MediaSortOrder.dateWise,
                      child: const Text('Date Wise'),
                    ),
                  ],
                );
              },
            ),
          // Refresh button
          Consumer<MediaProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => provider.loadMedia(forceRefresh: true),
                tooltip: 'Refresh',
              );
            },
          ),
        ],
      ),
      body: Consumer<MediaProvider>(
        builder: (context, provider, child) {
          // Show shimmer loading only on first load
          if (provider.isLoading && !provider.isLoaded) {
            return _buildShimmerLoading(theme);
          }

          if (widget.mediaType == MediaType.images) {
            return _buildImageGrid(provider.images, theme);
          } else if (widget.mediaType == MediaType.videos) {
            return _buildVideoGrid(provider.videos, theme);
          } else if (widget.mediaType == MediaType.audios) {
            return _buildAudioList(provider.audios, theme);
          } else {
            return _buildDocumentList(provider.documents, theme);
          }
        },
      ),
    );
  }

  // ─── Shimmer Loading (Namida-style) ───────────────────────────────────────
  Widget _buildShimmerLoading(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor =
        isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ShaderMask(
                shaderCallback: (rect) {
                  final gradient = LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [baseColor, highlightColor, baseColor],
                    stops: [
                      0.0,
                      _shimmerController.value,
                      1.0,
                    ],
                  );
                  return gradient.createShader(rect);
                },
                child: Container(color: baseColor),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Image Grid ───────────────────────────────────────────────────────────
  Widget _buildImageGrid(List<AssetEntity> images, ThemeData theme) {
    if (images.isEmpty) return _buildEmptyState(theme);
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final asset = images[index];
        return _CachedImageTile(
          asset: asset,
          onTap: () async {
            final file = await asset.file;
            if (file != null && context.mounted) {
              Navigator.push(
                context,
                _slideRoute(ImageViewerScreen(imagePath: file.path)),
              );
            }
          },
        );
      },
    );
  }

  // ─── Video Grid ───────────────────────────────────────────────────────────
  Widget _buildVideoGrid(List<AssetEntity> videos, ThemeData theme) {
    if (videos.isEmpty) return _buildEmptyState(theme);
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final asset = videos[index];
        return _CachedVideoTile(
          asset: asset,
          onTap: () async {
            final file = await asset.file;
            if (file != null && context.mounted) {
              Navigator.push(
                context,
                _slideRoute(VideoPlayerScreen(videoPath: file.path)),
              );
            }
          },
        );
      },
    );
  }

  // ─── Audio List ───────────────────────────────────────────────────────────
  Widget _buildAudioList(List<SongModel> audios, ThemeData theme) {
    if (audios.isEmpty) return _buildEmptyState(theme);
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: audios.length,
      itemBuilder: (context, index) {
        final audio = audios[index];
        return _AudioListTile(
          audio: audio,
          index: index,
          allAudios: audios,
        );
      },
    );
  }

  // ─── Documents List ───────────────────────────────────────────────────────
  Widget _buildDocumentList(
      List<FileSystemEntity> documents, ThemeData theme) {
    if (documents.isEmpty) return _buildEmptyState(theme);
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index] as dynamic;
        final path = doc.path as String;
        final name = path.split('/').last;
        final ext = name.contains('.')
            ? name.substring(name.lastIndexOf('.')).toLowerCase()
            : '';
        final icon = _docIcon(ext);
        final color = _docColor(ext);

        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            ext.isEmpty ? 'File' : ext.toUpperCase().replaceAll('.', ''),
            style: TextStyle(color: color, fontSize: 11),
          ),
          trailing: Icon(Broken.arrow_right_3, size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.4)),
          onTap: () {
            Navigator.push(
              context,
              _slideRoute(DocumentViewerScreen(filePath: path)),
            );
          },
        );
      },
    );
  }

  IconData _docIcon(String ext) {
    switch (ext) {
      case '.pdf':
        return Broken.document;
      case '.doc':
      case '.docx':
        return Broken.document_text;
      case '.xls':
      case '.xlsx':
        return Broken.document_text;
      case '.ppt':
      case '.pptx':
        return Broken.presention_chart;
      case '.txt':
        return Broken.note_2;
      default:
        return Broken.document;
    }
  }

  Color _docColor(String ext) {
    switch (ext) {
      case '.pdf':
        return Colors.redAccent;
      case '.doc':
      case '.docx':
        return Colors.blueAccent;
      case '.xls':
      case '.xlsx':
        return Colors.green;
      case '.ppt':
      case '.pptx':
        return Colors.orangeAccent;
      case '.txt':
        return Colors.purpleAccent;
      default:
        return Colors.teal;
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _emptyIcon,
            size: 72,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_title.toLowerCase()} found',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final minutes = d.inMinutes;
    final remainingSeconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

// ─── Thumbnail Shimmer Placeholder (Namida-style) ───────────────────────────
class _ThumbnailShimmerPlaceholder extends StatefulWidget {
  const _ThumbnailShimmerPlaceholder({super.key});

  @override
  State<_ThumbnailShimmerPlaceholder> createState() => _ThumbnailShimmerPlaceholderState();
}

class _ThumbnailShimmerPlaceholderState extends State<_ThumbnailShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (rect) {
            final gradient = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                0.0,
                _controller.value,
                1.0,
              ],
            );
            return gradient.createShader(rect);
          },
          child: Container(color: baseColor),
        );
      },
    );
  }
}

// ─── Cached Image Tile ────────────────────────────────────────────────────────
class _CachedImageTile extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _CachedImageTile({required this.asset, required this.onTap});

  @override
  State<_CachedImageTile> createState() => _CachedImageTileState();
}

class _CachedImageTileState extends State<_CachedImageTile> {
  Uint8List? _thumbnail;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (ThumbnailCache.hasCached(widget.asset.id)) {
      if (mounted) {
        setState(() {
          _thumbnail = ThumbnailCache.getCached(widget.asset.id);
          _loaded = true;
        });
      }
      return;
    }
    final data = await ThumbnailCache.get(widget.asset);
    if (mounted) {
      setState(() {
        _thumbnail = data;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _loaded && _thumbnail != null
              ? Image.memory(
                  _thumbnail!,
                  key: const ValueKey('img'),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                )
              : const _ThumbnailShimmerPlaceholder(key: ValueKey('shimmer')),
        ),
      ),
    );
  }
}

// ─── Cached Video Tile ────────────────────────────────────────────────────────
class _CachedVideoTile extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const _CachedVideoTile({required this.asset, required this.onTap});

  @override
  State<_CachedVideoTile> createState() => _CachedVideoTileState();
}

class _CachedVideoTileState extends State<_CachedVideoTile> {
  Uint8List? _thumbnail;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (ThumbnailCache.hasCached(widget.asset.id)) {
      if (mounted) {
        setState(() {
          _thumbnail = ThumbnailCache.getCached(widget.asset.id);
          _loaded = true;
        });
      }
      return;
    }
    final data = await ThumbnailCache.get(widget.asset);
    if (mounted) {
      setState(() {
        _thumbnail = data;
        _loaded = true;
      });
    }
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loaded && _thumbnail != null
                  ? Image.memory(
                      _thumbnail!,
                      key: const ValueKey('vid'),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                    )
                  : const _ThumbnailShimmerPlaceholder(key: ValueKey('shimmer')),
            ),
            // Dark gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
            // Play icon
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 22),
              ),
            ),
            // Duration badge
            Positioned(
              bottom: 4,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(widget.asset.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Audio List Tile ──────────────────────────────────────────────────────────
class _AudioListTile extends StatelessWidget {
  final SongModel audio;
  final int index;
  final List<SongModel> allAudios;

  const _AudioListTile({
    required this.audio,
    required this.index,
    required this.allAudios,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                AudioPlayerScreen(
              audioPath: audio.data,
              title: audio.title,
              artist: audio.artist ?? 'Unknown Artist',
              allSongs: allAudios,
              initialIndex: index,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.primaryContainer,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: QueryArtworkWidget(
                  id: audio.id,
                  type: ArtworkType.AUDIO,
                  artworkBorder: BorderRadius.circular(10),
                  artworkFit: BoxFit.cover,
                  artworkWidth: 52,
                  artworkHeight: 52,
                  nullArtworkWidget: Icon(
                    Icons.music_note,
                    size: 26,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    audio.artist ?? 'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.play_circle_outline,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
