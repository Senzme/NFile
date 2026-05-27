import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_avif/flutter_avif.dart';
import '../../models/file_item_model.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/media_provider.dart';
import '../../providers/file_manager_provider.dart';
import 'package:on_audio_query/on_audio_query.dart';

class FileItem extends StatelessWidget {
  final FileItemModel file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(String) onAction;
  final bool isSelected;
  final double iconScale;
  final double itemPaddingMultiplier;

  const FileItem({
    super.key,
    required this.file,
    required this.onTap,
    this.onLongPress,
    required this.onAction,
    this.isSelected = false,
    this.iconScale = 1.0,
    this.itemPaddingMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = FileUtils.getColorForFile(file.path, context);
    final isArchive = FileUtils.isArchive(file.path);
    final isHighlighted = context.select<FileManagerProvider, bool>(
      (p) => p.enableFolderHighlight && p.highlightedPaths.contains(file.path),
    );

    final cardMargin = EdgeInsets.symmetric(
      horizontal: (16 * itemPaddingMultiplier).clamp(4.0, 32.0),
      vertical: (4 * itemPaddingMultiplier).clamp(1.0, 16.0),
    );

    final child = Card(
      margin: cardMargin,
      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.1),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all((12.0 * itemPaddingMultiplier).clamp(4.0, 24.0)),
          child: Row(
            children: [
              GestureDetector(
                onTap: onLongPress,
                child: Container(
                  width: 48 * iconScale,
                  height: 48 * iconScale,
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _MediaThumbnail(
                      file: file,
                      iconScale: iconScale,
                      isSelected: isSelected,
                      iconColor: iconColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15 * (1 + (iconScale - 1) * 0.3),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Consumer<FileManagerProvider>(
                      builder: (context, provider, _) {
                        return Row(
                          children: [
                            if (!provider.hideTimeAndDate) ...[
                              Text(
                                FileUtils.formatDate(file.modified, use24Hour: provider.use24HourFormat),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Text(
                              FileUtils.formatBytes(file.size, 2),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Broken.more, size: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                position: PopupMenuPosition.under,
                elevation: 8,
                onSelected: onAction,
                itemBuilder: (context) => [
                  if (isArchive)
                    const PopupMenuItem(value: 'extract', child: Row(children: [Icon(Broken.archive, size: 20), SizedBox(width: 12), Text('Extract', style: TextStyle(fontWeight: FontWeight.w500))])),
                  const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Broken.box_add, size: 20), SizedBox(width: 12), Text('Archive', style: TextStyle(fontWeight: FontWeight.w500))])),
                  const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Broken.document_copy, size: 20), SizedBox(width: 12), Text('Copy', style: TextStyle(fontWeight: FontWeight.w500))])),
                  const PopupMenuItem(value: 'cut', child: Row(children: [Icon(Broken.scissor, size: 20), SizedBox(width: 12), Text('Cut', style: TextStyle(fontWeight: FontWeight.w500))])),
                  const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Broken.edit, size: 20), SizedBox(width: 12), Text('Rename', style: TextStyle(fontWeight: FontWeight.w500))])),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Broken.trash, size: 20, color: Colors.redAccent), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500))]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: isHighlighted ? 1.0 : 0.0,
              child: Container(
                margin: cardMargin,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MediaThumbnail extends StatefulWidget {
  final FileItemModel file;
  final double iconScale;
  final bool isSelected;
  final Color iconColor;

  const _MediaThumbnail({
    required this.file,
    required this.iconScale,
    required this.isSelected,
    required this.iconColor,
  });

  @override
  State<_MediaThumbnail> createState() => _MediaThumbnailState();
}

class _MediaThumbnailState extends State<_MediaThumbnail> {
  Uint8List? _videoThumb;
  Uint8List? _audioThumb;

  @override
  void initState() {
    super.initState();
    if (FileUtils.isVideo(widget.file.path)) {
      _loadVideoThumb();
    } else if (FileUtils.isAudio(widget.file.path)) {
      _loadAudioThumb();
    }
  }

  Future<void> _loadAudioThumb() async {
    if (!mounted) return;
    try {
      final mediaProvider = context.read<MediaProvider>();
      final match = mediaProvider.audios.where((s) => s.data == widget.file.path).firstOrNull;
      if (match != null) {
        final artwork = await OnAudioQuery().queryArtwork(
          match.id,
          ArtworkType.AUDIO,
          size: 200,
          quality: 60,
        );
        if (mounted && artwork != null && artwork.isNotEmpty) {
          setState(() {
            _audioThumb = artwork;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVideoThumb() async {
    if (!mounted) return;
    try {
      final mediaProvider = context.read<MediaProvider>();
      final match = mediaProvider.videos.where((v) {
        final titleLower = (v.title ?? '').toLowerCase();
        final nameLower = widget.file.name.toLowerCase();
        
        // Case 1: title matches filename exactly
        if (titleLower == nameLower) return true;
        
        // Case 2: title is basename without extension, e.g. title="my_video", filename="my_video.mp4"
        final extIndex = nameLower.lastIndexOf('.');
        final ext = extIndex != -1 ? nameLower.substring(extIndex) : '';
        if (ext.isNotEmpty) {
          final baseName = nameLower.substring(0, extIndex);
          if (titleLower == baseName || '${titleLower}${ext}' == nameLower) {
            return true;
          }
        }
        
        // Case 3: Match via mimeType
        final mimeExt = v.mimeType?.split("/").last.toLowerCase();
        if (mimeExt != null && '${titleLower}.$mimeExt' == nameLower) {
          return true;
        }
        
        return false;
      }).firstOrNull;

      if (match != null) {
        final thumb = await ThumbnailCache.get(match);
        if (mounted && thumb != null) {
          setState(() {
            _videoThumb = thumb;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final showMediaPreviews = context.select<FileManagerProvider, bool>((p) => p.showMediaPreviews);
    final isImg = FileUtils.isImage(widget.file.path);
    final isVid = FileUtils.isVideo(widget.file.path);
    final isAud = FileUtils.isAudio(widget.file.path);

    if (widget.isSelected) {
      return Icon(Broken.tick_circle, color: Theme.of(context).colorScheme.onPrimary, size: 28 * widget.iconScale);
    }

    if (!showMediaPreviews) {
      return Icon(
        FileUtils.getIconForFile(widget.file.path),
        color: widget.iconColor,
        size: 28 * widget.iconScale,
      );
    }

    if (isImg && widget.file.size > 16) {
      if (widget.file.path.toLowerCase().endsWith('.avif')) {
        return AvifImage.file(
          File(widget.file.path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Icon(Broken.image, color: widget.iconColor, size: 28 * widget.iconScale),
        );
      }
      return Image.file(
        File(widget.file.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 160,
        errorBuilder: (context, error, stackTrace) => Icon(Broken.image, color: widget.iconColor, size: 28 * widget.iconScale),
      );
    }

    if (isVid && _videoThumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _videoThumb!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Icon(Broken.video, color: widget.iconColor, size: 28 * widget.iconScale),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: Icon(Broken.video, color: Colors.white, size: 16 * widget.iconScale),
            ),
          ),
        ],
      );
    }

    if (isAud && _audioThumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _audioThumb!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Icon(Broken.music, color: widget.iconColor, size: 28 * widget.iconScale),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: Icon(Broken.music, color: Colors.white, size: 16 * widget.iconScale),
            ),
          ),
        ],
      );
    }

    return Icon(
      FileUtils.getIconForFile(widget.file.path),
      color: widget.iconColor,
      size: 28 * widget.iconScale,
    );
  }
}
