import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import 'file_action_dialogs.dart';
import 'create_archive_dialog.dart';
import 'file_operation_progress_dialog.dart';

class SelectionActionBar extends StatelessWidget {
  final FileManagerProvider provider;

  const SelectionActionBar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = provider.selectedPaths.length;
    final hasClipboard = provider.hasClipboard;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Broken.document_copy,
              label: 'Copy',
              onTap: () {
                provider.copySelected();
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Copied $selectedCount item(s)')),
                // );
              },
            ),
            _ActionButton(
              icon: Broken.scissor,
              label: 'Cut',
              onTap: () {
                provider.cutSelected();
                // ScaffoldMessenger.of(context).showSnackBar(
                //   SnackBar(content: Text('Cut $selectedCount item(s)')),
                // );
              },
            ),
            _ActionButton(
              icon: Broken.trash,
              label: 'Delete',
              color: Colors.redAccent,
              onTap: () async {
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
            _ActionButton(
              icon: Broken.box_add,
              label: 'Archive',
              onTap: () async {
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
                }
              },
            ),
            _ActionButton(
              icon: Broken.info_circle,
              label: 'Properties',
              onTap: () => _showPropertiesModal(context, provider),
            ),
            PopupMenuButton<String>(
              icon: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Broken.more, size: 24),
                  SizedBox(height: 4),
                  Text('More', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              position: PopupMenuPosition.under,
              elevation: 8,
              onSelected: (action) async {
                if (action == 'rename') {
                  final path = provider.selectedPaths.first;
                  final currentName = p.basename(path);
                  final newName = await FileActionDialogs.showTextInputDialog(
                    context,
                    title: 'Rename',
                    hint: 'Enter new name',
                    initialValue: currentName,
                    actionText: 'Rename',
                  );
                  if (newName != null && newName.isNotEmpty) {
                    await provider.renameFile(path, newName);
                    provider.clearSelection();
                  }
                } else if (action == 'paste') {
                  FileOperationProgressDialog.show(context, provider);
                  await provider.pasteFile();
                  provider.clearSelection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pasted items successfully')),
                    );
                  }
                } else if (action == 'select_all') {
                  provider.selectAll();
                }
              },
              itemBuilder: (context) => [
                if (selectedCount == 1)
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Broken.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Rename', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                if (hasClipboard)
                  const PopupMenuItem(
                    value: 'paste',
                    child: Row(
                      children: [
                        Icon(Broken.clipboard, size: 20),
                        SizedBox(width: 12),
                        Text('Paste Here', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'select_all',
                  child: Row(
                    children: [
                      Icon(Broken.tick_square, size: 20),
                      SizedBox(width: 12),
                      Text('Select All', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPropertiesModal(BuildContext context, FileManagerProvider provider) {
    final selectedPaths = provider.selectedPaths.toList();
    if (selectedPaths.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => PropertiesModalDialog(selectedPaths: selectedPaths, provider: provider),
    );
  }
}

class PropertiesModalDialog extends StatefulWidget {
  final List<String> selectedPaths;
  final FileManagerProvider provider;

  const PropertiesModalDialog({super.key, required this.selectedPaths, required this.provider});

  @override
  State<PropertiesModalDialog> createState() => PropertiesModalDialogState();
}

class PropertiesModalDialogState extends State<PropertiesModalDialog> {
  bool _isLoading = true;
  int _totalBytes = 0;
  int _folderCount = 0;
  int _fileCount = 0;
  DateTime? _lastModified;
  String _permissions = '';
  String _mimeType = '';

  @override
  void initState() {
    super.initState();
    _calculateProperties();
  }

  Future<void> _calculateProperties() async {
    int bytes = 0;
    int folders = 0;
    int files = 0;

    final currentFilesMap = {for (var f in widget.provider.currentFiles) f.path: f};

    for (final path in widget.selectedPaths) {
      try {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          folders++;
          final dir = Directory(path);
          if (dir.existsSync()) {
            try {
              await for (final entity in dir.list(recursive: true, followLinks: false)) {
                if (entity is File) {
                  files++;
                  bytes += await entity.length();
                } else if (entity is Directory) {
                  folders++;
                }
              }
            } catch (_) {}
          }
        } else if (type == FileSystemEntityType.file) {
          files++;
          final f = File(path);
          if (f.existsSync()) {
            bytes += f.lengthSync();
            if (widget.selectedPaths.length == 1) {
              final stat = f.statSync();
              _lastModified = stat.modified;
              _permissions = '${(stat.mode & 0x100) != 0 ? "Read" : ""}${(stat.mode & 0x80) != 0 ? " / Write" : ""}';
            }
          }
        } else {
          // Fallback if restricted/Shizuku
          final item = currentFilesMap[path];
          if (item != null) {
            if (item.isDirectory) {
              folders++;
            } else {
              files++;
              bytes += item.size;
            }
          }
        }
      } catch (_) {
        final item = currentFilesMap[path];
        if (item != null) {
          if (item.isDirectory) {
            folders++;
          } else {
            files++;
            bytes += item.size;
          }
        }
      }
    }

    if (widget.selectedPaths.length == 1) {
      final pStr = widget.selectedPaths.first;
      final ext = pStr.contains('.') ? pStr.substring(pStr.lastIndexOf('.')).toLowerCase() : '';
      if (folders > 0) {
        _mimeType = 'Folder / Directory';
      } else {
        _mimeType = ext.isNotEmpty ? 'File ($ext)' : 'File';
      }
    }

    if (mounted) {
      setState(() {
        _totalBytes = bytes;
        _folderCount = folders;
        _fileCount = files;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = widget.selectedPaths.length;
    final isSingle = count == 1;
    final nameDisplay = isSingle ? p.basename(widget.selectedPaths.first) : '$count items selected';

    return AlertDialog(
      title: Row(
        children: [
          Icon(Broken.info_circle, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          const Text('Properties', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Calculating sizes...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSingle) ...[
                    _CopyablePropertyRow(label: 'Name', value: nameDisplay),
                    _CopyablePropertyRow(label: 'Path', value: widget.selectedPaths.first),
                    _CopyablePropertyRow(
                      label: 'Size',
                      value: '${FileUtils.formatBytes(_totalBytes, 2)} ($_totalBytes bytes)',
                    ),
                    if (_folderCount > 0 && _fileCount > 0)
                      _CopyablePropertyRow(
                        label: 'Contains',
                        value: '$_folderCount folder(s), $_fileCount file(s)',
                      ),
                    if (_lastModified != null)
                      _CopyablePropertyRow(label: 'Modified', value: FileUtils.formatDate(_lastModified!)),
                    if (_mimeType.isNotEmpty) _CopyablePropertyRow(label: 'Type', value: _mimeType),
                    if (_permissions.isNotEmpty) _CopyablePropertyRow(label: 'Permissions', value: _permissions),
                  ] else ...[
                    _CopyablePropertyRow(
                      label: 'Items Selected',
                      value: '$count items ($_folderCount folder(s), $_fileCount file(s))',
                    ),
                    _CopyablePropertyRow(
                      label: 'Total Size',
                      value: '${FileUtils.formatBytes(_totalBytes, 2)} ($_totalBytes bytes)',
                    ),
                    const SizedBox(height: 12),
                    const Text('Selected Paths:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.selectedPaths
                                .map((path) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6.0),
                                      child: SelectableText(
                                        p.basename(path),
                                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: displayColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: displayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyablePropertyRow extends StatelessWidget {
  final String label;
  final String value;

  const _CopyablePropertyRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied $label to clipboard'), duration: const Duration(seconds: 1)),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary),
                ),
              ),
              Expanded(
                flex: 7,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Broken.document_copy, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
