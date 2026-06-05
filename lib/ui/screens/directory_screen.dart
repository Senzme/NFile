import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../models/file_filter_type.dart';
import '../../models/drag_payload.dart';
import '../widgets/file_filter_bottom_sheet.dart';
import '../widgets/file_item.dart';
import '../widgets/folder_item.dart';
import '../widgets/file_grid_item.dart';
import '../widgets/folder_grid_item.dart';
import '../widgets/drag_drop_handler.dart';
import '../widgets/file_action_dialogs.dart';
import '../widgets/drag_drop_action_dialog.dart';
import '../widgets/create_archive_dialog.dart';
import '../widgets/batch_rename_dialog.dart';
import '../widgets/selection_action_bar.dart';
import '../widgets/selection_context_bottom_sheet.dart';
import '../widgets/file_operation_progress_dialog.dart';
import '../widgets/nfile_drawer.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'global_search_screen.dart';
import 'internal_file_picker_screen.dart';
import '../widgets/restricted_folder_banner.dart';
import '../widgets/directory_tab_bar.dart';
import '../../services/pin_service.dart';
import '../../services/folder_share_service.dart';
import '../widgets/pane_browser.dart';
import '../widgets/nfile_address_bar.dart';
import '../../services/network_connections_service.dart';
import 'network_connection_wizard_screen.dart';
import 'remote_explorer_screen.dart';

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
      provider.saveScrollOffset(provider.currentPath, _scrollController.offset);
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
      provider.saveScrollOffset(provider.currentPath, _scrollController.offset);
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
            context: context,
          );
        }
        break;
      case 'extract':
        await provider.extractArchiveDirectly(context, path);
        break;
      case 'copy':
        provider.copyFile(path);
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        break;
      case 'cut':
        provider.cutFile(path);
        // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cut to clipboard')));
        break;
      case 'rename':
        final isMulti = provider.selectedPaths.isNotEmpty && provider.selectedPaths.contains(path);
        if (isMulti && provider.selectedPaths.length > 1) {
          await BatchRenameDialog.show(context, provider);
        } else {
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
            if (isMulti) {
              provider.clearSelection();
            }
          }
        }
        break;
      case 'delete':
        final isMulti = provider.selectedPaths.isNotEmpty && provider.selectedPaths.contains(path);
        final confirm = await FileActionDialogs.showConfirmDialog(
          context,
          title: isMulti ? 'Delete Selected' : 'Delete Item',
          content: isMulti
              ? 'Are you sure you want to delete ${provider.selectedPaths.length} items? This cannot be undone.'
              : 'Are you sure you want to delete this item? This cannot be undone.',
        );
        if (confirm) {
          if (isMulti) {
            await provider.deleteSelected();
          } else {
            await provider.deleteFile(path);
          }
        }
        break;
      case 'share':
        final paths = (provider.selectedPaths.isNotEmpty && provider.selectedPaths.contains(path))
            ? provider.selectedPaths.toList()
            : [path];
        await FolderShareService.sharePaths(context, paths);
        break;
      case 'pin':
        await provider.togglePinPath(path);
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
          final createdName = await provider.createFile(fileName);
          if (createdName != null && createdName != fileName && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$fileName" already exists. Created "$createdName" instead.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
          final createdName = await provider.createFolder(folderName);
          if (createdName != null && createdName != folderName && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"$folderName" already exists. Created "$createdName" instead.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
            context: context,
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
    bool isAppearanceExpanded = false;
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
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: isAppearanceExpanded,
                          onExpansionChanged: (exp) {
                            isAppearanceExpanded = exp;
                          },
                          leading: Icon(Broken.setting_2, color: theme.colorScheme.primary),
                          title: Text('Size & Padding Options', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Icon & Folder Size', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text('${(provider.iconScale * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ],
                            ),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Item Padding & Spacing', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text('${(provider.itemPaddingMultiplier * 100).round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                              ],
                            ),
                            Slider(
                              value: provider.itemPaddingMultiplier,
                              min: 0.4,
                              max: 2.0,
                              divisions: 16,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (val) {
                                provider.setItemPaddingMultiplier(val);
                                setStateModal(() {});
                              },
                            ),
                          ],
                        ),
                      ),
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
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: provider.isFolderOverrideEnabled(provider.currentPath)
                            ? theme.colorScheme.primary.withOpacity(0.08)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: provider.isFolderOverrideEnabled(provider.currentPath)
                              ? theme.colorScheme.primary.withOpacity(0.25)
                              : theme.dividerColor.withOpacity(0.08),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Broken.folder_favorite,
                            color: provider.isFolderOverrideEnabled(provider.currentPath)
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.65),
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Only this folder',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Enable custom sorting specific to this folder',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: provider.isFolderOverrideEnabled(provider.currentPath),
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              provider.setFolderOverrideEnabled(provider.currentPath, val);
                              setStateModal(() {});
                            },
                          ),
                        ],
                      ),
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
    final activeSort = provider.getSortTypeForPath(provider.currentPath);
    final isSelected = activeSort == sortType;
    return ActionChip(
      label: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface)),
      backgroundColor: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
      onPressed: () {
        provider.setSortType(sortType);
        if (sortType == FileSortType.type) {
          Navigator.pop(context); // Close the sort sheet
          FileFilterBottomSheet.show(context); // Open filter sheet
        } else {
          setStateModal(() {});
        }
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
        final connections = NetworkConnectionsService.getConnections();
        return SafeArea(
          child: SingleChildScrollView(
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Storage Volumes',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                          icon: const Icon(Broken.folder_add, size: 18),
                          label: const Text('Add Shortcut', style: TextStyle(fontSize: 14)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final picked = await InternalFilePickerScreen.show(
                              context,
                              rootPath: provider.storageVolumes.isNotEmpty ? provider.storageVolumes.first.path : '/storage/emulated/0',
                              pickDirectory: true,
                            );
                            if (picked != null && picked.isNotEmpty) {
                              for (final path in picked) {
                                final label = p.basename(path).isEmpty ? path : p.basename(path);
                                provider.addPinnedFolderShortcut(path, label);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...provider.storageVolumes.map((vol) {
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
                  }),
                  ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: provider.rootPath == '/' ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Broken.cpu, color: provider.rootPath == '/' ? theme.colorScheme.primary : theme.colorScheme.onSurface, size: 24),
                    ),
                    title: Text('System Root', style: TextStyle(fontWeight: provider.rootPath == '/' ? FontWeight.bold : FontWeight.w600, fontSize: 16)),
                    subtitle: Text('/', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                    trailing: provider.rootPath == '/' ? Icon(Icons.check_circle, color: theme.colorScheme.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      provider.setRootPath('/');
                      provider.loadDirectory('/');
                    },
                  ),
                  ...provider.pinnedFolderShortcuts.map((item) {
                    final isSelected = provider.rootPath == item.path || provider.currentPath == item.path;
                    return ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary.withOpacity(0.2) : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Broken.folder_favorite, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface, size: 24),
                      ),
                      title: Text(item.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 16)),
                      subtitle: Text(item.path, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            Icon(Icons.check_circle, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                          ],
                          IconButton(
                            icon: const Icon(Broken.trash, size: 20, color: Colors.redAccent),
                            onPressed: () {
                              provider.removePinnedFolderShortcut(item.id);
                              Navigator.pop(ctx);
                              _showStorageVolumeModal(context, provider);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        provider.setRootPath(item.path);
                        provider.loadDirectory(item.path);
                      },
                    );
                  }),

                  // Network Connections Section
                  if (connections.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Network Connections',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontFamily: 'LexendDeca',
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_link_rounded, size: 20),
                            tooltip: 'Add Network Connection',
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final added = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NetworkConnectionWizardScreen(),
                                ),
                              );
                              if (added == true) {
                                _showStorageVolumeModal(context, provider);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Divider(height: 8, thickness: 1),
                    ),
                    ...connections.map((conn) {
                      IconData iconData;
                      switch (conn.type) {
                        case 'Google Drive':
                          iconData = Icons.cloud_circle_rounded;
                          break;
                        case 'Dropbox':
                          iconData = Icons.folder_shared_rounded;
                          break;
                        case 'OneDrive':
                          iconData = Icons.cloud_queue_rounded;
                          break;
                        case 'Box':
                          iconData = Icons.all_inbox_rounded;
                          break;
                        case 'LAN/SMB':
                          iconData = Icons.dns_rounded;
                          break;
                        case 'FTP':
                          iconData = Icons.swap_horizontal_circle_rounded;
                          break;
                        case 'SFTP':
                          iconData = Icons.vpn_lock_rounded;
                          break;
                        case 'WebDav':
                          iconData = Icons.web_rounded;
                          break;
                        default:
                          iconData = Broken.wifi;
                      }
                      return ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(iconData, color: theme.colorScheme.primary, size: 22),
                        ),
                        title: Text(conn.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        subtitle: Text('${conn.type} • ${conn.host}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                        trailing: IconButton(
                          icon: const Icon(Broken.trash, size: 20, color: Colors.redAccent),
                          tooltip: 'Remove Connection',
                          onPressed: () async {
                            await NetworkConnectionsService.deleteConnection(conn.id);
                            Navigator.pop(ctx);
                            _showStorageVolumeModal(context, provider);
                          },
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RemoteExplorerScreen(connection: conn),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ],
              ),
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
        final theme = Theme.of(context);
        final isSelectionMode = provider.isSelectionMode;

        if (provider.shouldScrollToHighlight) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              provider.resetScrollToHighlight();
              final firstHighlightedIndex = provider.currentFiles.indexWhere(
                (f) => provider.highlightedPaths.contains(f.path),
              );
              if (firstHighlightedIndex != -1) {
                double targetOffset = 0.0;
                if (provider.isGridView) {
                  final crossAxisCount = (MediaQuery.of(context).size.width / (110 * provider.iconScale)).floor().clamp(2, 6);
                  final row = firstHighlightedIndex ~/ crossAxisCount;
                  final itemHeight = (150 * provider.iconScale * provider.itemPaddingMultiplier).clamp(100.0, 300.0);
                  targetOffset = row * itemHeight;
                } else {
                  final itemHeight = (72 * provider.itemPaddingMultiplier).clamp(40.0, 150.0);
                  targetOffset = firstHighlightedIndex * itemHeight;
                }
                _scrollController.jumpTo(
                  targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                );
              }
            }
          });
        }

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
              titleSpacing: 0,
              centerTitle: false,
              title: isSelectionMode
                  ? Text('${provider.selectedPaths.length}/${provider.currentFiles.length}')
                  : _AnimatedTitleButton(
                      onTap: () => _showStorageVolumeModal(context, provider),
                    ),
              bottom: (isSelectionMode || !provider.enableMultipleTabs) ? null : DirectoryTabBar(provider: provider),
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
                  ? provider.showBottomActionBar
                      ? [
                          IconButton(
                            icon: const Icon(Broken.tick_square),
                            tooltip: 'Select All',
                            onPressed: () => provider.selectAll(),
                          ),
                        ]
                      : [
                          IconButton(
                            icon: const Icon(Broken.document_copy),
                            tooltip: 'Copy',
                            onPressed: () {
                              provider.copySelected();
                              // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied selected items')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Broken.scissor),
                            tooltip: 'Cut',
                            onPressed: () {
                              provider.cutSelected();
                              // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cut selected items')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Broken.edit),
                            tooltip: 'Rename',
                            onPressed: () async {
                              if (provider.selectedPaths.length == 1) {
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
                              } else if (provider.selectedPaths.length > 1) {
                                await BatchRenameDialog.show(context, provider);
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
                          PopupMenuButton<String>(
                            icon: const Icon(Broken.more),
                            tooltip: 'More Actions',
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            position: PopupMenuPosition.under,
                            elevation: 8,
                            onSelected: (action) async {
                              if (action == 'select_all') {
                                provider.selectAll();
                              } else if (action == 'pin_to_top') {
                                final selected = provider.selectedPaths.toList();
                                final allPinned = selected.every((p) => PinService.isPinned(p));
                                for (final path in selected) {
                                  if (allPinned) {
                                    await PinService.unpin(path);
                                  } else {
                                    await PinService.pin(path);
                                  }
                                }
                                provider.refreshDirectoryView();
                                provider.clearSelection();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(allPinned ? 'Unpinned selected item(s)' : 'Pinned selected item(s) to top'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } else if (action == 'properties') {
                                final selectedPaths = provider.selectedPaths.toList();
                                if (selectedPaths.isNotEmpty) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => PropertiesModalDialog(
                                      selectedPaths: selectedPaths,
                                      provider: provider,
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) {
                              final selected = provider.selectedPaths.toList();
                              final allPinned = selected.isNotEmpty && selected.every((p) => PinService.isPinned(p));
                              return [
                                const PopupMenuItem<String>(
                                  value: 'select_all',
                                  child: Row(
                                    children: [
                                      Icon(Broken.tick_square, size: 20),
                                      SizedBox(width: 12),
                                      Text('Select All', style: TextStyle(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'pin_to_top',
                                  child: Row(
                                    children: [
                                      Icon(
                                        allPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, 
                                        size: 20, 
                                        color: allPinned ? Colors.orange : null
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        allPinned ? 'Unpin from Top' : 'Pin to Top', 
                                        style: const TextStyle(fontWeight: FontWeight.w500)
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'properties',
                                  child: Row(
                                    children: [
                                      Icon(Broken.info_circle, size: 20),
                                      const SizedBox(width: 12),
                                      Text('Properties', style: TextStyle(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ]
                  : provider.showBottomActionBar
                      ? [
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
                        ]
                      : [
                          IconButton(
                            icon: const Icon(Broken.search_normal),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchScreen(searchFolderPath: provider.currentPath)));
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
            body: Column(
              children: [
                if (provider.showAddressBar) const NFileAddressBar(),
                if (provider.filterType != FileFilterType.all)
                  _buildActiveFilterBanner(context, provider),
                if (provider.isLoading && provider.currentFiles.isNotEmpty)
                  LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                Expanded(
                  child: DragTarget<DragPayload>(
                    onWillAccept: (data) {
                      if (data == null || data.paths.isEmpty) return false;
                      final sourceParent = p.dirname(data.paths.first);
                      if (sourceParent == provider.currentPath) return false;
                      if (data.paths.any((x) => provider.currentPath == x || provider.currentPath.startsWith(x + p.separator))) return false;
                      return true;
                    },
                    onAccept: (data) {
                      if (provider.showDragDropDialog) {
                        DragDropActionDialog.show(
                          context: context,
                          sourcePaths: data.paths,
                          initialTargetPath: provider.currentPath,
                        );
                      } else {
                        for (final path in data.paths) {
                          provider.moveItem(context, path, provider.currentPath);
                        }
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (!provider.enableMultipleTabs || provider.enableSplitScreen || isSelectionMode) {
                        return;
                      }
                      final velocity = details.primaryVelocity ?? 0.0;
                      // Swipe Left (moves right-to-left) -> Next Tab
                      if (velocity < -300) {
                        if (provider.activeTabIndex < provider.tabs.length - 1) {
                          provider.setActiveTab(provider.activeTabIndex + 1);
                        }
                      }
                      // Swipe Right (moves left-to-right) -> Previous Tab
                      else if (velocity > 300) {
                        if (provider.activeTabIndex > 0) {
                          provider.setActiveTab(provider.activeTabIndex - 1);
                        }
                      }
                    },
                    behavior: HitTestBehavior.translucent,
                    child: provider.enableSplitScreen
                      ? const Row(
                          children: [
                            Expanded(child: PaneBrowser(tabIndex: 0)),
                            Expanded(child: PaneBrowser(tabIndex: 1)),
                          ],
                        )
                      : (provider.isLoading && provider.currentFiles.isEmpty)
                          ? const Center(child: CircularProgressIndicator())
                          : provider.needsPermission
                              ? RestrictedFolderBanner(
                                  onEnableRoot: () => provider.enableRootMode(),
                                  onEnableShizuku: () => provider.enableShizukuMode(),
                                  isRootAvailable: provider.isRootAvailable,
                                )
                              : CustomScrollView(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () => provider.loadDirectory(provider.currentPath, showLoading: false, clearCache: true),
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
                      if (provider.currentFiles.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Broken.folder_open,
                                      size: 72,
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Empty Folder',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'This directory does not contain any files or subfolders.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
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
                                    mainAxisSpacing: (12 * provider.itemPaddingMultiplier).clamp(4.0, 24.0),
                                    crossAxisSpacing: (12 * provider.itemPaddingMultiplier).clamp(4.0, 24.0),
                                    childAspectRatio: 0.75,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final item = provider.currentFiles[index];
                                      final isSelected = provider.selectedPaths.contains(item.path);
                                      if (item.isDirectory) {
                                        final itemLongPress = () {
                                          if (isSelectionMode && isSelected) {
                                            SelectionContextBottomSheet.show(context, provider, item.path);
                                          } else {
                                            provider.toggleSelection(item.path);
                                          }
                                        };
                                        return DragDropHandler(
                                          path: item.path,
                                          isDirectory: true,
                                          onLongPress: itemLongPress,
                                          child: FolderGridItem(
                                            folder: item,
                                            isSelected: isSelected,
                                            iconScale: provider.iconScale,
                                            itemPaddingMultiplier: provider.itemPaddingMultiplier,
                                            onTap: () {
                                              if (isSelectionMode) {
                                                provider.toggleSelection(item.path);
                                              } else {
                                                _openFolder(provider, item.path);
                                              }
                                            },
                                            onLongPress: provider.enableDragDrop ? null : itemLongPress,
                                            onIconTap: itemLongPress,
                                            onAction: (action) => _handleAction(context, action, item.path),
                                          ),
                                        );
                                      } else {
                                        final itemLongPress = () {
                                          if (isSelectionMode && isSelected) {
                                            SelectionContextBottomSheet.show(context, provider, item.path);
                                          } else {
                                            provider.toggleSelection(item.path);
                                          }
                                        };
                                        return DragDropHandler(
                                          path: item.path,
                                          isDirectory: false,
                                          onLongPress: itemLongPress,
                                          child: FileGridItem(
                                            file: item,
                                            isSelected: isSelected,
                                            iconScale: provider.iconScale,
                                            itemPaddingMultiplier: provider.itemPaddingMultiplier,
                                            onTap: () {
                                              if (isSelectionMode) {
                                                provider.toggleSelection(item.path);
                                              } else {
                                                provider.openFile(context, item.path, showOpenWithPopup: true);
                                              }
                                            },
                                            onLongPress: provider.enableDragDrop ? null : itemLongPress,
                                            onIconTap: itemLongPress,
                                            onAction: (action) => _handleAction(context, action, item.path),
                                          ),
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
                                        final itemLongPress = () {
                                          if (isSelectionMode && isSelected) {
                                            SelectionContextBottomSheet.show(context, provider, item.path);
                                          } else {
                                            provider.toggleSelection(item.path);
                                          }
                                        };
                                        return DragDropHandler(
                                          path: item.path,
                                          isDirectory: true,
                                          onLongPress: itemLongPress,
                                          child: FolderItem(
                                            folder: item,
                                            isSelected: isSelected,
                                            iconScale: provider.iconScale,
                                            itemPaddingMultiplier: provider.itemPaddingMultiplier,
                                            onTap: () {
                                              if (isSelectionMode) {
                                                provider.toggleSelection(item.path);
                                              } else {
                                                _openFolder(provider, item.path);
                                              }
                                            },
                                            onLongPress: provider.enableDragDrop ? null : itemLongPress,
                                            onIconTap: itemLongPress,
                                            onAction: (action) => _handleAction(context, action, item.path),
                                          ),
                                        );
                                      } else {
                                        final itemLongPress = () {
                                          if (isSelectionMode && isSelected) {
                                            SelectionContextBottomSheet.show(context, provider, item.path);
                                          } else {
                                            provider.toggleSelection(item.path);
                                          }
                                        };
                                        return DragDropHandler(
                                          path: item.path,
                                          isDirectory: false,
                                          onLongPress: itemLongPress,
                                          child: FileItem(
                                            file: item,
                                            isSelected: isSelected,
                                            iconScale: provider.iconScale,
                                            itemPaddingMultiplier: provider.itemPaddingMultiplier,
                                            onTap: () {
                                              if (isSelectionMode) {
                                                provider.toggleSelection(item.path);
                                              } else {
                                                provider.openFile(context, item.path, showOpenWithPopup: true);
                                              }
                                            },
                                            onLongPress: provider.enableDragDrop ? null : itemLongPress,
                                            onIconTap: itemLongPress,
                                            onAction: (action) => _handleAction(context, action, item.path),
                                          ),
                                        );
                                      }
                                    },
                                    childCount: provider.currentFiles.length,
                                  ),
                                ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
            floatingActionButtonLocation: isSelectionMode
                ? null
                : provider.showBottomActionBar
                    ? FloatingActionButtonLocation.centerDocked
                    : FloatingActionButtonLocation.endFloat,
            floatingActionButton: (() {
              if (provider.hasClipboard) {
                return Padding(
                  padding: EdgeInsets.only(bottom: provider.showBottomActionBar ? 0 : 16),
                  child: GestureDetector(
                    onLongPress: () {
                      provider.clearClipboard();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Action cancelled / Clipboard cleared'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    onDoubleTap: () async {
                      FileOperationProgressDialog.show(context, provider);
                      await provider.pasteFile(context, clearAfterPaste: false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pasted (holding clipboard for multiple pastes)'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: FloatingActionButton.extended(
                      onPressed: () async {
                        FileOperationProgressDialog.show(context, provider);
                        await provider.pasteFile(context, clearAfterPaste: true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Pasted successfully'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Broken.clipboard),
                      label: const Text('Paste Here'),
                    ),
                  ),
                );
              }
              if (!isSelectionMode && provider.showFloatingAddButton) {
                return Padding(
                  padding: EdgeInsets.only(bottom: provider.showBottomActionBar ? 0 : 16),
                  child: FloatingActionButton(
                    onPressed: () => _showAddBottomSheet(context, provider),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shape: provider.showBottomActionBar ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)) : null,
                    child: const Icon(Broken.add, size: 28),
                  ),
                );
              }
              return null;
            })(),
            bottomNavigationBar: (isSelectionMode && provider.showBottomActionBar)
                ? SelectionActionBar(provider: provider)
                : !provider.showBottomActionBar
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
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalSearchScreen(searchFolderPath: provider.currentPath))),
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

  Widget _buildActiveFilterBanner(BuildContext context, FileManagerProvider provider) {
    final theme = Theme.of(context);
    final filter = provider.filterType;
    String label = '';
    IconData icon = Broken.category;
    Color color = theme.colorScheme.primary;

    switch (filter) {
      case FileFilterType.all:
        break;
      case FileFilterType.documents:
        label = 'Documents only';
        icon = Broken.document;
        color = Colors.blueAccent;
        break;
      case FileFilterType.images:
        label = 'Images only';
        icon = Broken.image;
        color = Colors.purpleAccent;
        break;
      case FileFilterType.audio:
        label = 'Audio only';
        icon = Broken.music;
        color = Colors.greenAccent;
        break;
      case FileFilterType.videos:
        label = 'Videos only';
        icon = Broken.video;
        color = Colors.redAccent;
        break;
      case FileFilterType.archives:
        label = 'Archives only';
        icon = Broken.archive;
        color = Colors.brown;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label Filter Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                backgroundColor: color.withOpacity(0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => provider.toggleHideFoldersInFilter(),
              icon: Icon(
                provider.hideFoldersInFilter ? Broken.folder : Broken.folder_connection,
                color: color,
                size: 15,
              ),
              label: Text(
                provider.hideFoldersInFilter ? 'Show Folders' : 'Hide Folders',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => provider.setFilterType(FileFilterType.all),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Broken.close_square, color: color, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTitleButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedTitleButton({required this.onTap});

  @override
  State<_AnimatedTitleButton> createState() => _AnimatedTitleButtonState();
}

class _AnimatedTitleButtonState extends State<_AnimatedTitleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            splashColor: theme.colorScheme.primary.withOpacity(0.3),
            highlightColor: theme.colorScheme.primary.withOpacity(0.15),
            onTapDown: (_) => _controller.forward(),
            onTapCancel: () => _controller.reverse(),
            onTap: () {
              _controller.reverse();
              widget.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Files',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: -0.5),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Broken.arrow_down_2, size: 16, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
