import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/icon_fonts/broken_icons.dart';
import '../../../../models/app_info_model.dart';
import '../../../../services/app_manager_service.dart';
import '../../../../services/apk_installer_service.dart';
import '../../../../core/utils.dart';

class BackupListTab extends StatefulWidget {
  final String searchQuery;
  final String sortBy;

  const BackupListTab({
    key,
    required this.searchQuery,
    required this.sortBy,
  }) : super(key: key);

  @override
  State<BackupListTab> createState() => _BackupListTabState();
}

class _BackupListTabState extends State<BackupListTab> {
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = true;
  final Map<String, Uint8List> _apkIconCache = {};

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  @override
  void didUpdateWidget(covariant BackupListTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery || oldWidget.sortBy != widget.sortBy) {
      _loadBackups();
    }
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
    });

    final list = await AppManagerService.listBackups();

    // Filter by query
    List<Map<String, dynamic>> filtered = list;
    if (widget.searchQuery.isNotEmpty) {
      final q = widget.searchQuery.toLowerCase();
      filtered = list.where((item) {
        final name = (item['name'] as String).toLowerCase();
        final package = (item['packageName'] as String).toLowerCase();
        return name.contains(q) || package.contains(q);
      }).toList();
    }

    // Sort
    if (widget.sortBy == 'name') {
      filtered.sort((a, b) => (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));
    } else if (widget.sortBy == 'size') {
      filtered.sort((a, b) => (b['apkSize'] as int).compareTo(a['apkSize'] as int));
    } else if (widget.sortBy == 'date') {
      filtered.sort((a, b) => (b['installTime'] as DateTime).compareTo(a['installTime'] as DateTime));
    }

    setState(() {
      _backups = filtered;
      _isLoading = false;
    });
  }

  void _showBackupOptionsSheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isApks = item['isApks'] as bool;
        final apkPath = item['path'] as String;

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
                        child: _ApkIconWidget(
                          apkPath: apkPath,
                          iconCache: _apkIconCache,
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
                            item['name'] as String,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${isApks ? "Split Bundle" : "Single APK"} • v${item['version']}',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${FileUtils.formatBytes(item['apkSize'] as int, 2)} • Backup Date: ${FileUtils.formatDate(item['installTime'] as DateTime, use24Hour: true).split('  ').first}',
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
                  icon: Broken.document_upload,
                  label: 'Restore / Install App',
                  color: theme.colorScheme.primary,
                  onTap: () async {
                    Navigator.pop(context);
                    await ApkInstallerService.installApk(context, apkPath);
                  },
                ),
                _buildBottomSheetActionItem(
                  theme: theme,
                  icon: Broken.export_1,
                  label: 'Share Backup File',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    AppManagerService.shareAppApk(
                      AppInfoModel(
                        name: item['name'],
                        packageName: item['packageName'],
                        version: item['version'],
                        apkSize: item['apkSize'],
                        isSystem: false,
                        installTime: item['installTime'],
                        sourceDir: apkPath,
                        splitSourceDirs: const [],
                      ),
                    );
                  },
                ),
                _buildBottomSheetActionItem(
                  theme: theme,
                  icon: Broken.trash,
                  label: 'Delete Backup File',
                  color: Colors.redAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final success = await AppManagerService.deleteBackup(apkPath);
                    if (success) {
                      _loadBackups();
                    }
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_backups.isEmpty) {
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
                  Broken.document_download,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No backups found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                widget.searchQuery.isNotEmpty
                    ? 'We couldn\'t find any backups matching "${widget.searchQuery}"'
                    : 'A list of your backed up APK and APKS files will show here.',
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

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _backups.length,
      itemBuilder: (context, index) {
        final item = _backups[index];
        final isApks = item['isApks'] as bool;
        final apkPath = item['path'] as String;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.06),
              width: 1.0,
            ),
          ),
          child: InkWell(
            onTap: () => _showBackupOptionsSheet(item),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Apk Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _ApkIconWidget(
                        apkPath: apkPath,
                        iconCache: _apkIconCache,
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
                          item['name'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${isApks ? "Split Bundle (APKS)" : "Single APK"} • v${item['version']}',
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
                  Text(
                    FileUtils.formatBytes(item['apkSize'] as int, 1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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

class _ApkIconWidget extends StatelessWidget {
  final String apkPath;
  final Map<String, Uint8List> iconCache;
  final double size;

  const _ApkIconWidget({
    required this.apkPath,
    required this.iconCache,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (iconCache.containsKey(apkPath)) {
      return Image.memory(
        iconCache[apkPath]!,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: AppManagerService.getApkIcon(apkPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          iconCache[apkPath] = snapshot.data!;
          return Image.memory(
            snapshot.data!,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        }
        return Icon(Broken.box, size: size * 0.8, color: Theme.of(context).colorScheme.primary.withOpacity(0.5));
      },
    );
  }
}
