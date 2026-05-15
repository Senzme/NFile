import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../providers/media_provider.dart';
import 'image_viewer_screen.dart';
import 'video_player_screen.dart';
import 'audio_player_screen.dart';

enum MediaType { images, videos, audios }

class MediaCategoryScreen extends StatefulWidget {
  final MediaType mediaType;
  
  const MediaCategoryScreen({super.key, required this.mediaType});

  @override
  State<MediaCategoryScreen> createState() => _MediaCategoryScreenState();
}

class _MediaCategoryScreenState extends State<MediaCategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaProvider>().loadMedia();
    });
  }

  String get _title {
    switch (widget.mediaType) {
      case MediaType.images: return 'Images';
      case MediaType.videos: return 'Videos';
      case MediaType.audios: return 'Audios';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
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
        ],
      ),
      body: Consumer<MediaProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.mediaType == MediaType.images) {
            return _buildImageGrid(provider.images);
          } else if (widget.mediaType == MediaType.videos) {
            return _buildVideoGrid(provider.videos);
          } else {
            return _buildAudioList(provider.audios);
          }
        },
      ),
    );
  }

  Widget _buildImageGrid(List<AssetEntity> images) {
    if (images.isEmpty) return const Center(child: Text('No images found'));
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final asset = images[index];
        return GestureDetector(
          onTap: () async {
            final file = await asset.file;
            if (file != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(imagePath: file.path),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
              future: asset.thumbnailDataWithSize(const ThumbnailSize.square(200)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }
                return Container(color: Colors.grey[300]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid(List<AssetEntity> videos) {
    if (videos.isEmpty) return const Center(child: Text('No videos found'));
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final asset = videos[index];
        return GestureDetector(
          onTap: () async {
            final file = await asset.file;
            if (file != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(videoPath: file.path),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FutureBuilder<Uint8List?>(
                  future: asset.thumbnailDataWithSize(const ThumbnailSize.square(200)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                      return Image.memory(snapshot.data!, fit: BoxFit.cover);
                    }
                    return Container(color: Colors.grey[900]);
                  },
                ),
              ),
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
              ),
              Positioned(
                bottom: 4,
                right: 8,
                child: Text(
                  _formatDuration(asset.duration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.black45,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAudioList(List<SongModel> audios) {
    if (audios.isEmpty) return const Center(child: Text('No audios found'));
    return ListView.builder(
      itemCount: audios.length,
      itemBuilder: (context, index) {
        final audio = audios[index];
        return ListTile(
          leading: QueryArtworkWidget(
            id: audio.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: const Icon(Icons.music_note, size: 40),
          ),
          title: Text(audio.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(audio.artist ?? "Unknown Artist"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AudioPlayerScreen(
                  audioPath: audio.data,
                  title: audio.title,
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(int seconds) {
    final d = Duration(seconds: seconds);
    final minutes = d.inMinutes;
    final remainingSeconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
