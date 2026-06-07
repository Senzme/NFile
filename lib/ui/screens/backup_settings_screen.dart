import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../services/settings_backup_service.dart';
import 'internal_file_picker_screen.dart';

class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        leading: IconButton(
          icon: const Icon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            _BackupSettingsTile(
              icon: Broken.document_upload,
              title: 'Backup Settings',
              subtitle: 'Save all your current settings to NFile/Backups/Settings/',
              onTap: () => SettingsBackupService.backupSettings(context),
            ),
            const SizedBox(height: 8),
            _BackupSettingsTile(
              icon: Broken.document_download,
              title: 'Restore Settings',
              subtitle: 'Select and restore settings from a JSON backup file',
              onTap: () async {
                final pickedPaths = await InternalFilePickerScreen.show(
                  context,
                  rootPath: '/storage/emulated/0',
                  pickDirectory: false,
                );

                if (pickedPaths != null && pickedPaths.isNotEmpty) {
                  final selectedPath = pickedPaths.first;
                  if (selectedPath.toLowerCase().endsWith('.json')) {
                    if (context.mounted) {
                      await SettingsBackupService.restoreSettings(context, selectedPath);
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please select a valid .json settings backup file'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: theme.colorScheme.error,
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BackupSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
          size: 22,
        ),
        onTap: onTap,
      ),
    );
  }
}
