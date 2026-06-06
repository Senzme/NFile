import 'package:flutter/material.dart';
import '../../../../core/icon_fonts/broken_icons.dart';
import '../../../../models/app_info_model.dart';
import '../../../../services/app_manager_service.dart';

class AppBatchActionBar extends StatelessWidget {
  final List<AppInfoModel> allApps;
  final Set<String> selectedPackages;
  final VoidCallback onClearSelection;
  final VoidCallback onRefreshNeeded;
  final bool canUninstall; // False for system apps tab

  const AppBatchActionBar({
    super.key,
    required this.allApps,
    required this.selectedPackages,
    required this.onClearSelection,
    required this.onRefreshNeeded,
    required this.canUninstall,
  });

  List<AppInfoModel> get _selectedApps {
    return allApps.where((app) => selectedPackages.contains(app.packageName)).toList();
  }

  Future<void> _handleBatchUninstall(BuildContext context) async {
    if (selectedPackages.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Uninstall Apps', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to uninstall ${selectedPackages.length} selected app(s)?'),
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
      final List<String> toUninstall = selectedPackages.toList();
      onClearSelection();

      for (final package in toUninstall) {
        await AppManagerService.uninstallApp(package);
      }
      
      Future.delayed(const Duration(seconds: 2), onRefreshNeeded);
    }
  }

  Future<void> _handleBatchBackup(BuildContext context) async {
    if (selectedPackages.isEmpty) return;
    
    final appsToBackup = _selectedApps;
    onClearSelection();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Backing up selected applications...")),
          ],
        ),
      ),
    );

    try {
      await AppManagerService.batchBackupApps(appsToBackup, (current, total) {});
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully backed up ${appsToBackup.length} app(s) to NFile/Backups/Apps/')),
        );
        onRefreshNeeded();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to back up some apps: $e')),
        );
      }
    }
  }

  void _handleBatchShare() {
    if (selectedPackages.isEmpty) return;
    final appsToShare = _selectedApps;
    onClearSelection();
    AppManagerService.batchShareAppApks(appsToShare);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onClearSelection,
              child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  // Batch Backup
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Broken.document_download, size: 18),
                      label: const Text('Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.withOpacity(0.15),
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => _handleBatchBackup(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Batch Share
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Broken.export_1, size: 18),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.withOpacity(0.15),
                        foregroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: _handleBatchShare,
                    ),
                  ),
                  if (canUninstall) ...[
                    const SizedBox(width: 8),
                    // Batch Uninstall
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Broken.trash, size: 18),
                        label: const Text('Uninstall', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.15),
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () => _handleBatchUninstall(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
