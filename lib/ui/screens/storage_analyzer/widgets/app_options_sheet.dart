import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/icon_fonts/broken_icons.dart';
import '../../../../models/app_info_model.dart';
import '../../../../services/app_manager_service.dart';
import '../../../../core/utils.dart';

class AppOptionsSheet extends StatelessWidget {
  final AppInfoModel app;
  final Map<String, Uint8List> iconCache;
  final VoidCallback onRefreshNeeded;

  const AppOptionsSheet({
    super.key,
    required this.app,
    required this.iconCache,
    required this.onRefreshNeeded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      iconCache: iconCache,
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
            _buildBottomSheetActionItem(
              theme: theme,
              icon: Broken.document_download,
              label: 'Back Up APK',
              color: Colors.orangeAccent,
              onTap: () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backing up APK...')),
                );
                final success = await AppManagerService.backupApp(app);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'APK backed up successfully to NFile/Backups/Apps/'
                            : 'Failed to back up APK',
                      ),
                    ),
                  );
                  onRefreshNeeded();
                }
              },
            ),
            _buildBottomSheetActionItem(
              theme: theme,
              icon: Broken.export_1,
              label: 'Share APK File',
              color: Colors.teal,
              onTap: () {
                Navigator.pop(context);
                AppManagerService.shareAppApk(app);
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
                    Future.delayed(const Duration(seconds: 2), onRefreshNeeded);
                  });
                },
              ),
          ],
        ),
      ),
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
