import 'package:flutter/material.dart';
import '../../models/file_item_model.dart';
import '../../models/file_filter_type.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../services/pin_service.dart';
import '../../services/app_manager_service.dart';
import 'package:path/path.dart' as p;
import 'dart:typed_data';

class FolderGridItem extends StatelessWidget {
  final FileItemModel folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onIconTap;
  final Function(String) onAction;
  final bool isSelected;
  final double iconScale;
  final double itemPaddingMultiplier;

  const FolderGridItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.onIconTap,
    required this.onAction,
    this.isSelected = false,
    this.iconScale = 1.0,
    this.itemPaddingMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHighlighted = context.select<FileManagerProvider, bool>(
      (p) => p.forceHighlightedPaths.contains(folder.path) || (p.enableFolderHighlight && p.highlightedPaths.contains(folder.path)),
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
                        onTap: onIconTap ?? onLongPress,
                        child: Container(
                          width: 48 * iconScale,
                          height: 48 * iconScale,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: (() {
                            final parentPath = p.dirname(folder.path).toLowerCase();
                            final isPackageFolder = parentPath.endsWith('/android/data') || parentPath.endsWith('/android/obb') || parentPath.endsWith(r'\android\data') || parentPath.endsWith(r'\android\obb');

                            if (isPackageFolder && !isSelected) {
                              return FutureBuilder<Uint8List?>(
                                future: AppManagerService.getAppIcon(folder.name),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                    return Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          snapshot.data!,
                                          width: 38 * iconScale,
                                          height: 38 * iconScale,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            FileUtils.getFolderIcon(context.select<FileManagerProvider, String>((p) => p.folderIconOption)),
                                            color: theme.colorScheme.primary,
                                            size: 28 * iconScale,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Icon(
                                    FileUtils.getFolderIcon(context.select<FileManagerProvider, String>((p) => p.folderIconOption)),
                                    color: theme.colorScheme.primary,
                                    size: 28 * iconScale,
                                  );
                                },
                              );
                            }

                            return Icon(
                              isSelected ? Broken.tick_circle : FileUtils.getFolderIcon(context.select<FileManagerProvider, String>((p) => p.folderIconOption)),
                              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                              size: 28 * iconScale,
                            );
                          })(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (PinService.isPinned(folder.path)) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 12 * (1 + (iconScale - 1) * 0.3),
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              folder.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13 * (1 + (iconScale - 1) * 0.3),
                              ),
                              maxLines: context.select<FileManagerProvider, bool>((p) => p.adaptiveMultiLineNames) ? 3 : 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
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
                                    fontSize: 10 * (1 + (iconScale - 1) * 0.2),
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            );
                          } else {
                            if (provider.hideTimeAndDate && !provider.showFolderContentsCount && !provider.showFolderSizes) {
                              return const SizedBox.shrink();
                            }
                            return FutureBuilder<List<int>>(
                              future: Future.wait([
                                provider.showFolderContentsCount ? provider.getFolderItemCount(folder.path) : Future.value(-1),
                                provider.showFolderSizes ? provider.getFolderSize(folder.path) : Future.value(-1),
                              ]),
                              builder: (context, snapshot) {
                                final data = snapshot.data;
                                final count = (data != null && data[0] != -1) ? data[0] : null;
                                final size = (data != null && data[1] != -1) ? data[1] : null;

                                final parts = <String>[];
                                if (count != null) {
                                  parts.add(count == 1 ? '1 item' : '$count items');
                                }
                                if (size != null) {
                                  parts.add(FileUtils.formatBytes(size, 1));
                                }
                                if (!provider.hideTimeAndDate) {
                                  parts.add(FileUtils.formatDate(folder.modified, use24Hour: provider.use24HourFormat));
                                }

                                if (parts.isEmpty) return const SizedBox.shrink();

                                return Text(
                                  parts.join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10 * (1 + (iconScale - 1) * 0.2),
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            );
                          }
                        },
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
            else if (PinService.isPinned(folder.path))
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.push_pin_rounded, size: 12, color: Colors.white),
                ),
              ),
            if (!isSelected && !context.select<FileManagerProvider, bool>((p) => p.hideActionMenuButtons))
              Positioned(
                top: 4,
                right: 4,
                child: PopupMenuButton<String>(
                  icon: const Icon(Broken.more, size: 20),
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
