import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'archive_service.dart';

class FolderShareService {
  /// Compresses folders into temporary ZIP archives and shares files + compressed folders natively.
  static Future<void> sharePaths(BuildContext context, List<String> paths) async {
    if (paths.isEmpty) return;

    // Show a loading dialog since compression can take a while
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Preparing folders for sharing...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Compressing contents, please wait',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final filesToShare = <XFile>[];
    final tempZipFiles = <File>[];

    try {
      final tempDir = Directory.systemTemp;

      for (final path in paths) {
        final type = FileSystemEntity.typeSync(path);
        if (type == FileSystemEntityType.file) {
          filesToShare.add(XFile(path));
        } else if (type == FileSystemEntityType.directory) {
          final folderName = p.basename(path);
          final tempZipName = '${folderName}_${DateTime.now().millisecondsSinceEpoch}';
          
          // Compress the folder using high-performance ArchiveService
          await ArchiveService.createArchive(
            sourcePaths: [path],
            destinationDir: tempDir.path,
            archiveName: tempZipName,
            format: 'zip',
            compressionLevel: 3, // Fast compression for quick sharing
            deleteSource: false,
            separateArchives: false,
          );

          final zipFile = File(p.join(tempDir.path, '$tempZipName.zip'));
          if (zipFile.existsSync()) {
            tempZipFiles.add(zipFile);
            filesToShare.add(XFile(zipFile.path));
          }
        }
      }

      // Close the loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (filesToShare.isNotEmpty) {
        await Share.shareXFiles(filesToShare);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No shareable items found.')),
          );
        }
      }
    } catch (e) {
      // Close the loading dialog if it's still showing
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error preparing files to share: $e')),
        );
      }
    } finally {
      // Delete temporary zip files after a delay to let the share sheet access them
      Future.delayed(const Duration(seconds: 15), () {
        for (final file in tempZipFiles) {
          try {
            if (file.existsSync()) {
              file.deleteSync();
            }
          } catch (_) {}
        }
      });
    }
  }
}
