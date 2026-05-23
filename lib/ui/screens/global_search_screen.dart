import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../models/file_item_model.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/file_action_dialogs.dart';
import '../../core/icon_fonts/broken_icons.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String? searchFolderPath;
  const GlobalSearchScreen({super.key, this.searchFolderPath});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedFilter = 'All'; // All, Folders, Images, Videos, Audio, Docs
  
  List<FileItemModel> _results = [];
  bool _isSearching = false;
  StreamSubscription<FileSystemEntity>? _searchSubscription;

  final Set<String> _selectedPaths = {};
  bool get _isSelectionMode => _selectedPaths.isNotEmpty;

  final List<String> _filters = [
    'All',
    'Folders',
    'Images',
    'Videos',
    'Audio',
    'Docs',
  ];

  @override
  void dispose() {
    _searchSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _query = value.trim();
    });
    _executeSearch();
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _executeSearch();
  }

  void _executeSearch() {
    _searchSubscription?.cancel();
    _clearSelection();
    if (_query.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _results = [];
      _isSearching = true;
    });

    final Set<String> seenPaths = {};
    final List<FileItemModel> currentBatch = [];
    final mediaProvider = context.read<MediaProvider>();
    final fileProvider = context.read<FileManagerProvider>();

    final qLower = _query.toLowerCase();
    
    // Resolve search scope
    final isGlobal = widget.searchFolderPath == null ||
                     widget.searchFolderPath == '/storage/emulated/0' ||
                     widget.searchFolderPath == '/';

    final rootPath = isGlobal
        ? (Platform.isAndroid ? '/storage/emulated/0' : fileProvider.currentPath)
        : widget.searchFolderPath!;
    
    // 1. Instant check from MediaProvider indexes if matching filter
    if (_selectedFilter == 'All' || _selectedFilter == 'Docs') {
      final matchingDocs = <FileSystemEntity>[];
      for (final doc in mediaProvider.documents) {
        if (!isGlobal && !doc.path.startsWith(rootPath)) continue;
        final name = p.basename(doc.path);
        if (name.toLowerCase().contains(qLower) && !seenPaths.contains(doc.path)) {
          seenPaths.add(doc.path);
          matchingDocs.add(doc);
        }
      }
      if (matchingDocs.isNotEmpty) {
        Future.wait(matchingDocs.map((doc) => FileItemModel.fromEntityAsync(doc))).then((resolvedDocs) {
          if (mounted) {
            setState(() {
              _results.addAll(resolvedDocs);
            });
          }
        });
      }
    }

    if (_selectedFilter == 'All' || _selectedFilter == 'Audio') {
      for (final song in mediaProvider.audios) {
        final path = song.data;
        if (!isGlobal && !path.startsWith(rootPath)) continue;
        final name = p.basename(path);
        if (name.toLowerCase().contains(qLower) && !seenPaths.contains(path)) {
          seenPaths.add(path);
          currentBatch.add(FileItemModel(
            entity: File(path),
            name: song.title,
            path: path,
            isDirectory: false,
            size: song.size,
            modified: DateTime.fromMillisecondsSinceEpoch((song.dateModified ?? 0) * 1000),
          ));
        }
      }
    }

    // Update state instantly with cached media results
    if (currentBatch.isNotEmpty) {
      setState(() {
        _results = List.from(currentBatch);
      });
    }

    // 2. Stream across filesystem for full coverage (Folders and other files)
    final rootDir = Directory(rootPath);
    if (!rootDir.existsSync()) {
      setState(() {
        _isSearching = false;
      });
      return;
    }

    _searchSubscription = rootDir.list(recursive: true, followLinks: false).listen(
      (entity) {
        final name = p.basename(entity.path);
        if (name.toLowerCase().contains(qLower)) {
          final isDir = entity is Directory;
          
          bool matchFilter = false;
          if (_selectedFilter == 'All') {
            matchFilter = true;
          } else if (_selectedFilter == 'Folders' && isDir) {
            matchFilter = true;
          } else if (_selectedFilter == 'Images' && !isDir && _isImage(name)) {
            matchFilter = true;
          } else if (_selectedFilter == 'Videos' && !isDir && _isVideo(name)) {
            matchFilter = true;
          } else if (_selectedFilter == 'Audio' && !isDir && _isAudio(name)) {
            matchFilter = true;
          } else if (_selectedFilter == 'Docs' && !isDir && _isDoc(name)) {
            matchFilter = true;
          }

          if (matchFilter && !seenPaths.contains(entity.path)) {
            seenPaths.add(entity.path);
            FileItemModel.fromEntityAsync(entity).then((item) {
              if (mounted) {
                setState(() {
                  _results.add(item);
                });
              }
            });
          }
        }
      },
      onError: (_) {},
      onDone: () {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      },
    );
  }

  bool _isImage(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'].contains(ext);
  }

  bool _isVideo(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.ts'].contains(ext);
  }

  bool _isAudio(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus', '.amr'].contains(ext);
  }

  bool _isDoc(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv'].contains(ext);
  }

  // --- Multi-Selection logic ---
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
      for (final item in _results) {
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
          _results.removeWhere((e) => e.path == path);
        });
      }
      _clearSelection();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully deleted items')));
    }
  }

  void _handleAction(BuildContext context, String action, String path) async {
    final provider = context.read<FileManagerProvider>();
    switch (action) {
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
          _executeSearch(); // refresh
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
            _results.removeWhere((e) => e.path == path);
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlobal = widget.searchFolderPath == null ||
                     widget.searchFolderPath == '/storage/emulated/0' ||
                     widget.searchFolderPath == '/';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Broken.close_square),
                onPressed: _clearSelection,
              )
            : IconButton(
                icon: const Icon(Broken.arrow_left),
                onPressed: () => Navigator.pop(context),
              ),
        title: _isSelectionMode
            ? Text(
                '${_selectedPaths.length} Selected',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              )
            : TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText: isGlobal ? 'Search globally...' : 'Search in this folder...',
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withAlpha(102)),
                  border: InputBorder.none,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Broken.close_square, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                ),
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
            : null,
      ),
      body: Column(
        children: [
          // Filter Chips Row (NFile style)
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onFilterChanged(filter),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withAlpha(38)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.dividerColor.withAlpha(51),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (isSelected) ...[
                            Icon(Broken.tick_circle, size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            filter,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withAlpha(178),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Search Progress Indicator
          if (_isSearching)
            LinearProgressIndicator(
              backgroundColor: theme.colorScheme.primary.withAlpha(25),
              color: theme.colorScheme.primary,
              minHeight: 2,
            )
          else
            const SizedBox(height: 2),
 
          // Results List / Empty State
          Expanded(
            child: _query.isEmpty
                ? _buildEmptyState(
                    theme,
                    Broken.search_normal_1,
                    isGlobal ? 'Search your storage' : 'Search this folder',
                    isGlobal
                        ? 'Find any file, folder, document or media instantly across your device'
                        : 'Search files and subfolders in: ${widget.searchFolderPath!.split("/").last}',
                  )
                : _results.isEmpty && !_isSearching
                    ? _buildEmptyState(
                        theme,
                        Broken.document_filter,
                        'No results found',
                        'We could not find anything matching "$_query" under $_selectedFilter',
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final isItemSelected = _selectedPaths.contains(item.path);

                          if (item.isDirectory) {
                            return FolderItem(
                              folder: item,
                              isSelected: isItemSelected,
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(item.path);
                                } else {
                                  Navigator.pop(context);
                                  context.read<FileManagerProvider>().loadDirectory(item.path);
                                }
                              },
                              onLongPress: () => _toggleSelection(item.path),
                              onAction: (action) => _handleAction(context, action, item.path),
                            );
                          } else {
                            return FileItem(
                              file: item,
                              isSelected: isItemSelected,
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(item.path);
                                } else {
                                  context.read<FileManagerProvider>().openFile(context, item.path);
                                }
                              },
                              onLongPress: () => _toggleSelection(item.path),
                              onAction: (action) => _handleAction(context, action, item.path),
                            );
                          }
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(127), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
