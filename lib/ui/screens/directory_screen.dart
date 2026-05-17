import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/file_action_dialogs.dart';
import '../widgets/create_archive_dialog.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'global_search_screen.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileManagerProvider>().init();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openFolder(FileManagerProvider provider, String path) {
    if (_scrollController.hasClients) {
      provider.saveScrollOffset(_scrollController.offset);
    }
    provider.loadDirectory(path).then((_) {
      if (_scrollController.hasClients) {
        final savedOffset = provider.getSavedScrollOffset(path);
        _scrollController.jumpTo(savedOffset);
      }
    });
  }

  void _goBack(FileManagerProvider provider) async {
    if (_scrollController.hasClients) {
      provider.saveScrollOffset(_scrollController.offset);
    }
    final prevPath = p.dirname(provider.currentPath);
    final handled = await provider.goBack();
    if (handled && _scrollController.hasClients) {
      final savedOffset = provider.getSavedScrollOffset(prevPath);
      _scrollController.jumpTo(savedOffset);
    }
  }

  void _handleAction(BuildContext context, String action, String path) async {
    final provider = context.read<FileManagerProvider>();
    switch (action) {
      case 'archive':
        final res = await CreateArchiveDialog.show(
          context,
          initialName: p.basename(path),
          isMultiSelection: false,
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
            targetPaths: [path],
          );
        }
        break;
      case 'extract':
        await provider.extractArchiveDirectly(context, path);
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
        }
        break;
      case 'delete':
        final confirm = await FileActionDialogs.showConfirmDialog(
          context,
          title: 'Delete Item',
          content: 'Are you sure you want to delete this item? This cannot be undone.',
        );
        if (confirm) {
          await provider.deleteFile(path);
        }
        break;
    }
  }

  void _handleMenuAction(BuildContext context, String action, FileManagerProvider provider) async {
    switch (action) {
      case 'file':
        final fileName = await FileActionDialogs.showTextInputDialog(
          context,
          title: 'New File',
          hint: 'File name',
          actionText: 'Create',
        );
        if (fileName != null && fileName.isNotEmpty) {
          await provider.createFile(fileName);
        }
        break;
      case 'folder':
        final folderName = await FileActionDialogs.showTextInputDialog(
          context,
          title: 'New Folder',
          hint: 'Folder name',
          actionText: 'Create',
        );
        if (folderName != null && folderName.isNotEmpty) {
          await provider.createFolder(folderName);
        }
        break;
      case 'archive':
        final currentFolderName = p.basename(provider.currentPath);
        final res = await CreateArchiveDialog.show(
          context,
          initialName: currentFolderName.isEmpty ? 'archive' : currentFolderName,
          isMultiSelection: false,
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
            targetPaths: [provider.currentPath],
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FileManagerProvider>(
      builder: (context, provider, child) {
        final isSelectionMode = provider.isSelectionMode;

        return PopScope(
          canPop: !isSelectionMode && !provider.canGoBack,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (isSelectionMode) {
              provider.clearSelection();
            } else if (provider.canGoBack) {
              _goBack(provider);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(isSelectionMode ? '${provider.selectedPaths.length} selected' : 'Files'),
              leading: isSelectionMode
                  ? IconButton(
                      icon: const Icon(Broken.close_square),
                      onPressed: () => provider.clearSelection(),
                    )
                  : IconButton(
                      icon: const Icon(Broken.arrow_left),
                      onPressed: () => _goBack(provider),
                    ),
              actions: isSelectionMode
                  ? [
                      IconButton(
                        icon: const Icon(Broken.tick_square),
                        tooltip: 'Select All',
                        onPressed: () => provider.selectAll(),
                      ),
                      IconButton(
                        icon: const Icon(Broken.document_copy),
                        tooltip: 'Copy',
                        onPressed: () {
                          provider.copySelected();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied selected items')));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Broken.scissor),
                        tooltip: 'Cut',
                        onPressed: () {
                          provider.cutSelected();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cut selected items')));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Broken.box_add),
                        tooltip: 'Create Archive',
                        onPressed: () async {
                          final res = await CreateArchiveDialog.show(
                            context,
                            initialName: p.basename(provider.currentPath).isEmpty ? 'archive' : p.basename(provider.currentPath),
                            isMultiSelection: provider.selectedPaths.length > 1,
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
                      IconButton(
                        icon: const Icon(Broken.trash, color: Colors.redAccent),
                        tooltip: 'Delete Selected',
                        onPressed: () async {
                          final confirm = await FileActionDialogs.showConfirmDialog(
                            context,
                            title: 'Delete Selected',
                            content: 'Are you sure you want to delete ${provider.selectedPaths.length} items? This cannot be undone.',
                          );
                          if (confirm) {
                            await provider.deleteSelected();
                          }
                        },
                      ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Broken.search_normal),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
                        },
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Broken.add_square, size: 26),
                        tooltip: 'Create New',
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        position: PopupMenuPosition.under,
                        elevation: 8,
                        onSelected: (val) => _handleMenuAction(context, val, provider),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'file', child: Row(children: [Icon(Broken.document, size: 20), SizedBox(width: 12), Text('New File', style: TextStyle(fontWeight: FontWeight.w600))])),
                          const PopupMenuItem(value: 'folder', child: Row(children: [Icon(Broken.folder, size: 20), SizedBox(width: 12), Text('New Folder', style: TextStyle(fontWeight: FontWeight.w600))])),
                          const PopupMenuItem(value: 'archive', child: Row(children: [Icon(Broken.archive, size: 20), SizedBox(width: 12), Text('New Archive', style: TextStyle(fontWeight: FontWeight.w600))])),
                        ],
                      ),
                    ],
            ),
            body: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () => provider.loadDirectory(provider.currentPath),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = provider.currentFiles[index];
                              final isSelected = provider.selectedPaths.contains(item.path);

                              if (item.isDirectory) {
                                return FolderItem(
                                  folder: item,
                                  isSelected: isSelected,
                                  onTap: () {
                                    if (isSelectionMode) {
                                      provider.toggleSelection(item.path);
                                    } else {
                                      _openFolder(provider, item.path);
                                    }
                                  },
                                  onLongPress: () => provider.toggleSelection(item.path),
                                  onAction: (action) => _handleAction(context, action, item.path),
                                );
                              } else {
                                return FileItem(
                                  file: item,
                                  isSelected: isSelected,
                                  onTap: () {
                                    if (isSelectionMode) {
                                      provider.toggleSelection(item.path);
                                    } else {
                                      provider.openFile(context, item.path);
                                    }
                                  },
                                  onLongPress: () => provider.toggleSelection(item.path),
                                  onAction: (action) => _handleAction(context, action, item.path),
                                );
                              }
                            },
                            childCount: provider.currentFiles.length,
                          ),
                        ),
                      ),
                    ],
                  ),
            floatingActionButton: provider.hasClipboard
                ? FloatingActionButton.extended(
                    onPressed: () async {
                      await provider.pasteFile();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pasted successfully')));
                      }
                    },
                    icon: const Icon(Broken.clipboard),
                    label: const Text('Paste Here'),
                  )
                : null,
          ),
        );
      },
    );
  }
}
