import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../providers/media_provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';
import 'image_viewer_screen.dart';
import 'video_player/video_player_screen.dart';
import 'audio_player/audio_player_screen.dart';
import 'document_viewer_screen.dart';
import '../../core/icon_fonts/broken_icons.dart';

enum MediaType { images, videos, audios, documents, archives, downloads, apks, screenshots }

class MediaCategoryScreen extends StatefulWidget {
  final MediaType mediaType;

  const MediaCategoryScreen({super.key, required this.mediaType});

  @override
  State<MediaCategoryScreen> createState() => _MediaCategoryScreenState();
}

class _MediaCategoryScreenState extends State<MediaCategoryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  Set<String> _selectedFilePaths = {};
  Set<String> _selectedAssetIds = {};

  bool get _isSelectionMode => _selectedFilePaths.isNotEmpty || _selectedAssetIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      case MediaType.archives:
        return 'Archives';
      case MediaType.downloads:
        return 'Downloads';
      case MediaType.apks:
        return 'APKs';
      case MediaType.screenshots:
        return 'Screenshots';
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
      case MediaType.archives:
        return Broken.archive;
      case MediaType.downloads:
        return Broken.document_download;
      case MediaType.apks:
        return Broken.box;
      case MediaType.screenshots:
        return Broken.mobile;
    }
  }

  void _toggleSelection(String? filePath, String? assetId) {
    setState(() {
      if (filePath != null && filePath.isNotEmpty) {
        if (_selectedFilePaths.contains(filePath)) {
          _selectedFilePaths.remove(filePath);
        } else {
          _selectedFilePaths.add(filePath);
        }
      }
      if (assetId != null && assetId.isNotEmpty) {
        if (_selectedAssetIds.contains(assetId)) {
          _selectedAssetIds.remove(assetId);
        } else {
          _selectedAssetIds.add(assetId);
        }
      }
    });
  }

  void _selectAll(MediaProvider provider) {
    final filePaths = <String>{};
    final assetIds = <String>{};

    if (widget.mediaType == MediaType.images) {
      assetIds.addAll(provider.images.map((e) => e.id));
    } else if (widget.mediaType == MediaType.videos) {
      assetIds.addAll(provider.videos.map((e) => e.id));
    } else if (widget.mediaType == MediaType.screenshots) {
      assetIds.addAll(provider.screenshots.map((e) => e.id));
    } else if (widget.mediaType == MediaType.audios) {
      filePaths.addAll(provider.audios.map((e) => e.data));
    } else if (widget.mediaType == MediaType.archives) {
      filePaths.addAll(provider.archives.map((e) => e.path));
    } else if (widget.mediaType == MediaType.downloads) {
      filePaths.addAll(provider.downloads.map((e) => e.path));
    } else if (widget.mediaType == MediaType.apks) {
      filePaths.addAll(provider.apks.map((e) => e.path));
    } else if (widget.mediaType == MediaType.documents) {
      filePaths.addAll(provider.documents.map((e) => e.path));
    }

    setState(() {
      _selectedFilePaths = filePaths;
      _selectedAssetIds = assetIds;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFilePaths.clear();
      _selectedAssetIds.clear();
    });
  }

  Future<void> _handleCopyCut(bool isCut) async {
    final paths = _selectedFilePaths.toList();
    if (_selectedAssetIds.isNotEmpty) {
      final provider = context.read<MediaProvider>();
      final allAssets = [...provider.images, ...provider.videos, ...provider.screenshots];
      for (final id in _selectedAssetIds) {
        final match = allAssets.where((a) => a.id == id).firstOrNull;
        if (match != null) {
          final f = await match.file;
          if (f != null) paths.add(f.path);
        }
      }
    }

    if (paths.isNotEmpty && mounted) {
      context.read<FileManagerProvider>().setClipboard(paths, isCut: isCut);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isCut ? 'Cut ${paths.length} items to clipboard' : 'Copied ${paths.length} items to clipboard')),
      );
      _clearSelection();
    }
  }

  Future<void> _handleDelete() async {
    final count = _selectedFilePaths.length + _selectedAssetIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete $count selected items?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final filePaths = _selectedFilePaths.toList();
      final assetIds = _selectedAssetIds.toList();

      if (_selectedAssetIds.isNotEmpty) {
        final provider = context.read<MediaProvider>();
        final allAssets = [...provider.images, ...provider.videos, ...provider.screenshots];
        for (final id in assetIds) {
          final match = allAssets.where((a) => a.id == id).firstOrNull;
          if (match != null) {
            final f = await match.file;
            if (f != null) filePaths.add(f.path);
          }
        }
      }

      await context.read<MediaProvider>().deleteMediaItems(filePaths: filePaths, assetIds: assetIds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully deleted $count items')));
        _clearSelection();
      }
    }
  }

  Future<void> _handlePaste() async {
    final fm = context.read<FileManagerProvider>();
    if (!fm.hasClipboard) return;

    String destDir = '/storage/emulated/0/Download';
    if (widget.mediaType == MediaType.documents) destDir = '/storage/emulated/0/Documents';
    if (widget.mediaType == MediaType.archives) destDir = '/storage/emulated/0/Download';
    if (widget.mediaType == MediaType.apks) destDir = '/storage/emulated/0/Download';

    final dir = Directory(destDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    int pastedCount = 0;
    for (final src in fm.clipboardPaths) {
      try {
        final f = File(src);
        if (f.existsSync()) {
          final target = '${dir.path}/${src.split('/').last}';
          if (fm.isCut) {
            f.renameSync(target);
          } else {
            f.copySync(target);
          }
          pastedCount++;
        }
      } catch (_) {}
    }

    fm.clearClipboard();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pasted $pastedCount items to $destDir')));
    await context.read<MediaProvider>().loadMedia(forceRefresh: true);
  }

  Widget _buildCopyableRow(String label, String value, BuildContext ctx) {
    if (value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(ctx);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Copied $label to clipboard'), duration: const Duration(seconds: 1)));
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary)),
              ),
              Expanded(
                flex: 7,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(value, style: const TextStyle(fontSize: 13), softWrap: true)),
                    const SizedBox(width: 4),
                    Icon(Broken.document_copy, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPropertiesDialog({String? singleFilePath, String? singleAssetId, String? explicitName}) async {
    final filePaths = singleFilePath != null ? [singleFilePath] : _selectedFilePaths.toList();
    final assetIds = singleAssetId != null ? [singleAssetId] : _selectedAssetIds.toList();

    int totalBytes = 0;
    int count = filePaths.length + assetIds.length;
    DateTime? lastMod;
    String nameDisplay = explicitName ?? '';
    String fullPath = '';
    String mimeType = '';
    String dimensionsOrDuration = '';
    String permissionsStr = '';

    if (assetIds.isNotEmpty) {
      final provider = context.read<MediaProvider>();
      final allAssets = [...provider.images, ...provider.videos, ...provider.screenshots];
      for (final id in assetIds) {
        final match = allAssets.where((a) => a.id == id).firstOrNull;
        if (match != null) {
          final f = await match.file;
          if (f != null) {
            if (count == 1) fullPath = f.path;
            if (count == 1 && nameDisplay.isEmpty) nameDisplay = f.path.split('/').last;
            try {
              final st = f.statSync();
              totalBytes += st.size;
              if (count == 1) {
                lastMod = st.modified;
                permissionsStr = '${(st.mode & 0x100) != 0 ? "R" : ""}${(st.mode & 0x80) != 0 ? "/W" : ""}';
              }
            } catch (_) {}
            if (count == 1) {
              if (match.type == AssetType.image) {
                dimensionsOrDuration = '${match.width} x ${match.height}';
                mimeType = match.mimeType ?? 'image/${f.path.split('.').last}';
              } else if (match.type == AssetType.video) {
                final d = Duration(seconds: match.duration);
                dimensionsOrDuration = '${match.width} x ${match.height} • ${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, "0")}';
                mimeType = match.mimeType ?? 'video/${f.path.split('.').last}';
              }
            }
          }
        }
      }
    }

    for (final p in filePaths) {
      if (count == 1 && nameDisplay.isEmpty) nameDisplay = p.split('/').last;
      if (count == 1) fullPath = p;
      try {
        final f = File(p);
        if (f.existsSync()) {
          final st = f.statSync();
          totalBytes += st.size;
          if (count == 1) {
            lastMod = st.modified;
            permissionsStr = '${(st.mode & 0x100) != 0 ? "R" : ""}${(st.mode & 0x80) != 0 ? "/W" : ""}';
            final ext = p.contains('.') ? p.substring(p.lastIndexOf('.')).toLowerCase() : '';
            if (widget.mediaType == MediaType.audios) mimeType = 'audio/$ext';
            else if (widget.mediaType == MediaType.apks) mimeType = 'application/vnd.android.package-archive';
            else if (widget.mediaType == MediaType.archives) mimeType = 'archive/$ext';
            else mimeType = 'file/$ext';
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Broken.info_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (count == 1) ...[
                _buildCopyableRow('Name', nameDisplay, ctx),
                _buildCopyableRow('Path', fullPath, ctx),
                _buildCopyableRow('Size', '${FileUtils.formatBytes(totalBytes, 2)} ($totalBytes bytes)', ctx),
                if (lastMod != null) _buildCopyableRow('Modified', FileUtils.formatDate(lastMod!), ctx),
                if (mimeType.isNotEmpty && mimeType != 'file/') _buildCopyableRow('Type', mimeType, ctx),
                if (dimensionsOrDuration.isNotEmpty) _buildCopyableRow('Media Info', dimensionsOrDuration, ctx),
                if (permissionsStr.isNotEmpty) _buildCopyableRow('Permissions', permissionsStr, ctx),
              ] else ...[
                _buildCopyableRow('Items Selected', '$count items', ctx),
                _buildCopyableRow('Total Size', '${FileUtils.formatBytes(totalBytes, 2)} ($totalBytes bytes)', ctx),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  void _showSingleItemOptions({required String name, String? filePath, String? assetId}) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Broken.document_copy, color: theme.colorScheme.primary),
                title: const Text('Copy'),
                onTap: () async {
                  Navigator.pop(ctx);
                  String? target = filePath;
                  if (assetId != null) {
                    final provider = context.read<MediaProvider>();
                    final allAssets = [...provider.images, ...provider.videos, ...provider.screenshots];
                    final match = allAssets.where((a) => a.id == assetId).firstOrNull;
                    if (match != null) {
                      final f = await match.file;
                      target = f?.path;
                    }
                  }
                  if (target != null && mounted) {
                    context.read<FileManagerProvider>().setClipboard([target], isCut: false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $name to clipboard')));
                  }
                },
              ),
              ListTile(
                leading: Icon(Broken.scissor, color: theme.colorScheme.primary),
                title: const Text('Cut'),
                onTap: () async {
                  Navigator.pop(ctx);
                  String? target = filePath;
                  if (assetId != null) {
                    final provider = context.read<MediaProvider>();
                    final allAssets = [...provider.images, ...provider.videos, ...provider.screenshots];
                    final match = allAssets.where((a) => a.id == assetId).firstOrNull;
                    if (match != null) {
                      final f = await match.file;
                      target = f?.path;
                    }
                  }
                  if (target != null && mounted) {
                    context.read<FileManagerProvider>().setClipboard([target], isCut: true);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cut $name to clipboard')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Broken.trash, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Confirm Deletion'),
                      content: Text('Permanently delete "$name"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    List<String> files = [];
                    if (filePath != null) files.add(filePath);
                    if (assetId != null) {
                      final provider = context.read<MediaProvider>();
                      final allAssets = [...provider.images, ...provider.videos, ...provider.screenshots];
                      final match = allAssets.where((a) => a.id == assetId).firstOrNull;
                      if (match != null) {
                        final f = await match.file;
                        if (f != null) files.add(f.path);
                      }
                    }
                    await context.read<MediaProvider>().deleteMediaItems(filePaths: files, assetIds: assetId != null ? [assetId] : []);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted $name')));
                    }
                  }
                },
              ),
              ListTile(
                leading: Icon(Broken.info_circle, color: theme.colorScheme.primary),
                title: const Text('Properties'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPropertiesDialog(singleFilePath: filePath, singleAssetId: assetId, explicitName: name);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fm = context.watch<FileManagerProvider>();
    final canPaste = (widget.mediaType == MediaType.downloads || widget.mediaType == MediaType.documents || widget.mediaType == MediaType.archives || widget.mediaType == MediaType.apks) && fm.hasClipboard;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedFilePaths.length + _selectedAssetIds.length} Selected' : _title),
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Broken.close_square), onPressed: _clearSelection)
            : null,
        actions: [
          if (_isSelectionMode)
            Consumer<MediaProvider>(
              builder: (context, provider, child) => IconButton(
                icon: const Icon(Broken.task_square),
                tooltip: 'Select All',
                onPressed: () => _selectAll(provider),
              ),
            )
          else ...[
            if (canPaste)
              IconButton(
                icon: const Icon(Broken.clipboard),
                tooltip: 'Paste Here',
                onPressed: _handlePaste,
              ),
            Consumer<MediaProvider>(
              builder: (context, provider, child) {
                return PopupMenuButton<MediaSortOrder>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort Options',
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
        ],
      ),
      body: Consumer<MediaProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && !provider.isLoaded) {
            return _buildShimmerLoading(theme);
          }

          final isDateWise = provider.sortOrder == MediaSortOrder.dateWise;

          if (widget.mediaType == MediaType.images) {
            return _buildImageGrid(provider.images, theme, isDateWise);
          } else if (widget.mediaType == MediaType.videos) {
            return _buildVideoGrid(provider.videos, theme, isDateWise);
          } else if (widget.mediaType == MediaType.audios) {
            return _buildAudioList(provider.audios, theme, isDateWise);
          } else if (widget.mediaType == MediaType.screenshots) {
            return _buildImageGrid(provider.screenshots, theme, isDateWise);
          } else if (widget.mediaType == MediaType.archives) {
            return _buildGenericFileList(provider.archives, theme, isDateWise);
          } else if (widget.mediaType == MediaType.downloads) {
            return _buildGenericFileList(provider.downloads, theme, isDateWise);
          } else if (widget.mediaType == MediaType.apks) {
            return _buildGenericFileList(provider.apks, theme, isDateWise);
          } else {
            return _buildDocumentList(provider.documents, theme, isDateWise);
          }
        },
      ),
      bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar(theme) : null,
    );
  }

  Widget _buildBottomActionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionItem(theme, icon: Broken.document_copy, label: 'Copy', onTap: () => _handleCopyCut(false)),
            _buildActionItem(theme, icon: Broken.scissor, label: 'Cut', onTap: () => _handleCopyCut(true)),
            _buildActionItem(theme, icon: Broken.trash, label: 'Delete', color: Colors.red, onTap: _handleDelete),
            _buildActionItem(theme, icon: Broken.info_circle, label: 'Info', onTap: () => _showPropertiesDialog()),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(ThemeData theme, {required IconData icon, required String label, required VoidCallback onTap, Color? color}) {
    final c = color ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: c, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE0E0E0);
    final highlightColor = isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemCount: 24,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ShaderMask(
                shaderCallback: (rect) => LinearGradient(
                  colors: [baseColor, highlightColor, baseColor],
                  stops: [0.0, _shimmerController.value, 1.0],
                ).createShader(rect),
                child: Container(color: baseColor),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageGrid(List<AssetEntity> images, ThemeData theme, bool isDateWise) {
    if (images.isEmpty) return _buildEmptyState(theme);
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final asset = images[index];
        final isSelected = _selectedAssetIds.contains(asset.id);
        final dateStr = FileUtils.formatDate(asset.createDateTime);

        return Stack(
          key: ValueKey(asset.id),
          fit: StackFit.expand,
          children: [
            _CachedImageTile(
              asset: asset,
              onTap: () async {
                if (_isSelectionMode) {
                  _toggleSelection(null, asset.id);
                } else {
                  final file = await asset.file;
                  if (file != null && context.mounted) {
                    Navigator.push(context, _slideRoute(ImageViewerScreen(
                      imagePath: file.path,
                      siblingAssets: images,
                      initialAssetId: asset.id,
                    )));
                  }
                }
              },
              onLongPress: () => _toggleSelection(null, asset.id),
            ),
            if (isDateWise)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    dateStr.split(',').first,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (_isSelectionMode || isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  isSelected ? Broken.tick_square : Icons.check_box_outline_blank,
                  color: isSelected ? theme.colorScheme.primary : Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              )
            else
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () async {
                    final f = await asset.file;
                    if (f != null) {
                      _showSingleItemOptions(name: asset.title ?? 'Image_${asset.id}', filePath: f.path, assetId: asset.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: const Icon(Broken.more, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildVideoGrid(List<AssetEntity> videos, ThemeData theme, bool isDateWise) {
    if (videos.isEmpty) return _buildEmptyState(theme);
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final asset = videos[index];
        final isSelected = _selectedAssetIds.contains(asset.id);
        final dateStr = FileUtils.formatDate(asset.createDateTime);

        return Stack(
          key: ValueKey(asset.id),
          fit: StackFit.expand,
          children: [
            _CachedVideoTile(
              asset: asset,
              onTap: () async {
                if (_isSelectionMode) {
                  _toggleSelection(null, asset.id);
                } else {
                  final file = await asset.file;
                  if (file != null && context.mounted) {
                    Navigator.push(context, _slideRoute(VideoPlayerScreen(videoPath: file.path)));
                  }
                }
              },
              onLongPress: () => _toggleSelection(null, asset.id),
            ),
            if (isDateWise)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    dateStr.split(',').first,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (_isSelectionMode || isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  isSelected ? Broken.tick_square : Icons.check_box_outline_blank,
                  color: isSelected ? theme.colorScheme.primary : Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              )
            else
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () async {
                    final f = await asset.file;
                    if (f != null) {
                      _showSingleItemOptions(name: asset.title ?? 'Video_${asset.id}', filePath: f.path, assetId: asset.id);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                    child: const Icon(Broken.more, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAudioList(List<SongModel> audios, ThemeData theme, bool isDateWise) {
    if (audios.isEmpty) return _buildEmptyState(theme);
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: audios.length,
      itemBuilder: (context, index) {
        final audio = audios[index];
        final path = audio.data;
        final isSelected = _selectedFilePaths.contains(path);
        DateTime? modified;
        try {
          modified = File(path).statSync().modified;
        } catch (_) {}
        final dateStr = modified != null ? FileUtils.formatDate(modified) : 'Unknown Date';

        return ListTile(
          key: ValueKey(path),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(path, null);
            } else {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => AudioPlayerScreen(
                    audioPath: path,
                    title: audio.title,
                    artist: audio.artist ?? 'Unknown Artist',
                    allSongs: audios,
                    initialIndex: index,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) => SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: child,
                  ),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              );
            }
          },
          onLongPress: () => _toggleSelection(path, null),
          leading: Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: theme.colorScheme.primaryContainer),
                child: QueryArtworkWidget(
                  id: audio.id,
                  type: ArtworkType.AUDIO,
                  artworkBorder: BorderRadius.circular(10),
                  artworkFit: BoxFit.cover,
                  artworkWidth: 50,
                  artworkHeight: 50,
                  nullArtworkWidget: Icon(Icons.music_note, size: 26, color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              if (_isSelectionMode || isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                    child: Icon(isSelected ? Broken.tick_square : Icons.check_box_outline_blank, color: isSelected ? theme.colorScheme.primary : Colors.grey, size: 20),
                  ),
                ),
            ],
          ),
          title: Text(audio.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(
            isDateWise
                ? '${audio.artist ?? "Unknown Artist"} • $dateStr'
                : audio.artist ?? "Unknown Artist",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.55), fontSize: 11),
          ),
          trailing: _isSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(Broken.more),
                  onPressed: () => _showSingleItemOptions(name: audio.title, filePath: path),
                ),
        );
      },
    );
  }

  Widget _buildDocumentList(List<FileSystemEntity> documents, ThemeData theme, bool isDateWise) {
    if (documents.isEmpty) return _buildEmptyState(theme);
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final path = doc.path;
        final name = path.split('/').last;
        final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')).toLowerCase() : '';
        final icon = _docIcon(ext);
        final color = _docColor(ext);
        final isSelected = _selectedFilePaths.contains(path);

        int size = 0;
        DateTime modified = DateTime.now();
        try {
          final st = doc.statSync();
          size = st.size;
          modified = st.modified;
        } catch (_) {}

        return ListTile(
          key: ValueKey(path),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(path, null);
            } else {
              Navigator.push(context, _slideRoute(DocumentViewerScreen(filePath: path)));
            }
          },
          onLongPress: () => _toggleSelection(path, null),
          leading: Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              if (_isSelectionMode || isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                    child: Icon(isSelected ? Broken.tick_square : Icons.check_box_outline_blank, color: isSelected ? theme.colorScheme.primary : Colors.grey, size: 20),
                  ),
                ),
            ],
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            isDateWise
                ? '${FileUtils.formatBytes(size, 1)} • ${FileUtils.formatDate(modified)}'
                : FileUtils.formatBytes(size, 1),
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11),
          ),
          trailing: _isSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(Broken.more),
                  onPressed: () => _showSingleItemOptions(name: name, filePath: path),
                ),
        );
      },
    );
  }

  Widget _buildGenericFileList(List<FileSystemEntity> files, ThemeData theme, bool isDateWise) {
    if (files.isEmpty) return _buildEmptyState(theme);
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final path = file.path;
        final name = path.split('/').last;
        final isSelected = _selectedFilePaths.contains(path);

        int size = 0;
        DateTime modified = DateTime.now();
        try {
          final st = file.statSync();
          size = st.size;
          modified = st.modified;
        } catch (_) {}
        final iconColor = FileUtils.getColorForFile(name, context);

        return ListTile(
          key: ValueKey(path),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(path, null);
            } else {
              context.read<FileManagerProvider>().openFile(context, path);
            }
          },
          onLongPress: () => _toggleSelection(path, null),
          leading: Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: iconColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(FileUtils.getIconForFile(name), color: iconColor, size: 22),
              ),
              if (_isSelectionMode || isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
                    child: Icon(isSelected ? Broken.tick_square : Icons.check_box_outline_blank, color: isSelected ? theme.colorScheme.primary : Colors.grey, size: 20),
                  ),
                ),
            ],
          ),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            isDateWise
                ? '${FileUtils.formatBytes(size, 1)} • ${FileUtils.formatDate(modified)}'
                : FileUtils.formatBytes(size, 1),
            style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 11),
          ),
          trailing: _isSelectionMode
              ? null
              : IconButton(
                  icon: const Icon(Broken.more),
                  onPressed: () => _showSingleItemOptions(name: name, filePath: path),
                ),
        );
      },
    );
  }

  IconData _docIcon(String ext) {
    switch (ext) {
      case '.pdf': return Broken.document;
      case '.doc': case '.docx': case '.xls': case '.xlsx': return Broken.document_text;
      case '.ppt': case '.pptx': return Broken.presention_chart;
      case '.txt': return Broken.note_2;
      default: return Broken.document;
    }
  }

  Color _docColor(String ext) {
    switch (ext) {
      case '.pdf': return Colors.redAccent;
      case '.doc': case '.docx': return Colors.blueAccent;
      case '.xls': case '.xlsx': return Colors.green;
      case '.ppt': case '.pptx': return Colors.orangeAccent;
      case '.txt': return Colors.purpleAccent;
      default: return Colors.teal;
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_emptyIcon, size: 72, color: theme.colorScheme.onSurface.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('No ${_title.toLowerCase()} found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 16)),
        ],
      ),
    );
  }

  PageRoute _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

class _ThumbnailShimmerPlaceholder extends StatefulWidget {
  const _ThumbnailShimmerPlaceholder({super.key});

  @override
  State<_ThumbnailShimmerPlaceholder> createState() => _ThumbnailShimmerPlaceholderState();
}

class _ThumbnailShimmerPlaceholderState extends State<_ThumbnailShimmerPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
      builder: (context, child) => ShaderMask(
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [0.0, _controller.value, 1.0],
        ).createShader(rect),
        child: Container(color: baseColor),
      ),
    );
  }
}

class _CachedImageTile extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CachedImageTile({required this.asset, required this.onTap, required this.onLongPress});

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
  void didUpdateWidget(covariant _CachedImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loaded = false;
      _thumbnail = null;
      _loadThumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
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

class _CachedVideoTile extends StatefulWidget {
  final AssetEntity asset;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CachedVideoTile({required this.asset, required this.onTap, required this.onLongPress});

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
  void didUpdateWidget(covariant _CachedVideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _loaded = false;
      _thumbnail = null;
      _loadThumbnail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.5)]),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _formatDuration(widget.asset.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
