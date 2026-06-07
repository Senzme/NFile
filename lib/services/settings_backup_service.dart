import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';
import '../providers/media_provider.dart';

class SettingsBackupService {
  static const String _backupDir = '/storage/emulated/0/NFile/Backups/Settings';
  static const String _defaultBackupFileName = 'nfile_settings_backup.json';

  static Future<void> backupSettings(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, dynamic> backupData = {};

      for (final key in keys) {
        final val = prefs.get(key);
        if (val != null) {
          backupData[key] = val;
        }
      }

      // Create backup directory if it doesn't exist
      final directory = Directory(_backupDir);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      final jsonStr = const JsonEncoder.withIndent('  ').convert(backupData);

      // Write to default backup file
      final defaultFile = File('$_backupDir/$_defaultBackupFileName');
      await defaultFile.writeAsString(jsonStr);

      // Write to timestamped backup file
      final now = DateTime.now();
      final timestamp = '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}_${_twoDigits(now.hour)}${_twoDigits(now.minute)}${_twoDigits(now.second)}';
      final timestampedFile = File('$_backupDir/nfile_settings_backup_$timestamp.json');
      await timestampedFile.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings backed up to NFile/Backups/Settings/nfile_settings_backup.json'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to backup settings: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  static String _twoDigits(int n) {
    if (n >= 10) return '$n';
    return '0$n';
  }

  static Future<void> restoreSettings(BuildContext context, String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('Backup file does not exist');
      }

      final jsonStr = await file.readAsString();
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid backup file format');
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Clear existing preferences first
      await prefs.clear();

      // Write restored keys
      for (final entry in decoded.entries) {
        final key = entry.key;
        final val = entry.value;

        if (val is bool) {
          await prefs.setBool(key, val);
        } else if (val is int) {
          await prefs.setInt(key, val);
        } else if (val is double) {
          await prefs.setDouble(key, val);
        } else if (val is String) {
          await prefs.setString(key, val);
        } else if (val is List) {
          await prefs.setStringList(key, List<String>.from(val));
        }
      }

      // Reload preferences in providers to update the active UI instantly
      if (context.mounted) {
        Provider.of<FileManagerProvider>(context, listen: false).reloadPreferences();
        Provider.of<MediaProvider>(context, listen: false).reloadPreferences();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings restored successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restore settings: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
