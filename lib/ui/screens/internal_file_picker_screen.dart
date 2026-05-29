import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../models/file_item_model.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../services/root_shizuku_service.dart';

class InternalFilePickerScreen extends StatefulWidget {
  final String rootPath;
  final bool pickDirectory;

  const InternalFilePickerScreen({super.key, required this.rootPath, this.pickDirectory = false});

  static Future<List<String>?> show(BuildContext context, {required String rootPath, bool pickDirectory = false}) {
    return Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => InternalFilePickerScreen(rootPath: rootPath, pickDirectory: pickDirectory)),
    );
  }

  @override
  State<InternalFilePickerScreen> createState() => _InternalFilePickerScreenState();
}

class _InternalFilePickerScreenState extends State<InternalFilePickerScreen> {
  late String _currentPath;
  bool _isLoading = true;
  List<FileItemModel> _items = [];
  final Set<String> _selectedPaths = {};
  final Map<String, double> _scrollOffsets = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.rootPath;
    _scrollController.addListener(() {
      _scrollOffsets[_currentPath] = _scrollController.offset;
    });
    _loadDirectory(_currentPath);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String path) async {
    setState(() => _isLoading = true);

    try {
      final provider = context.read<FileManagerProvider>();
      final isRestricted = provider.isRestrictedPath(path);

      if (isRestricted) {
        final items = await RootShizukuService.listFiles(
          path,
          useRoot: provider.useRootMode,
          showHiddenFiles: provider.showHiddenFiles,
        );

        final folders = <FileItemModel>[];
        final files = <FileItemModel>[];

        for (var item in items) {
          if (item.isDirectory) {
            folders.add(item);
          } else if (!widget.pickDirectory) {
            files.add(item);
          }
        }

        folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (mounted) {
          setState(() {
            _currentPath = path;
            _items = [...folders, ...files];
            _isLoading = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final offset = _scrollOffsets[_currentPath] ?? 0.0;
              _scrollController.jumpTo(offset);
            }
          });
        }
        return;
      }

      final dir = Directory(path);
      if (await dir.exists()) {
        _currentPath = path;
        final entities = await dir.list().toList();

        final folders = <FileItemModel>[];
        final files = <FileItemModel>[];

        final items = await Future.wait(entities.map((e) => FileItemModel.fromEntityAsync(e)));

        for (var item in items) {
          try {
            if (item.isDirectory) {
              folders.add(item);
            } else if (!widget.pickDirectory) {
              files.add(item);
            }
          } catch (_) {}
        }

        folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (mounted) {
          setState(() {
            _items = [...folders, ...files];
            _isLoading = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              final offset = _scrollOffsets[_currentPath] ?? 0.0;
              _scrollController.jumpTo(offset);
            }
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading directory: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _goBack() async {
    if (_currentPath == widget.rootPath || _currentPath == '/' || p.dirname(_currentPath) == _currentPath) {
      return false;
    }
    final parent = p.dirname(_currentPath);
    await _loadDirectory(parent);
    return true;
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _currentPath == widget.rootPath || _currentPath == '/',
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _goBack();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Broken.arrow_left_2),
            onPressed: () async {
              if (!await _goBack()) {
                if (context.mounted) Navigator.pop(context, null);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.pickDirectory ? 'Select & Pin Folders' : 'Select Files & Folders', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text(_currentPath, style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
            ],
          ),
          actions: [
            if (_selectedPaths.isNotEmpty)
              IconButton(
                icon: const Icon(Broken.close_square),
                tooltip: 'Clear Selection',
                onPressed: () => setState(() => _selectedPaths.clear()),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('Folder is empty'))
                : ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isSelected = _selectedPaths.contains(item.path);
                      final iconColor = item.isDirectory ? theme.colorScheme.primary : FileUtils.getColorForFile(item.name, context);

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.5) : theme.colorScheme.surface,
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
                            if (item.isDirectory) {
                              _loadDirectory(item.path);
                            } else {
                              _toggleSelect(item.path);
                            }
                          },
                          onLongPress: () => _toggleSelect(item.path),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _toggleSelect(item.path),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected ? theme.colorScheme.primary : (item.isDirectory ? theme.colorScheme.primary.withOpacity(0.1) : iconColor.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isSelected ? Broken.tick_circle : (item.isDirectory ? FileUtils.getFolderIcon(context.read<FileManagerProvider>().folderIconOption) : FileUtils.getIconForFile(item.name)),
                                      color: isSelected ? theme.colorScheme.onPrimary : iconColor,
                                      size: 28,
                                    ),
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
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelect(item.path),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: widget.pickDirectory
            ? _selectedPaths.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.pop(context, _selectedPaths.toList()),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    icon: const Icon(Broken.folder_add),
                    label: Text('Pin Selected (${_selectedPaths.length})'),
                  )
                : FloatingActionButton.extended(
                    onPressed: () => Navigator.pop(context, [_currentPath]),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    icon: const Icon(Broken.folder_add),
                    label: const Text('Pin This Folder'),
                  )
            : _selectedPaths.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => Navigator.pop(context, _selectedPaths.toList()),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    icon: const Icon(Broken.add),
                    label: Text('Add Selected (${_selectedPaths.length})'),
                  )
                : null,
      ),
    );
  }
}
