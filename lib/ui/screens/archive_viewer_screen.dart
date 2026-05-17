import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';
import '../../services/archive_service.dart';

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

  String get _archiveName => p.basename(widget.archivePath);

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

  Future<void> _addNewFile() async {
    final provider = context.read<FileManagerProvider>();
    final availableFiles = provider.currentFiles.where((f) => !f.isDirectory).toList();

    if (availableFiles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No files in current folder to add')));
      }
      return;
    }

    final selectedPath = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select File to Add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableFiles.length,
            itemBuilder: (c, i) => ListTile(
              leading: Icon(FileUtils.getIconForFile(availableFiles[i].path), color: Theme.of(context).colorScheme.primary),
              title: Text(availableFiles[i].name),
              subtitle: Text(FileUtils.formatBytes(availableFiles[i].size, 1), style: const TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(c, availableFiles[i].path),
            ),
          ),
        ),
      ),
    );

    if (selectedPath != null) {
      setState(() => _isLoading = true);
      final success = await ArchiveService.addFileToArchive(
        archivePath: widget.archivePath,
        filePathToAdd: selectedPath,
        internalPath: _currentInternalPath,
      );
      if (success) {
        await _loadArchive();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File added successfully ✓')));
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add file')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _currentItems;

    return PopScope(
      canPop: _currentInternalPath.isEmpty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handlePop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
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
                          final iconColor = item.isDirectory ? Colors.amber : FileUtils.getColorForFile(item.name, context);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            color: theme.colorScheme.surface,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                            ),
                            child: InkWell(
                              onTap: () {
                                if (item.isDirectory) {
                                  setState(() => _currentInternalPath = item.fullPath);
                                } else {
                                  _openArchiveItem(item);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: iconColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item.isDirectory ? Broken.folder_2 : FileUtils.getIconForFile(item.name),
                                        color: iconColor,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addNewFile,
          icon: const Icon(Broken.add),
          label: const Text('Add File'),
        ),
      ),
    );
  }
}
