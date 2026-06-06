import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/icon_fonts/broken_icons.dart';
import '../../../models/app_info_model.dart';
import '../../../services/app_manager_service.dart';
import '../../../core/utils.dart';
import 'widgets/app_list_tab.dart';
import 'widgets/backup_list_tab.dart';
import 'widgets/app_options_sheet.dart';
import 'widgets/app_batch_action_bar.dart';

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

  // Global backup list key to force refresh BackupListTab when a backup is created
  Key _backupTabKey = UniqueKey();

  // Static cache for app icons to prevent flickering on rebuild/scroll
  static final Map<String, Uint8List> _iconCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _clearSelection();
        });
      }
    });
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

  void _showAppOptionsBottomSheet(AppInfoModel app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AppOptionsSheet(
          app: app,
          iconCache: _iconCache,
          onRefreshNeeded: () {
            _loadApplications();
            setState(() {
              _backupTabKey = UniqueKey(); // Force refresh BackupListTab
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                '${_selectedPackages.length}/${processedApps.length}',
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
              onPressed: () {
                _loadApplications();
                setState(() {
                  _backupTabKey = UniqueKey();
                });
              },
              tooltip: 'Refresh List',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          tabs: const [
            Tab(text: 'Installed User Apps'),
            Tab(text: 'System Packages'),
            Tab(text: 'Backed Up APKs'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (!_hasUsageStatsPermission && !_isSelectionMode && _tabController.index != 2)
            _buildPermissionBanner(theme),
          // Search & Sort bar (visible if not selecting)
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
                                hintText: _tabController.index == 2
                                    ? 'Search backups...'
                                    : 'Search packages or names...',
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
                        child: Text(_tabController.index == 2 ? 'Sort by Backup Date' : 'Sort by Install Date'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Apps List Tab Content
          Expanded(
            child: _isLoading && _tabController.index != 2
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(), // Managed via tab controller listener
                    children: [
                      AppListTab(
                        apps: processedApps,
                        selectedPackages: _selectedPackages,
                        onToggleSelection: _toggleSelection,
                        onShowOptions: _showAppOptionsBottomSheet,
                        iconCache: _iconCache,
                      ),
                      AppListTab(
                        apps: processedApps,
                        selectedPackages: _selectedPackages,
                        onToggleSelection: _toggleSelection,
                        onShowOptions: _showAppOptionsBottomSheet,
                        iconCache: _iconCache,
                      ),
                      BackupListTab(
                        key: _backupTabKey,
                        searchQuery: _searchQuery,
                        sortBy: _sortBy,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode
          ? AppBatchActionBar(
              allApps: activeApps,
              selectedPackages: _selectedPackages,
              onClearSelection: _clearSelection,
              onRefreshNeeded: () {
                _loadApplications();
                setState(() {
                  _backupTabKey = UniqueKey();
                });
              },
              canUninstall: _tabController.index == 0,
            )
          : null,
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
