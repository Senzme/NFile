import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../models/file_item_model.dart';
import '../screens/all_recent_files_screen.dart';

class RecentFilesSection extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const RecentFilesSection({super.key, this.onNavigateTab});

  @override
  State<RecentFilesSection> createState() => _RecentFilesSectionState();
}

class _RecentFilesSectionState extends State<RecentFilesSection> {
  List<FileItemModel> _recentFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentFiles();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch MediaProvider & FileManagerProvider to trigger automated rebuild on any file operation
    context.watch<MediaProvider>();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final items = await _scanRecentFilesAsync(context);
      if (mounted) {
        setState(() {
          _recentFiles = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<FileItemModel>> _scanRecentFilesAsync(BuildContext context) async {
    final list = <FileSystemEntity>[];
    final seen = <String>{};

    final rootDir = Directory('/storage/emulated/0');
    if (await rootDir.exists()) {
      try {
        final List<String> pathsToScan = [];
        
        final rootEntities = await rootDir.list(recursive: false).toList();
        for (final entity in rootEntities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && name != 'Android') {
              pathsToScan.add(entity.path);
            }
          }
        }

        pathsToScan.addAll([
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
        ]);

        await Future.wait(pathsToScan.map((path) async {
          final dir = Directory(path);
          if (await dir.exists()) {
            try {
              final entities = await dir.list(recursive: false).toList();
              for (final entity in entities) {
                if (!seen.contains(entity.path)) {
                  seen.add(entity.path);
                  list.add(entity);
                }
                if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
                  try {
                    final subEntities = await entity.list(recursive: false).toList();
                    for (final sub in subEntities) {
                      if (!seen.contains(sub.path)) {
                        seen.add(sub.path);
                        list.add(sub);
                      }
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }));
      } catch (_) {}
    }

    final mediaProvider = context.read<MediaProvider>();

    void addFromMediaList(List<FileSystemEntity> mediaList) {
      for (final entity in mediaList) {
        if (!seen.contains(entity.path)) {
          seen.add(entity.path);
          list.add(entity);
        }
      }
    }

    addFromMediaList(mediaProvider.downloads);
    addFromMediaList(mediaProvider.documents);
    addFromMediaList(mediaProvider.archives);
    addFromMediaList(mediaProvider.apks);

    for (final song in mediaProvider.audios) {
      final path = song.data;
      if (!seen.contains(path)) {
        seen.add(path);
        try {
          final f = File(path);
          if (await f.exists()) list.add(f);
        } catch (_) {}
      }
    }

    final filteredList = <FileSystemEntity>[];
    for (final entity in list) {
      if (entity is Directory) {
        bool hasNestedChild = false;
        for (final other in list) {
          if (other.path != entity.path && p.isWithin(entity.path, other.path)) {
            hasNestedChild = true;
            break;
          }
        }
        if (hasNestedChild) {
          continue;
        }
      }
      filteredList.add(entity);
    }

    final items = <FileItemModel>[];
    await Future.wait(filteredList.map((f) async {
      try {
        final isDir = f is Directory;
        if (isDir) return;

        final name = p.basename(f.path);
        if (name.startsWith('.')) return;

        final stat = await f.stat();
        items.add(FileItemModel(
          entity: f,
          name: name,
          path: f.path,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
        ));
      } catch (_) {}
    }));

    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  String _getRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${time.day} ${months[time.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _recentFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<FileManagerProvider>();

    final displayFiles = _recentFiles.where((e) => !e.isDirectory).take(12).toList();

    if (displayFiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Files',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AllRecentFilesScreen(onNavigateTab: widget.onNavigateTab)),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Text(
                      'View All',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 135,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: displayFiles.length,
              itemBuilder: (context, index) {
                final file = displayFiles[index];
                final isFolder = file.isDirectory;
                final iconColor = isFolder ? theme.colorScheme.primary : FileUtils.getColorForFile(file.name, context);
                final iconData = isFolder 
                    ? FileUtils.getFolderIcon(provider.folderIconOption) 
                    : FileUtils.getIconForFile(file.name);

                return Container(
                  width: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF13131A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(51) : Colors.black.withAlpha(10),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: isDark ? Colors.white.withAlpha(13) : Colors.grey.withAlpha(26),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () {
                        if (isFolder) {
                          provider.loadDirectory(file.path);
                        } else {
                          provider.openFile(context, file.path);
                        }
                      },
                      onLongPress: () {
                        if (!isFolder) {
                          provider.showFileInLocation(file.path);
                          widget.onNavigateTab?.call(1);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: iconColor.withAlpha(25),
                      highlightColor: iconColor.withAlpha(13),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconColor.withAlpha(38),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: iconColor.withAlpha(25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 20),
                                ),
                                Icon(isFolder ? Broken.folder : Broken.document, size: 16, color: theme.dividerColor.withAlpha(51)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isFolder ? 'Folder' : FileUtils.formatBytes(file.size, 1),
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.textTheme.bodySmall?.color?.withAlpha(153)),
                                    ),
                                    Text(
                                      _getRelativeTime(file.modified),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 10,
                                        color: theme.colorScheme.primary.withAlpha(204),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
