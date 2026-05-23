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

class RecentFilesSection extends StatelessWidget {
  const RecentFilesSection({super.key});

  List<FileItemModel> _scanRecentFilesSync(BuildContext context) {
    final list = <File>[];
    final seen = <String>{};

    final rootDir = Directory('/storage/emulated/0');
    if (rootDir.existsSync()) {
      try {
        final List<String> pathsToScan = [];
        
        // Find all non-hidden directories under root storage
        final rootEntities = rootDir.listSync(recursive: false);
        for (final entity in rootEntities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && name != 'Android') {
              pathsToScan.add(entity.path);
            }
          }
        }

        // Add specific key folders
        pathsToScan.addAll([
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
        ]);

        // Flat synchronous list of root-level directories to catch all copy/pastes and creations
        for (final path in pathsToScan) {
          final dir = Directory(path);
          if (dir.existsSync()) {
            try {
              final entities = dir.listSync(recursive: false);
              for (final entity in entities) {
                if (entity is File && !seen.contains(entity.path)) {
                  seen.add(entity.path);
                  list.add(entity);
                } else if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
                  // Scan 1 level deep inside subfolders to catch subfolder creations/copies
                  try {
                    final subEntities = entity.listSync(recursive: false);
                    for (final sub in subEntities) {
                      if (sub is File && !seen.contains(sub.path)) {
                        seen.add(sub.path);
                        list.add(sub);
                      }
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    final mediaProvider = context.read<MediaProvider>();

    void addFromMediaList(List<FileSystemEntity> mediaList) {
      for (final entity in mediaList) {
        if (entity is File && !seen.contains(entity.path)) {
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
          if (f.existsSync()) list.add(f);
        } catch (_) {}
      }
    }

    final items = <FileItemModel>[];
    for (final f in list) {
      try {
        final stat = f.statSync();
        items.add(FileItemModel(
          entity: f,
          name: p.basename(f.path),
          path: f.path,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
        ));
      } catch (_) {}
    }

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<FileManagerProvider>();
    
    // Watch MediaProvider & FileManagerProvider to trigger automated rebuild on any file operation (paste/delete/copy/rename)
    context.watch<MediaProvider>();

    final recentFiles = _scanRecentFilesSync(context).take(12).toList();

    if (recentFiles.isEmpty) return const SizedBox.shrink();

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
                      MaterialPageRoute(builder: (_) => const AllRecentFilesScreen()),
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
              itemCount: recentFiles.length,
              itemBuilder: (context, index) {
                final file = recentFiles[index];
                final iconColor = FileUtils.getColorForFile(file.name, context);

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
                      onTap: () => provider.openFile(context, file.path),
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
                                  child: Icon(FileUtils.getIconForFile(file.name), color: iconColor, size: 20),
                                ),
                                Icon(Broken.document, size: 16, color: theme.dividerColor.withAlpha(51)),
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
                                      FileUtils.formatBytes(file.size, 1),
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
