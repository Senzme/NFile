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
  const RecentFilesSection({super.key});

  @override
  State<RecentFilesSection> createState() => _RecentFilesSectionState();
}

class _RecentFilesSectionState extends State<RecentFilesSection> {
  List<FileItemModel> _recentFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    if (!mounted) return;
    try {
      final items = await _scanRecentFiles();
      if (mounted) {
        setState(() {
          _recentFiles = items.take(12).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<FileItemModel>> _scanRecentFiles() async {
    final list = <File>[];
    final folders = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Pictures/Screenshots',
      '/storage/emulated/0/Pictures',
    ];

    for (final path in folders) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        try {
          await for (final entity in dir.list(recursive: false)) {
            if (entity is File) {
              list.add(entity);
            } else if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
              try {
                await for (final subEntity in entity.list(recursive: false)) {
                  if (subEntity is File) {
                    list.add(subEntity);
                  }
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    }

    final mediaProvider = context.read<MediaProvider>();
    final seen = list.map((f) => f.path).toSet();

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

    if (!_isLoading && _recentFiles.isEmpty) return const SizedBox.shrink();

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
                    ).then((_) => _loadRecentFiles()); // Reload on return
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
            child: _isLoading
                ? _buildShimmerLoader(theme, isDark)
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = _recentFiles[index];
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

  Widget _buildShimmerLoader(ThemeData theme, bool isDark) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          width: 160,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2C).withAlpha(127) : Colors.grey.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const CircleAvatar(backgroundColor: Colors.grey, radius: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: 100, color: Colors.grey),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(height: 8, width: 40, color: Colors.grey),
                        Container(height: 8, width: 40, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
