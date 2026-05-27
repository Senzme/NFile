import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/icon_fonts/broken_icons.dart';
import '../../../models/app_info_model.dart';
import '../../../services/app_manager_service.dart';
import '../../../core/utils.dart';

class AppManagerScreen extends StatefulWidget {
  const AppManagerScreen({super.key});

  @override
  State<AppManagerScreen> createState() => _AppManagerScreenState();
}

class _AppManagerScreenState extends State<AppManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'size'; // 'name', 'size', 'date'
  bool _hasUsageStatsPermission = true;
  
  List<AppInfoModel> _userApps = [];
  List<AppInfoModel> _systemApps = [];

  final Set<String> _selectedPackages = {};
  bool get _isSelectionMode => _selectedPackages.isNotEmpty;

  // Static cache for app icons to prevent flickering on rebuild/scroll
  static final Map<String, Uint8List> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadApplications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final hasPermission = await AppManagerService.checkUsageStatsPermission();
      final user = await AppManagerService.getInstalledApps(includeSystem: false);
      final all = await AppManagerService.getInstalledApps(includeSystem: true);
      
      final sys = all.where((app) => app.isSystem).toList();

      setState(() {
        _hasUsageStatsPermission = hasPermission;
        _userApps = user;
        _systemApps = sys;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSelection(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPackages.clear();
    });
  }

  void _selectAll(List<AppInfoModel> activeList) {
    setState(() {
      for (final app in activeList) {
        _selectedPackages.add(app.packageName);
      }
    });
  }

  List<AppInfoModel> _filterAndSortApps(List<AppInfoModel> sourceList) {
    // 1. Filter by search query
    List<AppInfoModel> filtered = sourceList.where((app) {
      final q = _searchQuery.toLowerCase();
      return app.name.toLowerCase().contains(q) || app.packageName.toLowerCase().contains(q);
    }).toList();

    // 2. Sort list
    if (_sortBy == 'name') {
      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_sortBy == 'size') {
      filtered.sort((a, b) => b.apkSize.compareTo(a.apkSize));
    } else if (_sortBy == 'date') {
      filtered.sort((a, b) => b.installTime.compareTo(a.installTime));
    }

    return filtered;
  }

  Future<void> _handleBatchUninstall(List<AppInfoModel> activeList) async {
    if (_selectedPackages.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Uninstall Apps', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to uninstall ${_selectedPackages.length} selected app(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Uninstall', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final List<String> toUninstall = _selectedPackages.toList();
      _clearSelection();

      // Trigger uninstalls one after another
      for (final package in toUninstall) {
        await AppManagerService.uninstallApp(package);
      }
      
      // Delay briefly to allow uninstallation processes and then refresh list
      Future.delayed(const Duration(seconds: 2), _loadApplications);
    }
  }

  void _showAppOptionsBottomSheet(AppInfoModel app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _AppIconWidget(
                          packageName: app.packageName,
                          iconCache: _iconCache,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${app.packageName} • v${app.version}',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${FileUtils.formatBytes(app.apkSize, 2)} • Installed: ${FileUtils.formatDate(app.installTime, use24Hour: true).split('  ').first}',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: theme.dividerColor.withOpacity(0.1)),
                const SizedBox(height: 12),
                
                // Actions List
                _buildBottomSheetActionItem(
                  theme: theme,
                  icon: Broken.play,
                  label: 'Launch Application',
                  color: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.pop(context);
                    AppManagerService.launchApp(app.packageName);
                  },
                ),
                _buildBottomSheetActionItem(
                  theme: theme,
                  icon: Broken.setting_4,
                  label: 'System Settings / Details',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.pop(context);
                    AppManagerService.openAppDetails(app.packageName);
                  },
                ),
                if (!app.isSystem)
                  _buildBottomSheetActionItem(
                    theme: theme,
                    icon: Broken.trash,
                    label: 'Uninstall Application',
                    color: Colors.redAccent,
                    onTap: () {
                      Navigator.pop(context);
                      AppManagerService.uninstallApp(app.packageName).then((_) {
                        Future.delayed(const Duration(seconds: 2), _loadApplications);
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetActionItem({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      trailing: const Icon(Broken.arrow_right_3, size: 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeApps = _tabController.index == 0 ? _userApps : _systemApps;
    final processedApps = _filterAndSortApps(activeApps);

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
                '${_selectedPackages.length} Selected',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              )
            : Text(
                'App Manager',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Broken.task_square),
              onPressed: () => _selectAll(processedApps),
              tooltip: 'Select All',
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadApplications,
              tooltip: 'Refresh List',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          tabs: const [
            Tab(text: 'Installed User Apps'),
            Tab(text: 'System Packages'),
          ],
          onTap: (_) {
            setState(() {
              _clearSelection();
            });
          },
        ),
      ),
      body: Column(
        children: [
          if (!_hasUsageStatsPermission && !_isSelectionMode)
            _buildPermissionBanner(theme),
          // Search & Sort bar
          if (!_isSelectionMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Broken.search_normal, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                });
                              },
                              style: const TextStyle(fontSize: 14.5),
                              decoration: InputDecoration(
                                hintText: 'Search packages or names...',
                                hintStyle: TextStyle(
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Sort Trigger Icon
                  PopupMenuButton<String>(
                    icon: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
                      ),
                      child: const Icon(Icons.sort_rounded, size: 22),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _sortBy = val;
                      });
                    },
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: 'size',
                        checked: _sortBy == 'size',
                        child: const Text('Sort by Size'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'name',
                        checked: _sortBy == 'name',
                        child: const Text('Sort Alphabetically'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'date',
                        checked: _sortBy == 'date',
                        child: const Text('Sort by Install Date'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Total App Counter Summary
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${processedApps.length} packages found',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_sortBy == 'size')
                    Text(
                      'Sorted by size',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (_sortBy == 'name')
                    Text(
                      'Sorted alphabetically',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      'Sorted by date',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

          // Apps List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : processedApps.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: processedApps.length,
                        itemBuilder: (context, index) {
                          final app = processedApps[index];
                          final isSelected = _selectedPackages.contains(app.packageName);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer.withOpacity(0.35)
                                  : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor.withOpacity(0.06),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleSelection(app.packageName);
                                } else {
                                  _showAppOptionsBottomSheet(app);
                                }
                              },
                              onLongPress: () {
                                _toggleSelection(app.packageName);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // Lazy App Icon Widget
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: _AppIconWidget(
                                          packageName: app.packageName,
                                          iconCache: _iconCache,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            app.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${app.packageName} • v${app.version}',
                                            style: TextStyle(
                                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.55),
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          FileUtils.formatBytes(app.apkSize, 1),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(height: 4),
                                          Icon(
                                            Broken.tick_square,
                                            color: theme.colorScheme.primary,
                                            size: 18,
                                          ),
                                        ],
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
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar(theme, processedApps) : null,
    );
  }

  Widget _buildBottomActionBar(ThemeData theme, List<AppInfoModel> activeList) {
    // Only show uninstallation options if we are in User Apps tab
    // Since Android does not let users uninstall system apps without ROOT/ADB
    final canUninstall = _tabController.index == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _clearSelection,
              child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: canUninstall ? Colors.red : theme.colorScheme.primary.withOpacity(0.2),
                  foregroundColor: canUninstall ? Colors.white : theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: canUninstall ? () => _handleBatchUninstall(activeList) : null,
                child: Text(
                  canUninstall ? 'Uninstall Selected (${_selectedPackages.length})' : 'System App (Can\'t Uninstall)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Broken.mobile,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No applications found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'We couldn\'t find any packages matching "$_searchQuery"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Broken.info_circle, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Exact Storage Calculation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'To see exact app storage sizes (APK + data + cache) instead of just the raw installer size, please enable the Usage Access permission for NFile in System Settings.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
              ),
              onPressed: () async {
                await AppManagerService.requestUsageStatsPermission();
                // When coming back, wait briefly and check permission & reload
                Future.delayed(const Duration(seconds: 1), () {
                  _loadApplications();
                });
              },
              child: const Text(
                'Grant Usage Access Permission',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppIconWidget extends StatelessWidget {
  final String packageName;
  final Map<String, Uint8List> iconCache;
  final double size;

  const _AppIconWidget({
    required this.packageName,
    required this.iconCache,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (iconCache.containsKey(packageName)) {
      return Image.memory(
        iconCache[packageName]!,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: AppManagerService.getAppIcon(packageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          iconCache[packageName] = snapshot.data!;
          return Image.memory(
            snapshot.data!,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
        return Icon(Broken.mobile, size: size * 0.8, color: Theme.of(context).colorScheme.primary.withOpacity(0.5));
      },
    );
  }
}

