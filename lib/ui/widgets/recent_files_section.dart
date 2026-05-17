import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';

class RecentFilesSection extends StatelessWidget {
  const RecentFilesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FileManagerProvider>();

    final files = provider.currentFiles.where((f) => !f.isDirectory).toList();
    files.sort((a, b) => b.modified.compareTo(a.modified));
    final recentFiles = files.take(8).toList();

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
                Text(
                  'Latest Modified',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: recentFiles.length,
              itemBuilder: (context, index) {
                final file = recentFiles[index];
                final iconColor = FileUtils.getColorForFile(file.name, context);

                return Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.dividerColor.withOpacity(0.1), width: 1.0),
                    ),
                    child: InkWell(
                      onTap: () => provider.openFile(context, file.path),
                      borderRadius: BorderRadius.circular(16),
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
                                    color: iconColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(FileUtils.getIconForFile(file.name), color: iconColor, size: 22),
                                ),
                                Icon(Broken.document, size: 16, color: theme.dividerColor.withOpacity(0.4)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  file.name,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      FileUtils.formatBytes(file.size, 1),
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                                    ),
                                    Text(
                                      FileUtils.formatDate(file.modified).split(',').first,
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
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
