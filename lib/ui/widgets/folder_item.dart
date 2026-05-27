import 'package:flutter/material.dart';
import '../../models/file_item_model.dart';
import '../../models/file_filter_type.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../services/pin_service.dart';

class FolderItem extends StatelessWidget {
  final FileItemModel folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(String) onAction;
  final bool isSelected;
  final double iconScale;
  final double itemPaddingMultiplier;

  const FolderItem({
    super.key,
    required this.folder,
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
    final isHighlighted = context.select<FileManagerProvider, bool>(
      (p) => p.enableFolderHighlight && p.highlightedPaths.contains(folder.path),
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
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? Broken.tick_circle : FileUtils.getFolderIcon(context.select<FileManagerProvider, String>((p) => p.folderIconOption)),
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                    size: 28 * iconScale,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (PinService.isPinned(folder.path)) ...[
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14 * (1 + (iconScale - 1) * 0.3),
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            folder.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15 * (1 + (iconScale - 1) * 0.3),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Consumer<FileManagerProvider>(
                      builder: (context, provider, _) {
                        final activeFilter = provider.filterType;
                        if (activeFilter != FileFilterType.all) {
                          return FutureBuilder<int>(
                            future: provider.getMatchingFileCount(folder.path, activeFilter),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              final name = provider.getFilterTypeName(activeFilter, count);
                              return Text(
                                '$count $name',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          );
                        } else {
                          if (provider.hideTimeAndDate && !provider.showFolderContentsCount) {
                            return const SizedBox.shrink();
                          }
                          if (provider.showFolderContentsCount) {
                            return FutureBuilder<int>(
                              future: provider.getFolderItemCount(folder.path),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                final countStr = count == 1 ? '1 item' : '$count items';
                                if (provider.hideTimeAndDate) {
                                  return Text(
                                    countStr,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                } else {
                                  return Text(
                                    '$countStr • ${FileUtils.formatDate(folder.modified, use24Hour: provider.use24HourFormat)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }
                              },
                            );
                          } else {
                            return Text(
                              FileUtils.formatDate(folder.modified, use24Hour: provider.use24HourFormat),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                              ),
                            );
                          }
                        }
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
                itemBuilder: (context) {
                  return [
                    const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Broken.box_add, size: 20), SizedBox(width: 12), Text('Archive', style: TextStyle(fontWeight: FontWeight.w500))])),
                    const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Broken.document_copy, size: 20), SizedBox(width: 12), Text('Copy', style: TextStyle(fontWeight: FontWeight.w500))])),
                    const PopupMenuItem(value: 'cut', child: Row(children: [Icon(Broken.scissor, size: 20), SizedBox(width: 12), Text('Cut', style: TextStyle(fontWeight: FontWeight.w500))])),
                    const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Broken.edit, size: 20), SizedBox(width: 12), Text('Rename', style: TextStyle(fontWeight: FontWeight.w500))])),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Broken.trash, size: 20, color: Colors.redAccent), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500))]),
                    ),
                  ];
                },
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
