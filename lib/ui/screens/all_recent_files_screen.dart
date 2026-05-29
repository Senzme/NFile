import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../models/file_item_model.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/file_action_dialogs.dart';

class AllRecentFilesScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;
  const AllRecentFilesScreen({super.key, this.onNavigateTab});

  @override
  State<AllRecentFilesScreen> createState() => _AllRecentFilesScreenState();
}

class _AllRecentFilesScreenState extends State<AllRecentFilesScreen> {
  List<FileItemModel> _recentFiles = [];
  bool _isLoading = true;
  final Set<String> _selectedPaths = {};

  bool get _isSelectionMode => _selectedPaths.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final items = await _scanRecentFiles();
      if (mounted) {
        setState(() {
          _recentFiles = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<FileItemModel>> _scanRecentFiles() async {
    final list = <FileSystemEntity>[];
    final seen = <String>{};

    final rootDir = Directory('/storage/emulated/0');
    if (await rootDir.exists()) {
      try {
        final List<String> pathsToScan = [];
        
        final rootEntities = await rootDir.list(recursive: false).toList();
        for (final entity in rootEntities) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.') && name != 'Android') {
              pathsToScan.add(entity.path);
            }
          }
        }

        pathsToScan.addAll([
          '/storage/emulated/0/Android/media',
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Documents',
        ]);

        await Future.wait(pathsToScan.map((path) async {
          final dir = Directory(path);
          if (await dir.exists()) {
            try {
              final entities = await dir.list(recursive: false).toList();
              for (final entity in entities) {
                if (!seen.contains(entity.path)) {
                  seen.add(entity.path);
                  list.add(entity);
                }
                if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
                  try {
                    final subEntities = await entity.list(recursive: false).toList();
                    for (final sub in subEntities) {
                      if (!seen.contains(sub.path)) {
                        seen.add(sub.path);
                        list.add(sub);
                      }
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }));
      } catch (_) {}
    }

    final mediaProvider = context.read<MediaProvider>();

    void addFromMediaList(List<FileSystemEntity> mediaList) {
      for (final entity in mediaList) {
        if (!seen.contains(entity.path)) {
          seen.add(entity.path);
          list.add(entity);
        }
      }
    }

    addFromMediaList(mediaProvider.downloads);
    addFromMediaList(mediaProvider.documents);
    addFromMediaList(mediaProvider.archives);
    addFromMediaList(mediaProvider.apks);

    for (final song in mediaProvider.audios) {
      final path = song.data;
      if (!seen.contains(path)) {
        seen.add(path);
        try {
          final f = File(path);
          if (await f.exists()) list.add(f);
        } catch (_) {}
      }
    }

    final filteredList = <FileSystemEntity>[];
    for (final entity in list) {
      if (entity is Directory) {
        bool hasNestedChild = false;
        for (final other in list) {
          if (other.path != entity.path && p.isWithin(entity.path, other.path)) {
            hasNestedChild = true;
            break;
          }
        }
        if (hasNestedChild) {
          continue;
        }
      }
      filteredList.add(entity);
    }

    final items = <FileItemModel>[];
    await Future.wait(filteredList.map((f) async {
      try {
        final isDir = f is Directory;
        if (isDir) return;

        final name = p.basename(f.path);
        if (name.startsWith('.')) return;

        final stat = await f.stat();
        items.add(FileItemModel(
          entity: f,
          name: name,
          path: f.path,
          isDirectory: false,
          size: stat.size,
          modified: stat.modified,
        ));
      } catch (_) {}
    }));

    items.sort((a, b) => b.modified.compareTo(a.modified));
    return items;
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final item in _recentFiles) {
        _selectedPaths.add(item.path);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPaths.clear();
    });
  }

  void _handleCopySelected() {
    if (_selectedPaths.isEmpty) return;
    context.read<FileManagerProvider>().setClipboard(_selectedPaths.toList(), isCut: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${_selectedPaths.length} items to clipboard')),
    );
    _clearSelection();
  }

  void _handleCutSelected() {
    if (_selectedPaths.isEmpty) return;
    context.read<FileManagerProvider>().setClipboard(_selectedPaths.toList(), isCut: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cut ${_selectedPaths.length} items to clipboard')),
    );
    _clearSelection();
  }

  Future<void> _handleShareSelected() async {
    if (_selectedPaths.isEmpty) return;
    final shareFiles = <XFile>[];
    for (final path in _selectedPaths) {
      if (FileSystemEntity.isFileSync(path)) {
        shareFiles.add(XFile(path));
      }
    }
    if (shareFiles.isNotEmpty) {
      try {
        await Share.shareXFiles(shareFiles);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No files available to share')));
    }
    _clearSelection();
  }

  Future<void> _handleDeleteSelected() async {
    if (_selectedPaths.isEmpty) return;
    final confirm = await FileActionDialogs.showConfirmDialog(
      context,
      title: 'Delete Selected',
      content: 'Are you sure you want to delete ${_selectedPaths.length} selected item(s)? This cannot be undone.',
    );

    if (confirm) {
      final provider = context.read<FileManagerProvider>();
      final toDelete = _selectedPaths.toList();
      for (final path in toDelete) {
        await provider.deleteFile(path);
        setState(() {
          _recentFiles.removeWhere((e) => e.path == path);
        });
      }
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully deleted items')));
    }
  }

  void _handleAction(BuildContext context, String action, String path) async {
    final provider = context.read<FileManagerProvider>();
    switch (action) {
      case 'show_in_location':
        provider.showFileInLocation(path);
        Navigator.pop(context);
        widget.onNavigateTab?.call(1);
        break;
      case 'copy':
        provider.copyFile(path);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        break;
      case 'cut':
        provider.cutFile(path);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cut to clipboard')));
        break;
      case 'rename':
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
          _loadRecentFiles(); // refresh
        }
        break;
      case 'delete':
        final confirm = await FileActionDialogs.showConfirmDialog(
          context,
          title: 'Delete File',
          content: 'Are you sure you want to delete this item? This cannot be undone.',
        );
        if (confirm) {
          await provider.deleteFile(path);
          setState(() {
            _recentFiles.removeWhere((e) => e.path == path);
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FileManagerProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: _isSelectionMode
            ? IconButton(icon: const Icon(Broken.close_square), onPressed: _clearSelection)
            : IconButton(
                icon: const Icon(Broken.arrow_left),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          _isSelectionMode ? '${_selectedPaths.length} Selected' : 'All Recent Files',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Broken.document_copy),
                  tooltip: 'Copy',
                  onPressed: _handleCopySelected,
                ),
                IconButton(
                  icon: const Icon(Broken.scissor),
                  tooltip: 'Cut',
                  onPressed: _handleCutSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'Share',
                  onPressed: _handleShareSelected,
                ),
                IconButton(
                  icon: const Icon(Broken.trash, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: _handleDeleteSelected,
                ),
                IconButton(
                  icon: const Icon(Broken.task_square),
                  tooltip: 'Select All',
                  onPressed: _selectAll,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadRecentFiles();
                  },
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentFiles.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(20), shape: BoxShape.circle),
                          child: Icon(Broken.document_filter, size: 64, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 24),
                        Text('No recent files', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Newly created or downloaded files will show up here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(127), fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: _recentFiles.length,
                  itemBuilder: (context, index) {
                    final item = _recentFiles[index];
                    final isItemSelected = _selectedPaths.contains(item.path);

                    if (item.isDirectory) {
                      return FolderItem(
                        folder: item,
                        isSelected: isItemSelected,
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(item.path);
                          } else {
                            provider.loadDirectory(item.path);
                          }
                        },
                        onLongPress: () => _toggleSelection(item.path),
                        onAction: (action) => _handleAction(context, action, item.path),
                      );
                    } else {
                      return FileItem(
                        file: item,
                        isSelected: isItemSelected,
                        showShowInLocationOption: true,
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(item.path);
                          } else {
                            provider.openFile(context, item.path);
                          }
                        },
                        onLongPress: () => _toggleSelection(item.path),
                        onAction: (action) => _handleAction(context, action, item.path),
                      );
                    }
                  },
                ),
    );
  }
}
