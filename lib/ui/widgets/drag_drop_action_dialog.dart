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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getFileIconColor(context).withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getFileIconColor(context).withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Icon(
                        _getFileIcon(),
                        color: _getFileIconColor(context),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Drag & Drop Options',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                            ),
                            child: Text(
                              itemName,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        theme.colorScheme.primary.withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Destination Location'.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.3,
                    color: theme.colorScheme.primary.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 10),

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
                  onTapCustom: () {
                    if (_customPath == null || _selectedDestPath == _customPath) {
                      _pickCustomLocation(provider);
                    } else {
                      setState(() {
                        _selectedDestPath = _customPath!;
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Broken.info_circle, size: 18, color: theme.colorScheme.primary.withOpacity(0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedDestPath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'Choose Action'.toUpperCase(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.3,
                    color: theme.colorScheme.primary.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 12),

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

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                        onPressed: () => _executeAction(provider),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.08),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        color: isSelected
            ? theme.colorScheme.primary.withOpacity(0.06)
            : theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTapCustom ?? () {
            setState(() {
              _selectedDestPath = pathValue;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.55),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                          fontSize: 14.5,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.25),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(3.5),
                  child: isSelected
                      ? Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                ),
              ],
            ),
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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected ? color : theme.colorScheme.onSurface.withOpacity(0.08),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          color: isSelected ? color.withOpacity(0.06) : theme.colorScheme.surface,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(12),
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
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 14.5,
                            color: isSelected ? color : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? color : theme.colorScheme.onSurface.withOpacity(0.25),
                        width: 2.0,
                      ),
                      color: isSelected ? color : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
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
          await provider.moveItem(stableContext, path, _selectedDestPath, showToast: false);
        }
      }
      provider.clearSelection();
    } else if (_selectedAction == 'copy') {
      for (final path in widget.sourcePaths) {
        if (stableContext.mounted) {
          await provider.copyItem(stableContext, path, _selectedDestPath, showToast: false);
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
