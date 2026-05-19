import 'package:flutter/material.dart';
import '../../models/file_item_model.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';

class FolderGridItem extends StatelessWidget {
  final FileItemModel folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(String) onAction;
  final bool isSelected;
  final double iconScale;
  final double itemPaddingMultiplier;

  const FolderGridItem({
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
      (p) => p.highlightedPaths.contains(folder.path),
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
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? Broken.tick_circle : FileUtils.getFolderIcon(context.watch<FileManagerProvider>().folderIconOption),
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                            size: 28 * iconScale,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        folder.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13 * (1 + (iconScale - 1) * 0.3),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        FileUtils.formatDate(folder.modified),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10 * (1 + (iconScale - 1) * 0.2),
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
