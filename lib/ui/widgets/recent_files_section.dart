import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../models/file_item_model.dart';
import '../screens/all_recent_files_screen.dart';
import 'file_item.dart';

class RecentFilesSection extends StatelessWidget {
  final Function(int)? onNavigateTab;
  const RecentFilesSection({super.key, this.onNavigateTab});

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
    final mediaProvider = context.watch<MediaProvider>();
    final provider = context.watch<FileManagerProvider>();

    if (!provider.showRecentFiles) return const SizedBox.shrink();

    final isLoading = mediaProvider.isLoading && mediaProvider.recentFiles.isEmpty;
    final displayFiles = mediaProvider.recentFiles.where((e) => !e.isDirectory).take(12).toList();

    // If media has loaded and there are no files, hide the section entirely
    if (!isLoading && displayFiles.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                      MaterialPageRoute(builder: (_) => AllRecentFilesScreen(onNavigateTab: onNavigateTab)),
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
            child: isLoading
                ? _buildShimmer(isDark, theme)
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: displayFiles.length,
                    itemBuilder: (context, index) {
                      return _buildFileCard(context, displayFiles[index], isDark, theme, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer(bool isDark, ThemeData theme) {
    final baseColor = isDark ? const Color(0xFF1E1E2A) : const Color(0xFFE8E8EE);
    final highlightColor = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFF5F5FA);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _ShimmerCard(baseColor: baseColor, highlightColor: highlightColor);
      },
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    FileItemModel file,
    bool isDark,
    ThemeData theme,
    FileManagerProvider provider,
  ) {
    final isFolder = file.isDirectory;
    final iconColor = isFolder ? theme.colorScheme.primary : FileUtils.getColorForFile(file.name, context);

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
              onNavigateTab?.call(1);
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MediaThumbnail(
                          file: file,
                          iconScale: 0.8,
                          isSelected: false,
                          iconColor: iconColor,
                        ),
                      ),
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
  }
}

/// Animated shimmer skeleton card shown while media is loading for the first time
class _ShimmerCard extends StatefulWidget {
  final Color baseColor;
  final Color highlightColor;
  const _ShimmerCard({required this.baseColor, required this.highlightColor});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: 160,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: widget.baseColor.withAlpha(120), borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 11, width: 100, decoration: BoxDecoration(color: widget.baseColor.withAlpha(120), borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 6),
                    Container(height: 9, width: 60, decoration: BoxDecoration(color: widget.baseColor.withAlpha(80), borderRadius: BorderRadius.circular(6))),
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
