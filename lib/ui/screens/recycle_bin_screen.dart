import 'package:flutter/material.dart';
import '../../models/file_item_model.dart';
import '../../services/recycle_bin_service.dart';
import '../../core/utils.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'package:path/path.dart' as p;

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  List<RecycleBinItem> _allItems = [];
  List<RecycleBinItem> _filteredItems = [];
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _allItems = RecycleBinService.getTrashItems();
      _filterItems();
    });
  }

  void _filterItems() {
    if (_searchQuery.trim().isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      _filteredItems = _allItems
          .where((item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }

      if (_selectedIds.isEmpty) {
        _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _restoreSelected() async {
    final itemsToRestore = _allItems.where((item) => _selectedIds.contains(item.id)).toList();
    if (itemsToRestore.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final item in itemsToRestore) {
        await RecycleBinService.restoreItem(item);
      }
      if (mounted) Navigator.pop(context); // Dismiss loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${itemsToRestore.length} item(s) successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error restoring items: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _clearSelection();
    _loadItems();
  }

  Future<void> _deleteSelectedPermanently() async {
    final itemsToDelete = _allItems.where((item) => _selectedIds.contains(item.id)).toList();
    if (itemsToDelete.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Permanently?'),
        content: Text('Are you sure you want to permanently delete these ${itemsToDelete.length} item(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      for (final item in itemsToDelete) {
        await RecycleBinService.deletePermanently(item);
      }
      if (mounted) Navigator.pop(context); // Dismiss loading

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permanently deleted ${itemsToDelete.length} item(s)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting items: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _clearSelection();
    _loadItems();
  }

  Future<void> _emptyRecycleBin() async {
    if (_allItems.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Empty Recycle Bin?'),
        content: const Text('Are you sure you want to permanently delete all items in the Recycle Bin? This action is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty Bin'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await RecycleBinService.emptyBin();
      if (mounted) Navigator.pop(context); // Dismiss loading
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recycle Bin emptied successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error emptying bin: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _clearSelection();
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search deleted files...',
                      border: InputBorder.none,
                    ),
                    style: theme.textTheme.titleMedium,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _filterItems();
                      });
                    },
                  )
                : const Text('Recycle Bin'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearSelection,
              )
            : IconButton(
                icon: const Icon(Broken.arrow_left),
                onPressed: () => Navigator.pop(context),
              ),
        actions: [
          if (!_isSelectionMode) ...[
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = "";
                    _searchController.clear();
                    _filterItems();
                  });
                },
              )
            else
              IconButton(
                icon: const Icon(Broken.search_normal),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            IconButton(
              icon: const Icon(Broken.trash, color: Colors.redAccent),
              onPressed: _allItems.isEmpty ? null : _emptyRecycleBin,
              tooltip: 'Empty Recycle Bin',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: _allItems.isEmpty
            ? _buildEmptyState(theme)
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = _selectedIds.contains(item.id);

                        final icon = item.isDirectory
                            ? FileUtils.getFolderIcon('default')
                            : FileUtils.getIconForFile(item.name);
                        final iconColor = item.isDirectory
                            ? theme.colorScheme.primary
                            : FileUtils.getColorForFile(item.name, context);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: isSelected
                              ? theme.colorScheme.primaryContainer.withOpacity(0.4)
                              : theme.colorScheme.surface,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.dividerColor.withOpacity(0.08),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(item.id);
                              } else {
                                _showItemDetails(item);
                              }
                            },
                            onLongPress: () => _toggleSelection(item.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Leading Icon
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: isSelected
                                        ? Icon(Broken.tick_circle,
                                            color: theme.colorScheme.onPrimary, size: 24)
                                        : Icon(icon, color: iconColor, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  // Metadata details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Original Path: ${item.originalPath}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Deleted: ${FileUtils.formatDate(item.deletedAt)} • ${FileUtils.formatBytes(item.size, 1)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Trailing popup menu for quick actions
                                  if (!_isSelectionMode)
                                    PopupMenuButton<String>(
                                      icon: const Icon(Broken.more, size: 20),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16)),
                                      position: PopupMenuPosition.under,
                                      onSelected: (action) async {
                                        if (action == 'restore') {
                                          _selectedIds.clear();
                                          _selectedIds.add(item.id);
                                          await _restoreSelected();
                                        } else if (action == 'delete') {
                                          _selectedIds.clear();
                                          _selectedIds.add(item.id);
                                          await _deleteSelectedPermanently();
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(
                                          value: 'restore',
                                          child: Row(
                                            children: [
                                              Icon(Icons.restore_rounded, size: 20),
                                              SizedBox(width: 12),
                                              Text('Restore',
                                                  style: TextStyle(fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Broken.trash,
                                                  size: 20, color: Colors.redAccent),
                                              SizedBox(width: 12),
                                              Text('Delete Permanently',
                                                  style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight: FontWeight.w500)),
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
                  ),
                  // Multi-Selection Bottom Action Bar
                  if (_isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: theme.dividerColor.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _restoreSelected,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restore'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _deleteSelectedPermanently,
                              icon: const Icon(Broken.trash),
                              label: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Broken.trash,
                size: 84,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recycle Bin is Empty',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Items you delete when Recycle Bin is enabled will appear here. You can restore them or permanently delete them.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDetails(RecycleBinItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _buildDetailRow('Original Location', item.originalPath),
              _buildDetailRow('Recycled Date', FileUtils.formatDate(item.deletedAt)),
              _buildDetailRow('File Size', FileUtils.formatBytes(item.size, 2)),
              _buildDetailRow('Type', item.isDirectory ? 'Directory' : 'File'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        _selectedIds.clear();
                        _selectedIds.add(item.id);
                        await _restoreSelected();
                      },
                      child: const Text('Restore'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        _selectedIds.clear();
                        _selectedIds.add(item.id);
                        await _deleteSelectedPermanently();
                      },
                      child: const Text('Delete Permanently'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
