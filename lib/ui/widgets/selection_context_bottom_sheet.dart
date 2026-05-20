import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'selection_action_bar.dart'; // To access PropertiesModalDialog
import 'file_action_dialogs.dart';
import 'create_archive_dialog.dart';
import 'package:share_plus/share_plus.dart';
import 'batch_rename_dialog.dart';

class SelectionContextBottomSheet extends StatelessWidget {
  final FileManagerProvider provider;
  final String targetPath; // The path of the specific item that was long pressed

  const SelectionContextBottomSheet({
    super.key,
    required this.provider,
    required this.targetPath,
  });

  static Future<void> show(BuildContext context, FileManagerProvider provider, String targetPath) {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SelectionContextBottomSheet(
        provider: provider,
        targetPath: targetPath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = provider.selectedPaths.length;
    final isSingle = selectedCount == 1;
    final displayTitle = isSingle ? p.basename(targetPath) : '$selectedCount items selected';
    final isFolder = Directory(targetPath).existsSync() || 
        provider.currentFiles.firstWhere((e) => e.path == targetPath, orElse: () => provider.currentFiles.first).isDirectory;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      !isSingle 
                          ? Broken.tick_square 
                          : isFolder 
                              ? Broken.folder 
                              : Broken.document,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isSingle)
                          Text(
                            isFolder ? 'Folder' : 'File',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Broken.close_circle, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            _buildMenuItem(
              context: context,
              icon: Broken.document_copy,
              label: 'Copy Selected',
              onTap: () {
                Navigator.pop(context);
                provider.copySelected();
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Copied $selectedCount item(s)')),
                // );
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Broken.scissor,
              label: 'Cut Selected',
              onTap: () {
                Navigator.pop(context);
                provider.cutSelected();
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Cut $selectedCount item(s)')),
                // );
              },
            ),
            if (isSingle)
              _buildMenuItem(
                context: context,
                icon: Broken.edit,
                label: 'Rename',
                onTap: () async {
                  Navigator.pop(context);
                  final currentName = p.basename(targetPath);
                  final newName = await FileActionDialogs.showTextInputDialog(
                    context,
                    title: 'Rename',
                    hint: 'Enter new name',
                    initialValue: currentName,
                    actionText: 'Rename',
                  );
                  if (newName != null && newName.isNotEmpty) {
                    await provider.renameFile(targetPath, newName);
                    provider.clearSelection();
                  }
                },
              )
            else
              _buildMenuItem(
                context: context,
                icon: Broken.edit,
                label: 'Rename',
                onTap: () async {
                  Navigator.pop(context);
                  await BatchRenameDialog.show(context, provider);
                },
              ),
            _buildMenuItem(
              context: context,
              icon: Broken.box_add,
              label: 'Archive (Compress)',
              onTap: () async {
                Navigator.pop(context);
                final res = await CreateArchiveDialog.show(
                  context,
                  initialName: p.basename(provider.currentPath).isEmpty ? 'archive' : p.basename(provider.currentPath),
                  isMultiSelection: selectedCount > 1,
                );
                if (res != null) {
                  await provider.createArchive(
                    archiveName: res.archiveName,
                    format: res.format,
                    compressionLevel: res.compressionLevel,
                    password: res.password,
                    splitSizeMB: res.splitSizeMB,
                    deleteSource: res.deleteSource,
                    separateArchives: res.separateArchives,
                    targetPaths: provider.selectedPaths.toList(),
                  );
                  provider.clearSelection();
                }
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () async {
                Navigator.pop(context);
                final selectedPaths = provider.selectedPaths.toList();
                final filesToShare = <XFile>[];
                for (final path in selectedPaths) {
                  if (FileSystemEntity.isFileSync(path)) {
                    filesToShare.add(XFile(path));
                  }
                }
                if (filesToShare.isNotEmpty) {
                  try {
                    await Share.shareXFiles(filesToShare);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error sharing: $e')),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Only files can be shared.')),
                  );
                }
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Broken.info_circle,
              label: 'Properties & Info',
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => PropertiesModalDialog(
                    selectedPaths: provider.selectedPaths.toList(),
                    provider: provider,
                  ),
                );
              },
            ),
            const Divider(height: 1),
            _buildMenuItem(
              context: context,
              icon: Broken.trash,
              label: 'Delete Selected',
              color: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context);
                final confirm = await FileActionDialogs.showConfirmDialog(
                  context,
                  title: 'Delete Selected',
                  content: 'Are you sure you want to delete $selectedCount item(s)? This cannot be undone.',
                );
                if (confirm) {
                  await provider.deleteSelected();
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final displayColor = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: displayColor.withOpacity(0.8), size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: displayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
