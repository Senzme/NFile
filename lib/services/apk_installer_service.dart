import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'archive_service.dart';

class ApkInstallerService {
  static const List<String> apkExtensions = ['.apk', '.xapk', '.apks', '.apkm', '.aab'];

  static bool isApk(String path) {
    final ext = p.extension(path).toLowerCase();
    return apkExtensions.contains(ext);
  }

  static Future<void> installApk(BuildContext context, String path) async {
    final ext = p.extension(path).toLowerCase();

    if (ext == '.apk') {
      await OpenFilex.open(path);
      return;
    }

    // For .xapk, .apks, .apkm, .aab bundles
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Extracting package bundle for installation...")),
          ],
        ),
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final bundleDirName = p.basenameWithoutExtension(path).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final extractDir = Directory(p.join(tempDir.path, 'apk_bundles', bundleDirName));

      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create(recursive: true);

      // Extract the bundle
      await ArchiveService.extractArchive(
        archivePath: path,
        destinationDir: extractDir.path,
      );

      if (!context.mounted) return;

      // Locate base.apk or the largest APK file
      File? baseApk;
      List<File> allApks = [];

      await for (final entity in extractDir.list(recursive: true)) {
        if (entity is File && p.extension(entity.path).toLowerCase() == '.apk') {
          allApks.add(entity);
          final name = p.basename(entity.path).toLowerCase();
          if (name == 'base.apk' || name.contains('main')) {
            baseApk = entity;
          }
        } else if (entity is File && p.extension(entity.path).toLowerCase() == '.obb') {
          // Copy OBB file to Android/obb/ directory if possible
          try {
            final obbFileName = p.basename(entity.path);
            final parentDir = p.basename(p.dirname(entity.path));
            final targetObbDir = Directory('/storage/emulated/0/Android/obb/$parentDir');
            if (!await targetObbDir.exists()) {
              await targetObbDir.create(recursive: true);
            }
            await entity.copy('${targetObbDir.path}/$obbFileName');
          } catch (_) {}
        }
      }

      if (baseApk == null && allApks.isNotEmpty) {
        allApks.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
        baseApk = allApks.first;
      }

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (baseApk != null && await baseApk.exists()) {
        await OpenFilex.open(baseApk.path);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No installable APK found in package bundle')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to extract package bundle: $e')),
      );
    }
  }
}
