import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/file_grid_item.dart';
import '../widgets/folder_grid_item.dart';
import '../widgets/file_action_dialogs.dart';
import '../widgets/create_archive_dialog.dart';
import '../widgets/nfile_drawer.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'global_search_screen.dart';

class DirectoryScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final Function(int)? onNavigateTab;
  const DirectoryScreen({super.key, required this.toggleTheme, this.onNavigateTab});

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

  void _showAddBottomSheet(BuildContext context, FileManagerProvider provider) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Broken.folder_add, color: theme.colorScheme.primary, size: 24),
                ),
                title: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text('Create a new directory', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () {
                  Navigator.pop(context);
                  _handleMenuAction(context, 'folder', provider);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Broken.document_1, color: theme.colorScheme.primary, size: 24),
                ),
                title: const Text('New File', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text('Create a new empty text document', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () {
                  Navigator.pop(context);
                  _handleMenuAction(context, 'file', provider);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Broken.box_add, color: theme.colorScheme.primary, size: 24),
                ),
                title: const Text('New Archive', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                subtitle: Text('Compress current folder contents', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                onTap: () {
                  Navigator.pop(context);
                  _handleMenuAction(context, 'archive', provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortModal(BuildContext context, FileManagerProvider provider) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('View & Sort Options', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Broken.close_circle), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Layout Mode', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              provider.setGridView(false);
                              setStateModal(() {});
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !provider.isGridView ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Broken.row_vertical, color: !provider.isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                                  const SizedBox(width: 8),
                                  Text('List View', style: TextStyle(fontWeight: FontWeight.bold, color: !provider.isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              provider.setGridView(true);
                              setStateModal(() {});
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: provider.isGridView ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Broken.element_3, color: provider.isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface),
                                  const SizedBox(width: 8),
                                  Text('Grid View', style: TextStyle(fontWeight: FontWeight.bold, color: provider.isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Icon & Folder Size', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text('${(provider.iconScale * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Slider(
                      value: provider.iconScale,
                      min: 0.7,
                      max: 1.5,
                      divisions: 8,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        provider.setIconScale(val);
                        setStateModal(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Sort By', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSortChip(context, provider, setStateModal, 'Name (A-Z)', FileSortType.nameAsc),
                        _buildSortChip(context, provider, setStateModal, 'Name (Z-A)', FileSortType.nameDesc),
                        _buildSortChip(context, provider, setStateModal, 'Newest', FileSortType.dateNewest),
                        _buildSortChip(context, provider, setStateModal, 'Oldest', FileSortType.dateOldest),
                        _buildSortChip(context, provider, setStateModal, 'Size (Large)', FileSortType.sizeLargest),
                        _buildSortChip(context, provider, setStateModal, 'Size (Small)', FileSortType.sizeSmallest),
                        _buildSortChip(context, provider, setStateModal, 'Type', FileSortType.type),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

  Widget _buildSortChip(BuildContext context, FileManagerProvider provider, StateSetter setStateModal, String label, FileSortType sortType) {
    final theme = Theme.of(context);
    final isSelected = provider.sortType == sortType;
    return ActionChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface)),
      backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
      onPressed: () {
        provider.setSortType(sortType);
        setStateModal(() {});
      },
    );
  }

  void _showStorageVolumeModal(BuildContext context, FileManagerProvider provider) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('Storage Volumes & SD Card', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.storageVolumes.length,
                  itemBuilder: (_, i) {
                    final vol = provider.storageVolumes[i];
                    final isSelected = provider.rootPath == vol.path;

                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(vol.isInternal ? Broken.folder_open : Icons.sd_storage_rounded, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface, size: 24),
                      ),
                      title: Text(vol.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 16)),
                      subtitle: Text(vol.path, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      trailing: isSelected ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.setRootPath(vol.path);
                        provider.loadDirectory(vol.path);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
            drawer: NFileDrawer(
              toggleTheme: widget.toggleTheme,
              onNavigateTab: widget.onNavigateTab,
            ),
            appBar: AppBar(
              title: isSelectionMode
                  ? Text('${provider.selectedPaths.length} selected')
                  : InkWell(
                      onTap: () => _showStorageVolumeModal(context, provider),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(provider.rootPath.contains('-') || provider.rootPath.toLowerCase().contains('sdcard') ? Icons.sd_storage_rounded : Broken.folder_open, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                p.basename(provider.currentPath).isEmpty || provider.currentPath == '/' || provider.currentPath == '/storage/emulated/0' ? 'Internal Storage' : p.basename(provider.currentPath),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 22),
                          ],
                        ),
                      ),
                    ),
              leading: isSelectionMode
                  ? IconButton(
                      icon: const Icon(Broken.close_square),
                      onPressed: () => provider.clearSelection(),
                    )
                  : provider.canGoBack
                      ? IconButton(
                          icon: const Icon(Broken.arrow_left),
                          onPressed: () => _goBack(provider),
                        )
                      : Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Broken.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
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
                      IconButton(
                        icon: const Icon(Broken.filter_edit),
                        tooltip: 'View & Sort Options',
                        onPressed: () => _showSortModal(context, provider),
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
                      if (!isSelectionMode && provider.showFolderFileCount)
                        SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1))),
                            ),
                            child: Row(
                              children: [
                                Icon(Broken.folder, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Text('folders: ${provider.currentFiles.where((e) => e.isDirectory).length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
                                const SizedBox(width: 20),
                                Icon(Broken.document, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Text('files: ${provider.currentFiles.where((e) => !e.isDirectory).length}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8))),
                              ],
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: EdgeInsets.only(
                          bottom: 80,
                          left: provider.isGridView ? 16 : 0,
                          right: provider.isGridView ? 16 : 0,
                          top: 8,
                        ),
                        sliver: provider.isGridView
                            ? SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: (MediaQuery.of(context).size.width / (110 * provider.iconScale)).floor().clamp(2, 6),
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.75,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = provider.currentFiles[index];
                                    final isSelected = provider.selectedPaths.contains(item.path);
                                    if (item.isDirectory) {
                                      return FolderGridItem(
                                        folder: item,
                                        isSelected: isSelected,
                                        iconScale: provider.iconScale,
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
                                      return FileGridItem(
                                        file: item,
                                        isSelected: isSelected,
                                        iconScale: provider.iconScale,
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
                              )
                            : SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final item = provider.currentFiles[index];
                                    final isSelected = provider.selectedPaths.contains(item.path);
                                    if (item.isDirectory) {
                                      return FolderItem(
                                        folder: item,
                                        isSelected: isSelected,
                                        iconScale: provider.iconScale,
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
                                        iconScale: provider.iconScale,
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
            floatingActionButtonLocation: isSelectionMode
                ? null
                : provider.showBottomActionBar
                    ? FloatingActionButtonLocation.centerDocked
                    : FloatingActionButtonLocation.endFloat,
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
                : (!isSelectionMode && provider.showFloatingAddButton)
                    ? FloatingActionButton(
                        onPressed: () => _showAddBottomSheet(context, provider),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: provider.showBottomActionBar ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)) : null,
                        child: const Icon(Broken.add, size: 28),
                      )
                    : null,
            bottomNavigationBar: (isSelectionMode || !provider.showBottomActionBar)
                ? null
                : BottomAppBar(
                    elevation: 8,
                    color: Theme.of(context).colorScheme.surface,
                    shape: const CircularNotchedRectangle(),
                    notchMargin: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: const Icon(Broken.tick_square),
                          tooltip: 'Select Mode',
                          onPressed: () {
                            if (provider.currentFiles.isNotEmpty) {
                              provider.toggleSelection(provider.currentFiles.first.path);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Broken.search_normal),
                          tooltip: 'Global Search',
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen())),
                        ),
                        const SizedBox(width: 48), // Center dock slot for FAB
                        IconButton(
                          icon: const Icon(Broken.filter_edit),
                          tooltip: 'View & Sort Options',
                          onPressed: () => _showSortModal(context, provider),
                        ),
                        IconButton(
                          icon: const Icon(Icons.sd_storage_rounded),
                          tooltip: 'Storage Volumes & SD Card',
                          onPressed: () => _showStorageVolumeModal(context, provider),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
