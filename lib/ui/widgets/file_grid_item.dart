import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/file_item_model.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/media_provider.dart';
import '../../providers/file_manager_provider.dart';

class FileGridItem extends StatelessWidget {
  final FileItemModel file;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(String) onAction;
  final bool isSelected;
  final double iconScale;
  final double itemPaddingMultiplier;

  const FileGridItem({
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
      (p) => p.highlightedPaths.contains(file.path),
    );

    final child = Card(
      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.1),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: (8.0 * itemPaddingMultiplier).clamp(2.0, 16.0),
                    vertical: (8.0 * itemPaddingMultiplier).clamp(2.0, 16.0),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onLongPress,
                        child: Container(
                          width: 48 * iconScale,
                          height: 48 * iconScale,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _MediaThumbnail(
                              file: file,
                              iconScale: iconScale,
                              isSelected: isSelected,
                              iconColor: iconColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        file.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5 * (1 + (iconScale - 1) * 0.3),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatBytes(file.size, 1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Broken.tick_circle, size: 16, color: theme.colorScheme.onPrimary),
                ),
              )
            else
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Broken.more, size: 20),
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
              ),
          ],
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
                margin: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
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

  @override
  void initState() {
    super.initState();
    if (FileUtils.isVideo(widget.file.path)) {
      _loadVideoThumb();
    }
  }

  Future<void> _loadVideoThumb() async {
    if (!mounted) return;
    final mediaProvider = context.read<MediaProvider>();
    final match = mediaProvider.videos.where((v) => v.title == widget.file.name || '${v.title}.${v.mimeType?.split("/").last}' == widget.file.name).firstOrNull;
    if (match != null) {
      final thumb = await ThumbnailCache.get(match);
      if (mounted && thumb != null) {
        setState(() {
          _videoThumb = thumb;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showMediaPreviews = context.watch<FileManagerProvider>().showMediaPreviews;
    final isImg = FileUtils.isImage(widget.file.path);
    final isVid = FileUtils.isVideo(widget.file.path);

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

    if (isImg) {
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
          Image.memory(_videoThumb!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
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

    return Icon(
      FileUtils.getIconForFile(widget.file.path),
      color: widget.iconColor,
      size: 28 * widget.iconScale,
    );
  }
}
