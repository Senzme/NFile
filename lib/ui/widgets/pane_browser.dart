import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_avif/flutter_avif.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../models/file_item_model.dart';
import '../../models/folder_tab_model.dart';
import '../../models/drag_payload.dart';
import '../../models/file_filter_type.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../core/utils.dart';
import 'file_item.dart';
import 'folder_item.dart';
import 'file_grid_item.dart';
import 'folder_grid_item.dart';
import 'drag_drop_handler.dart';
import 'restricted_folder_banner.dart';
import 'selection_context_bottom_sheet.dart';
import 'file_action_dialogs.dart';
import 'create_archive_dialog.dart';

class PaneBrowser extends StatefulWidget {
  final int tabIndex;
  const PaneBrowser({super.key, required this.tabIndex});

  @override
  State<PaneBrowser> createState() => _PaneBrowserState();
}

class _PaneBrowserState extends State<PaneBrowser> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _activatePane(FileManagerProvider provider) {
    if (provider.activeTabIndex != widget.tabIndex) {
      provider.setActiveTab(widget.tabIndex);
    }
  }

  void _openFolder(FileManagerProvider provider, String path) {
    _activatePane(provider);
    if (_scrollController.hasClients) {
      provider.saveScrollOffset(provider.tabs[widget.tabIndex].currentPath, _scrollController.offset);
    }
    provider.loadDirectory(path).then((_) {
      if (_scrollController.hasClients) {
        final savedOffset = provider.getSavedScrollOffset(path);
        _scrollController.jumpTo(savedOffset);
      }
    });
  }

  void _goBack(FileManagerProvider provider) async {
    _activatePane(provider);
    if (_scrollController.hasClients) {
      provider.saveScrollOffset(provider.tabs[widget.tabIndex].currentPath, _scrollController.offset);
    }
    final prevPath = p.dirname(provider.tabs[widget.tabIndex].currentPath);
    final handled = await provider.goBack();
    if (handled && _scrollController.hasClients) {
      final savedOffset = provider.getSavedScrollOffset(prevPath);
      _scrollController.jumpTo(savedOffset);
    }
  }

  void _handleAction(BuildContext context, String action, String path) async {
    final provider = context.read<FileManagerProvider>();
    _activatePane(provider);
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
        break;
      case 'cut':
        provider.cutFile(path);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FileManagerProvider>();
    
    if (widget.tabIndex >= provider.tabs.length) {
      return const SizedBox.shrink();
    }
    
    final FolderTab tab = provider.tabs[widget.tabIndex];
    final isActive = provider.activeTabIndex == widget.tabIndex;
    final isSelectionMode = tab.selectedPaths.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _activatePane(provider),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(isActive ? 1.0 : 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
                ? theme.colorScheme.primary.withOpacity(0.8) 
                : theme.colorScheme.outline.withOpacity(0.15),
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.08),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ] : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Column(
                children: [
                  // --- Pane Custom Header ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive 
                          ? theme.colorScheme.primary.withOpacity(0.06) 
                          : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Glow/Active indicator dot or icon
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? const Color(0xFF00C853) : Colors.grey.withOpacity(0.6),
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: const Color(0xFF00C853).withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ] : null,
                          ),
                        ),
                        const Spacer(),
                        // UP button for parent directory
                        if (tab.currentPath != '/' && tab.currentPath != provider.rootPath)
                          IconButton(
                            icon: const Icon(Broken.arrow_up_1, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _goBack(provider),
                            tooltip: 'Go to Parent Directory',
                          ),
                      ],
                    ),
                  ),
                  if (tab.isLoading && tab.currentFiles.isNotEmpty)
                    LinearProgressIndicator(
                      minHeight: 2.0,
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  
                  // --- Scrollable Breadcrumbs Path ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          Icon(Broken.folder, size: 14, color: theme.colorScheme.primary.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            tab.currentPath,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.filterType != FileFilterType.all)
                    _buildActiveFilterBanner(context, provider),
                  
                  // --- Pane Body ---
                  Expanded(
                    child: DragTarget<DragPayload>(
                      onWillAccept: (data) {
                        if (data == null) return false;
                        final sourceParent = p.dirname(data.path);
                        if (sourceParent == tab.currentPath) return false;
                        if (tab.currentPath == data.path) return false;
                        if (tab.currentPath.startsWith(data.path + p.separator)) return false;
                        return true;
                      },
                      onAccept: (data) {
                        _activatePane(provider);
                        provider.moveItem(context, data.path, tab.currentPath);
                      },
                      builder: (context, candidateData, rejectedData) {
                        return (tab.isLoading && tab.currentFiles.isEmpty)
                            ? const Center(child: CircularProgressIndicator())
                            : tab.needsPermission
                                ? RestrictedFolderBanner(
                                    onEnableRoot: () {
                                      _activatePane(provider);
                                      provider.enableRootMode();
                                    },
                                    onEnableShizuku: () {
                                      _activatePane(provider);
                                      provider.enableShizukuMode();
                                    },
                                    isRootAvailable: tab.isRootAvailable,
                                  )
                                : CustomScrollView(
                                      controller: _scrollController,
                                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                      slivers: [
                                      CupertinoSliverRefreshControl(
                                        onRefresh: () => provider.loadDirectoryForTab(widget.tabIndex, tab.currentPath, showLoading: false),
                                      ),
                                      if (tab.currentFiles.isEmpty)
                                        SliverFillRemaining(
                                          hasScrollBody: false,
                                          child: Center(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(16),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.primary.withOpacity(0.08),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Broken.folder_open,
                                                      size: 48,
                                                      color: theme.colorScheme.primary.withOpacity(0.6),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    'Empty Folder',
                                                    style: theme.textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.onSurface,
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
                                            left: provider.isGridView ? 8 : 0,
                                            right: provider.isGridView ? 8 : 0,
                                            top: 8,
                                          ),
                                          sliver: provider.isGridView
                                              ? SliverGrid(
                                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: (MediaQuery.of(context).size.width / (2 * 110 * provider.iconScale)).floor().clamp(1, 3),
                                                    mainAxisSpacing: (8 * provider.itemPaddingMultiplier).clamp(4.0, 16.0),
                                                    crossAxisSpacing: (8 * provider.itemPaddingMultiplier).clamp(4.0, 16.0),
                                                    childAspectRatio: 0.75,
                                                  ),
                                                  delegate: SliverChildBuilderDelegate(
                                                    (context, index) {
                                                      final item = tab.currentFiles[index];
                                                      final isSelected = tab.selectedPaths.contains(item.path);
                                                      if (item.isDirectory) {
                                                        final itemLongPress = () {
                                                          _activatePane(provider);
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
                                                              _activatePane(provider);
                                                              if (isSelectionMode) {
                                                                provider.toggleSelection(item.path);
                                                              } else {
                                                                _openFolder(provider, item.path);
                                                              }
                                                            },
                                                            onLongPress: provider.enableDragDrop ? null : itemLongPress,
                                                            onAction: (action) => _handleAction(context, action, item.path),
                                                          ),
                                                        );
                                                      } else {
                                                        final itemLongPress = () {
                                                          _activatePane(provider);
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
                                                              _activatePane(provider);
                                                              if (isSelectionMode) {
                                                                provider.toggleSelection(item.path);
                                                              } else {
                                                                provider.openFile(context, item.path, showOpenWithPopup: true);
                                                              }
                                                            },
                                                            onLongPress: provider.enableDragDrop ? null : itemLongPress,
                                                            onAction: (action) => _handleAction(context, action, item.path),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    childCount: tab.currentFiles.length,
                                                  ),
                                                )
                                              : SliverList(
                                                  delegate: SliverChildBuilderDelegate(
                                                    (context, index) {
                                                      final item = tab.currentFiles[index];
                                                      final isSelected = tab.selectedPaths.contains(item.path);
                                                      if (item.isDirectory) {
                                                        return _buildCompactFolderItem(
                                                          context,
                                                          provider,
                                                          item,
                                                          isSelected,
                                                          isSelectionMode,
                                                        );
                                                      } else {
                                                        return _buildCompactFileItem(
                                                          context,
                                                          provider,
                                                          item,
                                                          isSelected,
                                                          isSelectionMode,
                                                        );
                                                      }
                                                    },
                                                    childCount: tab.currentFiles.length,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    );
                      },
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFolderItem(
    BuildContext context,
    FileManagerProvider provider,
    FileItemModel folder,
    bool isSelected,
    bool isSelectionMode,
  ) {
    final theme = Theme.of(context);
    final isHighlighted = provider.enableFolderHighlight && provider.highlightedPaths.contains(folder.path);

    final itemLongPress = () {
      _activatePane(provider);
      if (isSelectionMode && isSelected) {
        SelectionContextBottomSheet.show(context, provider, folder.path);
      } else {
        provider.toggleSelection(folder.path);
      }
    };

    return DragDropHandler(
      path: folder.path,
      isDirectory: true,
      onLongPress: itemLongPress,
      child: InkWell(
        onTap: () {
          _activatePane(provider);
          if (isSelectionMode) {
            provider.toggleSelection(folder.path);
          } else {
            _openFolder(provider, folder.path);
          }
        },
        onLongPress: provider.enableDragDrop ? null : itemLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                : isHighlighted
                    ? theme.colorScheme.primary.withOpacity(0.05)
                    : Colors.transparent,
            border: isHighlighted
                ? Border(
                    left: BorderSide(color: theme.colorScheme.primary, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isSelected
                      ? Broken.tick_circle
                      : FileUtils.getFolderIcon(provider.folderIconOption),
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Consumer<FileManagerProvider>(
                      builder: (context, provider, _) {
                        final activeFilter = provider.filterType;
                        if (activeFilter != FileFilterType.all) {
                          return FutureBuilder<int>(
                            future: provider.getMatchingFileCount(folder.path, activeFilter),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              final name = provider.getFilterTypeName(activeFilter, count);
                              return Text(
                                '$count $name',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          );
                        } else {
                          if (provider.hideTimeAndDate && !provider.showFolderContentsCount) {
                            return const SizedBox.shrink();
                          }
                          if (provider.showFolderContentsCount) {
                            return FutureBuilder<int>(
                              future: provider.getFolderItemCount(folder.path),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                final countStr = count == 1 ? '1 item' : '$count items';
                                if (provider.hideTimeAndDate) {
                                  return Text(
                                    countStr,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
                                      fontSize: 10.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                } else {
                                  return Text(
                                    '$countStr • ${FileUtils.formatDate(folder.modified, use24Hour: provider.use24HourFormat)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
                                      fontSize: 10.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }
                              },
                            );
                          } else {
                            return Text(
                              FileUtils.formatDate(folder.modified, use24Hour: provider.use24HourFormat),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
                                fontSize: 10.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFileItem(
    BuildContext context,
    FileManagerProvider provider,
    FileItemModel file,
    bool isSelected,
    bool isSelectionMode,
  ) {
    final theme = Theme.of(context);
    final isHighlighted = provider.enableFolderHighlight && provider.highlightedPaths.contains(file.path);
    final iconColor = FileUtils.getColorForFile(file.path, context);
    final isArchive = FileUtils.isArchive(file.path);

    final itemLongPress = () {
      _activatePane(provider);
      if (isSelectionMode && isSelected) {
        SelectionContextBottomSheet.show(context, provider, file.path);
      } else {
        provider.toggleSelection(file.path);
      }
    };

    return DragDropHandler(
      path: file.path,
      isDirectory: false,
      onLongPress: itemLongPress,
      child: InkWell(
        onTap: () {
          _activatePane(provider);
          if (isSelectionMode) {
            provider.toggleSelection(file.path);
          } else {
            provider.openFile(context, file.path, showOpenWithPopup: true);
          }
        },
        onLongPress: provider.enableDragDrop ? null : itemLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                : isHighlighted
                    ? theme.colorScheme.primary.withOpacity(0.05)
                    : Colors.transparent,
            border: isHighlighted
                ? Border(
                    left: BorderSide(color: theme.colorScheme.primary, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _CompactMediaThumbnail(
                    file: file,
                    isSelected: isSelected,
                    iconColor: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      provider.hideTimeAndDate
                          ? FileUtils.formatBytes(file.size, 1)
                          : "${FileUtils.formatDate(file.modified, use24Hour: provider.use24HourFormat)}   ${FileUtils.formatBytes(file.size, 1)}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
                        fontSize: 10.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ]
          ),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label Active',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ),
            InkWell(
              onTap: () => provider.toggleHideFoldersInFilter(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  provider.hideFoldersInFilter ? Broken.folder : Broken.folder_connection,
                  color: color,
                  size: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => provider.setFilterType(FileFilterType.all),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Broken.close_square, color: color, size: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMediaThumbnail extends StatefulWidget {
  final FileItemModel file;
  final bool isSelected;
  final Color iconColor;

  const _CompactMediaThumbnail({
    required this.file,
    required this.isSelected,
    required this.iconColor,
  });

  @override
  State<_CompactMediaThumbnail> createState() => _CompactMediaThumbnailState();
}

class _CompactMediaThumbnailState extends State<_CompactMediaThumbnail> {
  Uint8List? _videoThumb;
  Uint8List? _audioThumb;

  @override
  void initState() {
    super.initState();
    if (FileUtils.isVideo(widget.file.path)) {
      _loadVideoThumb();
    } else if (FileUtils.isAudio(widget.file.path)) {
      _loadAudioThumb();
    }
  }

  Future<void> _loadAudioThumb() async {
    if (!mounted) return;
    try {
      final mediaProvider = context.read<MediaProvider>();
      final match = mediaProvider.audios.where((s) => s.data == widget.file.path).firstOrNull;
      if (match != null) {
        final artwork = await OnAudioQuery().queryArtwork(
          match.id,
          ArtworkType.AUDIO,
          size: 150,
          quality: 50,
        );
        if (mounted && artwork != null && artwork.isNotEmpty) {
          setState(() {
            _audioThumb = artwork;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadVideoThumb() async {
    if (!mounted) return;
    try {
      final mediaProvider = context.read<MediaProvider>();
      final match = mediaProvider.videos.where((v) {
        final titleLower = (v.title ?? '').toLowerCase();
        final nameLower = widget.file.name.toLowerCase();
        
        // Case 1: title matches filename exactly
        if (titleLower == nameLower) return true;
        
        // Case 2: title is basename without extension, e.g. title="my_video", filename="my_video.mp4"
        final extIndex = nameLower.lastIndexOf('.');
        final ext = extIndex != -1 ? nameLower.substring(extIndex) : '';
        if (ext.isNotEmpty) {
          final baseName = nameLower.substring(0, extIndex);
          if (titleLower == baseName || '${titleLower}${ext}' == nameLower) {
            return true;
          }
        }
        
        // Case 3: Match via mimeType
        final mimeExt = v.mimeType?.split("/").last.toLowerCase();
        if (mimeExt != null && '${titleLower}.$mimeExt' == nameLower) {
          return true;
        }
        
        return false;
      }).firstOrNull;

      if (match != null) {
        final thumb = await ThumbnailCache.get(match);
        if (mounted && thumb != null) {
          setState(() {
            _videoThumb = thumb;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final showMediaPreviews = context.select<FileManagerProvider, bool>((p) => p.showMediaPreviews);
    final isImg = FileUtils.isImage(widget.file.path);
    final isVid = FileUtils.isVideo(widget.file.path);
    final isAud = FileUtils.isAudio(widget.file.path);

    if (widget.isSelected) {
      return Icon(Broken.tick_circle, color: Theme.of(context).colorScheme.onPrimary, size: 18);
    }

    if (!showMediaPreviews) {
      return Icon(
        FileUtils.getIconForFile(widget.file.path),
        color: widget.iconColor,
        size: 18,
      );
    }

    if (isImg && widget.file.size > 16) {
      if (widget.file.path.toLowerCase().endsWith('.avif')) {
        return AvifImage.file(
          File(widget.file.path),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Icon(Broken.image, color: widget.iconColor, size: 18),
        );
      }
      return Image.file(
        File(widget.file.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 80,
        errorBuilder: (context, error, stackTrace) => Icon(Broken.image, color: widget.iconColor, size: 18),
      );
    }

    if (isVid && _videoThumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _videoThumb!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Icon(Broken.video, color: widget.iconColor, size: 18),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: Icon(Broken.video, color: Colors.white, size: 10),
            ),
          ),
        ],
      );
    }

    if (isAud && _audioThumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _audioThumb!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Icon(Broken.music, color: widget.iconColor, size: 18),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
              child: Icon(Broken.music, color: Colors.white, size: 10),
            ),
          ),
        ],
      );
    }

    return Icon(
      FileUtils.getIconForFile(widget.file.path),
      color: widget.iconColor,
      size: 18,
    );
  }
}
