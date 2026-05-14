import 'package:flutter/material.dart';
import '../../models/file_item_model.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';

class FolderItem extends StatelessWidget {
  final FileItemModel folder;
  final VoidCallback onTap;
  final Function(String) onAction;

  const FolderItem({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Broken.folder,
                  color: theme.colorScheme.primary,
                  size: 28,
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
                        fontSize: 15,
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
                icon: const Icon(Broken.more, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: onAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Broken.copy, size: 18), SizedBox(width: 8), Text('Copy')])),
                  const PopupMenuItem(value: 'cut', child: Row(children: [Icon(Broken.scissor, size: 18), SizedBox(width: 8), Text('Cut')])),
                  const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Broken.edit, size: 18), SizedBox(width: 8), Text('Rename')])),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Broken.trash, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
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
