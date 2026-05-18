import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';
import '../../services/archive_service.dart';
import 'internal_file_picker_screen.dart';

class ArchiveItem {
  final String name;
  final String fullPath;
  final bool isDirectory;
  final int size;

  ArchiveItem({
    required this.name,
    required this.fullPath,
    required this.isDirectory,
    required this.size,
  });
}

class ArchiveViewerScreen extends StatefulWidget {
  final String archivePath;

  const ArchiveViewerScreen({super.key, required this.archivePath});

  @override
  State<ArchiveViewerScreen> createState() => _ArchiveViewerScreenState();
}

class _ArchiveViewerScreenState extends State<ArchiveViewerScreen> {
  Archive? _archive;
  String _currentInternalPath = '';
  bool _isLoading = true;
  final Set<String> _selectedInternalPaths = {};

  String get _archiveName => p.basename(widget.archivePath);
  bool get isSelectionMode => _selectedInternalPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() => _isLoading = true);
    final arch = await ArchiveService.readArchive(widget.archivePath);
    if (mounted) {
      setState(() {
        _archive = arch;
        _isLoading = false;
        _selectedInternalPaths.clear();
      });
    }
  }

  List<ArchiveItem> get _currentItems {
    if (_archive == null) return [];

    final Set<String> folders = {};
    final List<ArchiveItem> items = [];

    for (final f in _archive!.files) {
      final name = f.name.replaceAll('\\', '/');
      if (name.isEmpty || name == _currentInternalPath) continue;

      if (name.startsWith(_currentInternalPath)) {
        final remaining = name.substring(_currentInternalPath.length);
        final parts = remaining.split('/');

        if (parts.length == 1 || (parts.length == 2 && parts[1].isEmpty)) {
          if (parts.length == 2 && parts[1].isEmpty) {
            final folderName = parts[0];
            if (!folders.contains(folderName)) {
              folders.add(folderName);
              items.add(ArchiveItem(
                name: folderName,
                fullPath: '$_currentInternalPath$folderName/',
                isDirectory: true,
                size: 0,
              ));
            }
          } else {
            items.add(ArchiveItem(
              name: parts[0],
              fullPath: name,
              isDirectory: false,
              size: f.size,
            ));
          }
        } else {
          final folderName = parts[0];
          if (!folders.contains(folderName)) {
            folders.add(folderName);
            items.add(ArchiveItem(
              name: folderName,
              fullPath: '$_currentInternalPath$folderName/',
              isDirectory: true,
              size: 0,
            ));
          }
        }
      }
    }

    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return items;
  }

  void _toggleSelect(ArchiveItem item) {
    setState(() {
      if (_selectedInternalPaths.contains(item.fullPath)) {
        _selectedInternalPaths.remove(item.fullPath);
      } else {
        _selectedInternalPaths.add(item.fullPath);
      }
    });
  }

  Future<bool> _handlePop() async {
    if (_currentInternalPath.isNotEmpty) {
      final parts = _currentInternalPath.substring(0, _currentInternalPath.length - 1).split('/');
      if (parts.length <= 1) {
        setState(() => _currentInternalPath = '');
      } else {
        parts.removeLast();
        setState(() => _currentInternalPath = '${parts.join('/')}/');
      }
      return false;
    }
    return true;
  }

  Future<void> _openArchiveItem(ArchiveItem item) async {
    try {
      final fileObj = _archive!.files.firstWhere((f) => f.name.replaceAll('\\', '/') == item.fullPath);
      final tempDir = Directory.systemTemp.createTempSync('zip_preview');
      final tempFile = File(p.join(tempDir.path, item.name));
      tempFile.writeAsBytesSync(fileObj.content as List<int>);

      if (mounted) {
        final provider = context.read<FileManagerProvider>();
        await provider.openFile(context, tempFile.path);
      }
    } catch (e) {
      debugPrint('Error opening item: $e');
    }
  }

  Future<void> _extractItemOut(ArchiveItem item) async {
    final provider = context.read<FileManagerProvider>();
    final destDir = provider.currentPath;

    setState(() => _isLoading = true);

    try {
      if (!item.isDirectory) {
        final fileObj = _archive!.files.firstWhere((f) => f.name.replaceAll('\\', '/') == item.fullPath);
        final destFile = File(p.join(destDir, item.name));
        destFile.writeAsBytesSync(fileObj.content as List<int>);
      } else {
        for (final f in _archive!.files) {
          final name = f.name.replaceAll('\\', '/');
          if (name.startsWith(item.fullPath) && f.isFile) {
            final rel = name.substring(item.fullPath.length);
            final destFile = File(p.join(destDir, item.name, rel));
            destFile.createSync(recursive: true);
            destFile.writeAsBytesSync(f.content as List<int>);
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Extracted ${item.name} to ${p.basename(destDir)}')));
      }
      await provider.loadDirectory(destDir, showLoading: false);
    } catch (e) {
      debugPrint('Error extracting out: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copySelectedToClipboard({required bool isCut}) async {
    if (_selectedInternalPaths.isEmpty || _archive == null) return;
    setState(() => _isLoading = true);

    try {
      final tempDir = Directory.systemTemp.createTempSync('archive_clipboard');
      final List<String> physicalPaths = [];

      for (final internalPath in _selectedInternalPaths) {
        final isDir = internalPath.endsWith('/');
        if (!isDir) {
          final fileObj = _archive!.files.firstWhere((f) => f.name.replaceAll('\\', '/') == internalPath);
          final fileName = p.basename(internalPath);
          final physicalFile = File(p.join(tempDir.path, fileName));
          physicalFile.writeAsBytesSync(fileObj.content as List<int>);
          physicalPaths.add(physicalFile.path);
        } else {
          final folderName = p.basename(internalPath.substring(0, internalPath.length - 1));
          final targetSubDir = Directory(p.join(tempDir.path, folderName));
          targetSubDir.createSync(recursive: true);
          physicalPaths.add(targetSubDir.path);

          for (final f in _archive!.files) {
            final name = f.name.replaceAll('\\', '/');
            if (name.startsWith(internalPath) && f.isFile) {
              final rel = name.substring(internalPath.length);
              final destFile = File(p.join(targetSubDir.path, rel));
              destFile.createSync(recursive: true);
              destFile.writeAsBytesSync(f.content as List<int>);
            }
          }
        }
      }

      final provider = context.read<FileManagerProvider>();
      provider.setClipboard(
        physicalPaths,
        isCut: isCut,
        sourceArchive: isCut ? widget.archivePath : null,
        internalSourcePaths: isCut ? _selectedInternalPaths.toList() : null,
      );

      setState(() {
        _selectedInternalPaths.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${physicalPaths.length} item(s) copied to clipboard ✓')));
      }
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSelectedInternalItems() async {
    if (_selectedInternalPaths.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Selected Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('Are you sure you want to delete precisely these ${_selectedInternalPaths.length} item(s) from the archive? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() => _isLoading = true);
      final success = await ArchiveService.deleteItemsFromArchive(
        archivePath: widget.archivePath,
        internalPathsToDelete: _selectedInternalPaths.toList(),
      );

      _selectedInternalPaths.clear();
      await _loadArchive();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Items deleted successfully ✓')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete items')));
        }
      }
    }
  }

  Future<void> _addNewFile() async {
    final provider = context.read<FileManagerProvider>();
    final selectedPaths = await InternalFilePickerScreen.show(context, rootPath: provider.rootPath);

    if (selectedPaths != null && selectedPaths.isNotEmpty) {
      setState(() => _isLoading = true);
      int successCount = 0;

      for (final path in selectedPaths) {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.directory) {
          final dir = Directory(path);
          final folderBaseName = p.basename(path);
          final entities = dir.listSync(recursive: true);

          for (final entity in entities) {
            if (entity is File) {
              final relPath = entity.path.substring(path.length + 1);
              final targetInternalPath = p.join(_currentInternalPath, folderBaseName, p.dirname(relPath)).replaceAll('\\', '/');
              final success = await ArchiveService.addFileToArchive(
                archivePath: widget.archivePath,
                filePathToAdd: entity.path,
                internalPath: targetInternalPath == '.' ? '' : '$targetInternalPath/',
              );
              if (success) successCount++;
            }
          }
        } else {
          final success = await ArchiveService.addFileToArchive(
            archivePath: widget.archivePath,
            filePathToAdd: path,
            internalPath: _currentInternalPath,
          );
          if (success) successCount++;
        }
      }

      await _loadArchive();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Successfully added $successCount item(s) into archive ✓'),
        ));
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final provider = context.read<FileManagerProvider>();
    if (!provider.hasClipboard) return;

    setState(() => _isLoading = true);

    int count = 0;
    for (final path in provider.clipboardPaths) {
      final success = await ArchiveService.addFileToArchive(
        archivePath: widget.archivePath,
        filePathToAdd: path,
        internalPath: _currentInternalPath,
      );
      if (success) {
        count++;
        if (provider.isCut) {
          try {
            await File(path).delete();
          } catch (_) {}
        }
      }
    }

    provider.clearClipboard();
    await _loadArchive();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pasted $count item(s) into archive ✓')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FileManagerProvider>();
    final items = _currentItems;

    return PopScope(
      canPop: _currentInternalPath.isEmpty && !isSelectionMode,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (isSelectionMode) {
          setState(() => _selectedInternalPaths.clear());
        } else {
          await _handlePop();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: isSelectionMode
            ? AppBar(
                backgroundColor: theme.colorScheme.primaryContainer,
                leading: IconButton(
                  icon: const Icon(Broken.close_square),
                  onPressed: () => setState(() => _selectedInternalPaths.clear()),
                ),
                title: Text('${_selectedInternalPaths.length} selected', style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 18)),
                actions: [
                  IconButton(
                    icon: const Icon(Broken.document_copy),
                    tooltip: 'Copy',
                    onPressed: () => _copySelectedToClipboard(isCut: false),
                  ),
                  IconButton(
                    icon: const Icon(Broken.scissor),
                    tooltip: 'Cut',
                    onPressed: () => _copySelectedToClipboard(isCut: true),
                  ),
                  IconButton(
                    icon: const Icon(Broken.trash),
                    color: Colors.redAccent,
                    tooltip: 'Delete',
                    onPressed: _deleteSelectedInternalItems,
                  ),
                ],
              )
            : AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_archiveName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_currentInternalPath.isNotEmpty)
                      Text('/$_currentInternalPath', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Broken.refresh),
                    onPressed: _loadArchive,
                    tooltip: 'Refresh',
                  ),
                ],
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _archive == null
                ? const Center(child: Text('Could not read archive'))
                : items.isEmpty
                    ? const Center(child: Text('Folder is empty'))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final isSelected = _selectedInternalPaths.contains(item.fullPath);
                          final iconColor = item.isDirectory ? theme.colorScheme.primary : FileUtils.getColorForFile(item.name, context);

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
                              onTap: () {
                                if (isSelectionMode) {
                                  _toggleSelect(item);
                                } else if (item.isDirectory) {
                                  setState(() => _currentInternalPath = item.fullPath);
                                } else {
                                  _openArchiveItem(item);
                                }
                              },
                              onLongPress: () => _toggleSelect(item),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: isSelected ? theme.colorScheme.primary : (item.isDirectory ? theme.colorScheme.primary.withOpacity(0.1) : iconColor.withOpacity(0.1)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        isSelected ? Broken.tick_circle : (item.isDirectory ? FileUtils.getFolderIcon(context.watch<FileManagerProvider>().folderIconOption) : FileUtils.getIconForFile(item.name)),
                                        color: isSelected ? theme.colorScheme.onPrimary : iconColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (!item.isDirectory) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              FileUtils.formatBytes(item.size, 2),
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Broken.more, size: 22),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      position: PopupMenuPosition.under,
                                      elevation: 8,
                                      onSelected: (action) {
                                        if (action == 'extract') {
                                          _extractItemOut(item);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'extract',
                                          child: Row(
                                            children: [
                                              Icon(Broken.document_download, size: 20, color: theme.colorScheme.primary),
                                              const SizedBox(width: 12),
                                              const Text('Extract to Current Folder', style: TextStyle(fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
        floatingActionButton: provider.hasClipboard
            ? FloatingActionButton.extended(
                onPressed: _pasteFromClipboard,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                icon: const Icon(Broken.document_download),
                label: Text('Paste Here (${provider.clipboardPaths.length})'),
              )
            : FloatingActionButton.extended(
                onPressed: _addNewFile,
                icon: const Icon(Broken.add),
                label: const Text('Add File'),
              ),
      ),
    );
  }
}
