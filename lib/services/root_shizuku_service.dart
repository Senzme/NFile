import 'dart:io';
import 'package:flutter/services.dart';
import '../models/file_item_model.dart';
import 'package:path/path.dart' as p;

class RootShizukuStatus {
  final bool isRootAvailable;
  final bool isShizukuAvailable;
  final bool shizukuPermissionGranted;

  RootShizukuStatus({
    required this.isRootAvailable,
    required this.isShizukuAvailable,
    required this.shizukuPermissionGranted,
  });

  factory RootShizukuStatus.fromMap(Map<dynamic, dynamic> map) {
    return RootShizukuStatus(
      isRootAvailable: map['isRootAvailable'] == true,
      isShizukuAvailable: map['isShizukuAvailable'] == true,
      shizukuPermissionGranted: map['shizukuPermissionGranted'] == true,
    );
  }
}

class RootShizukuService {
  static const MethodChannel _channel = MethodChannel('com.rubex.nfile/root_shizuku');

  static Future<RootShizukuStatus> checkStatus() async {
    if (!Platform.isAndroid) {
      return RootShizukuStatus(isRootAvailable: false, isShizukuAvailable: false, shizukuPermissionGranted: false);
    }
    try {
      final res = await _channel.invokeMethod('checkStatus');
      if (res is Map) {
        return RootShizukuStatus.fromMap(res);
      }
    } catch (_) {}
    return RootShizukuStatus(isRootAvailable: false, isShizukuAvailable: false, shizukuPermissionGranted: false);
  }

  static Future<bool> requestShizukuPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('requestShizukuPermission');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> runCommand(String command, {required bool useRoot}) async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod('runCommand', {
        'command': command,
        'useRoot': useRoot,
      });
      return res?.toString();
    } catch (e) {
      throw Exception('Execution failed: $e');
    }
  }

  static Future<List<FileItemModel>> listFiles(String path, {required bool useRoot, bool showHiddenFiles = false}) async {
    final cleanPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    
    final cmd = 'for f in "$cleanPath"/* "$cleanPath"/.*; do [ -e "\$f" ] && [ "\${f##*/}" != "." ] && [ "\${f##*/}" != ".." ] && stat -c "%F|%s|%Y|%n" "\$f"; done';
    
    final output = await runCommand(cmd, useRoot: useRoot);
    if (output == null || output.trim().isEmpty) return [];

    final lines = output.split('\n');
    final items = <FileItemModel>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('|');
      if (parts.length < 4) continue;

      final typeStr = parts[0];
      final sizeStr = parts[1];
      final timeStr = parts[2];
      final fullPath = parts.sublist(3).join('|');

      final name = p.basename(fullPath);
      if (!showHiddenFiles && name.startsWith('.') && name != '.' && name != '..') {
        continue;
      }

      final isDir = typeStr.toLowerCase().contains('directory');
      final size = int.tryParse(sizeStr) ?? 0;
      final seconds = int.tryParse(timeStr) ?? 0;
      final modified = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

      items.add(FileItemModel.fromCustom(
        path: fullPath,
        isDirectory: isDir,
        size: size,
        modified: modified,
      ));
    }

    return items;
  }

  static Future<void> deleteItem(String path, {required bool useRoot}) async {
    final cmd = 'rm -rf "$path"';
    await runCommand(cmd, useRoot: useRoot);
  }

  static Future<void> renameItem(String oldPath, String newName, {required bool useRoot}) async {
    final newPath = p.join(p.dirname(oldPath), newName);
    final cmd = 'mv "$oldPath" "$newPath"';
    await runCommand(cmd, useRoot: useRoot);
  }

  static Future<void> createFolder(String parentPath, String name, {required bool useRoot}) async {
    final newPath = p.join(parentPath, name);
    final cmd = 'mkdir -p "$newPath"';
    await runCommand(cmd, useRoot: useRoot);
  }

  static Future<void> createFile(String parentPath, String name, {required bool useRoot}) async {
    final newPath = p.join(parentPath, name);
    final cmd = 'touch "$newPath"';
    await runCommand(cmd, useRoot: useRoot);
  }

  static Future<void> copyItem(String srcPath, String destPath, {required bool useRoot}) async {
    final cmd = 'cp -r "$srcPath" "$destPath"';
    await runCommand(cmd, useRoot: useRoot);
  }

  static Future<void> moveItem(String srcPath, String destPath, {required bool useRoot}) async {
    final cmd = 'mv "$srcPath" "$destPath"';
    await runCommand(cmd, useRoot: useRoot);
  }
}
