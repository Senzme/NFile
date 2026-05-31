import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../services/archive_service.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import 'create_archive_dialog.dart';
import '../screens/internal_file_picker_screen.dart';

class DragDropActionDialog extends StatefulWidget {
  final List<String> sourcePaths;
  final String initialTargetPath;
  final BuildContext parentContext;

  const DragDropActionDialog({
    super.key,
    required this.sourcePaths,
    required this.initialTargetPath,
    required this.parentContext,
  });

  static Future<void> show({
    required BuildContext context,
    required List<String> sourcePaths,
    required String initialTargetPath,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => DragDropActionDialog(
        sourcePaths: sourcePaths,
        initialTargetPath: initialTargetPath,
        parentContext: context,
      ),
    );
  }

  @override
  State<DragDropActionDialog> createState() => _DragDropActionDialogState();
}

class _DragDropActionDialogState extends State<DragDropActionDialog> {
  late String _selectedDestPath;
  String _selectedAction = 'move'; // 'move', 'copy', 'archive'
  String? _customPath;

  @override
  void initState() {
    super.initState();
    _selectedDestPath = widget.initialTargetPath;
  }

  Future<void> _pickCustomLocation(FileManagerProvider provider) async {
    final picked = await InternalFilePickerScreen.show(
      context,
      rootPath: provider.rootPath,
      pickDirectory: true,
    );

    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _customPath = picked.first;
        _selectedDestPath = picked.first;
      });
    }
  }

  IconData _getFileIcon() {
    if (widget.sourcePaths.length > 1) {
      return Broken.document_copy;
    }
    final path = widget.sourcePaths.first;
    if (Directory(path).existsSync()) {
      return Broken.folder;
    }
    return FileUtils.getIconForFile(path);
  }

  Color _getFileIconColor(BuildContext context) {
    if (widget.sourcePaths.length > 1) {
      return Theme.of(context).colorScheme.primary;
    }
    final path = widget.sourcePaths.first;
    if (Directory(path).existsSync()) {
      return Theme.of(context).colorScheme.primary;
    }
    return FileUtils.getColorForFile(path, context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FileManagerProvider>();
    final selectedCount = widget.sourcePaths.length;
    final isSingle = selectedCount == 1;
    final itemName = isSingle ? p.basename(widget.sourcePaths.first) : '$selectedCount items';
    final currentDirName = p.basename(provider.currentPath);
    final targetDirName = p.basename(widget.initialTargetPath);

    final showSelectedFolderOption = widget.initialTargetPath != provider.currentPath;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Visual Pathway Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getFileIconColor(context).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getFileIcon(),
                        color: _getFileIconColor(context),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Drag & Drop Options',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 20),

                // Destination options
                Text(
                  'Destination Location',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 10),

                // Radio options for target folder selection
                if (showSelectedFolderOption)
                  _buildDestinationCard(
                    theme: theme,
                    title: 'Dropped Folder',
                    subtitle: targetDirName.isEmpty ? 'Root' : targetDirName,
                    pathValue: widget.initialTargetPath,
                    icon: Broken.folder_connection,
                  ),
                _buildDestinationCard(
                  theme: theme,
                  title: 'Current Folder',
                  subtitle: currentDirName.isEmpty ? 'Root' : currentDirName,
                  pathValue: provider.currentPath,
                  icon: Broken.folder,
                ),
                _buildDestinationCard(
                  theme: theme,
                  title: _customPath != null ? 'Custom Location' : 'Select Custom Location...',
                  subtitle: _customPath != null ? p.basename(_customPath!) : 'Choose any destination',
                  pathValue: _customPath ?? 'custom_action',
                  icon: Broken.folder_add,
                  onTapCustom: () => _pickCustomLocation(provider),
                ),

                const SizedBox(height: 10),
                // Display absolute target path
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Broken.info_circle, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDestPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Actions Selector
                Text(
                  'Choose Action',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),

                // Action Choices
                _buildActionCard(
                  theme: theme,
                  action: 'move',
                  title: 'Move here',
                  subtitle: 'Cut & paste item into destination folder',
                  icon: Broken.scissor,
                  color: Colors.orange,
                  isDisabled: widget.sourcePaths.every((path) => p.dirname(path) == _selectedDestPath),
                ),
                _buildActionCard(
                  theme: theme,
                  action: 'copy',
                  title: 'Copy here',
                  subtitle: 'Leaves original file intact and duplicates here',
                  icon: Broken.document_copy,
                  color: Colors.blue,
                ),
                _buildActionCard(
                  theme: theme,
                  action: 'archive',
                  title: 'Archive here',
                  subtitle: 'Compress item into a zip/tar archive here',
                  icon: Broken.box_add,
                  color: Colors.teal,
                ),

                const SizedBox(height: 24),

                // Dialog Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      onPressed: () => _executeAction(provider),
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDestinationCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required String pathValue,
    required IconData icon,
    VoidCallback? onTapCustom,
  }) {
    final isSelected = _selectedDestPath == pathValue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.08),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (onTapCustom != null) {
            onTapCustom();
          } else {
            setState(() {
              _selectedDestPath = pathValue;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.5), size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: pathValue,
                groupValue: _selectedDestPath,
                onChanged: (val) {
                  if (onTapCustom != null && val == 'custom_action') {
                    onTapCustom();
                  } else if (val != null) {
                    setState(() {
                      _selectedDestPath = val;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required String action,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isDisabled = false,
  }) {
    final isSelected = _selectedAction == action;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDisabled
              ? null
              : () {
                  setState(() {
                    _selectedAction = action;
                  });
                },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  shape: const CircleBorder(),
                  onChanged: isDisabled
                      ? null
                      : (val) {
                          if (val == true) {
                            setState(() {
                              _selectedAction = action;
                            });
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _executeAction(FileManagerProvider provider) async {
    Navigator.pop(context);

    final stableContext = widget.parentContext;

    if (_selectedAction == 'move') {
      for (final path in widget.sourcePaths) {
        if (stableContext.mounted) {
          await provider.moveItem(stableContext, path, _selectedDestPath);
        }
      }
      provider.clearSelection();
    } else if (_selectedAction == 'copy') {
      for (final path in widget.sourcePaths) {
        if (stableContext.mounted) {
          await provider.copyItem(stableContext, path, _selectedDestPath);
        }
      }
      provider.clearSelection();
    } else if (_selectedAction == 'archive') {
      final isSingle = widget.sourcePaths.length == 1;
      final initialName = isSingle ? p.basename(widget.sourcePaths.first) : 'Archive';
      if (!stableContext.mounted) return;
      final res = await CreateArchiveDialog.show(stableContext, initialName: initialName, isMultiSelection: !isSingle);

      if (res != null) {
        provider.activeTab.isLoading = true;
        provider.notifyListeners();

        try {
          await ArchiveService.createArchive(
            sourcePaths: widget.sourcePaths,
            destinationDir: _selectedDestPath,
            archiveName: res.archiveName,
            format: res.format,
            compressionLevel: res.compressionLevel,
            password: res.password,
            splitSizeMB: res.splitSizeMB,
            deleteSource: res.deleteSource,
            separateArchives: res.separateArchives,
          );
          
          if (stableContext.mounted) {
            ScaffoldMessenger.of(stableContext).showSnackBar(
              SnackBar(
                content: Text('Archive "${res.archiveName}.${res.format}" created successfully!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          debugPrint('Error creating drag-drop archive: $e');
          if (stableContext.mounted) {
            ScaffoldMessenger.of(stableContext).showSnackBar(
              SnackBar(
                content: Text('Failed to create archive: $e'),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }

        provider.clearSelection();
        await provider.loadDirectory(provider.currentPath, showLoading: false);
      }
    }
  }
}
