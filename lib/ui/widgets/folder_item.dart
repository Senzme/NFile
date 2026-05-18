import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../models/file_item_model.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';

class FolderItem extends StatelessWidget {
  final FileItemModel folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(String) onAction;
  final bool isSelected;
  final double iconScale;

  const FolderItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    required this.onAction,
    this.isSelected = false,
    this.iconScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folderIcon = context.watch<FileManagerProvider>().folderIcon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48 * iconScale,
                height: 48 * iconScale,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? Broken.tick_circle : folderIcon,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                  size: 28 * iconScale,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15 * (1 + (iconScale - 1) * 0.3),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FileUtils.formatDate(folder.modified),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}
