import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

class ArchiveService {
  /// Creates an archive or multiple separate archives.
  static Future<void> createArchive({
    required List<String> sourcePaths,
    required String destinationDir,
    required String archiveName,
    required String format, // 'zip', 'tar', 'tar.gz', 'tar.bz2'
    required int compressionLevel, // 0 (None), 3 (Fast), 6 (Standard), 9 (Maximum)
    String? password,
    int? splitSizeMB,
    required bool deleteSource,
    required bool separateArchives,
  }) async {
    if (separateArchives) {
      for (final path in sourcePaths) {
        final name = p.basenameWithoutExtension(path);
        final fullDest = p.join(destinationDir, '$name.$format');
        await _createSingleArchive([path], fullDest, format, compressionLevel, password, splitSizeMB);
        if (deleteSource) {
          await _deleteEntity(path);
        }
      }
    } else {
      final fullDest = p.join(destinationDir, '$archiveName.$format');
      await _createSingleArchive(sourcePaths, fullDest, format, compressionLevel, password, splitSizeMB);
      if (deleteSource) {
        for (final path in sourcePaths) {
          await _deleteEntity(path);
        }
      }
    }
  }

  static Future<void> _createSingleArchive(
    List<String> sourcePaths,
    String destinationPath,
    String format,
    int level,
    String? password,
    int? splitSizeMB,
  ) async {
    return compute(_encodeArchiveTask, {
      'sourcePaths': sourcePaths,
      'destinationPath': destinationPath,
      'format': format,
      'level': level,
      'password': password,
      'splitSizeMB': splitSizeMB,
    });
  }

  static void _encodeArchiveTask(Map<String, dynamic> args) {
    final sourcePaths = args['sourcePaths'] as List<String>;
    final destinationPath = args['destinationPath'] as String;
    final format = args['format'] as String;
    final level = args['level'] as int;
    final password = args['password'] as String?;
    final splitSizeMB = args['splitSizeMB'] as int?;

    final archive = Archive();

    for (final path in sourcePaths) {
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.file) {
        final file = File(path);
        final bytes = file.readAsBytesSync();
        final name = p.basename(path);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      } else if (entity == FileSystemEntityType.directory) {
        final dir = Directory(path);
        final list = dir.listSync(recursive: true);
        for (final sub in list) {
          if (sub is File) {
            final relPath = p.relative(sub.path, from: p.dirname(path));
            final bytes = sub.readAsBytesSync();
            archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
          }
        }
      }
    }

    List<int>? encodedBytes;

    if (format == 'zip') {
      encodedBytes = ZipEncoder().encode(archive, level: level);
    } else if (format == 'tar') {
      encodedBytes = TarEncoder().encode(archive);
    } else if (format == 'tar.gz') {
      final tarBytes = TarEncoder().encode(archive);
      if (tarBytes != null) {
        encodedBytes = GZipEncoder().encode(tarBytes);
      }
    } else if (format == 'tar.bz2') {
      final tarBytes = TarEncoder().encode(archive);
      if (tarBytes != null) {
        encodedBytes = BZip2Encoder().encode(tarBytes);
      }
    }

    if (encodedBytes != null) {
      final outFile = File(destinationPath);
      outFile.writeAsBytesSync(encodedBytes);

      // Handle Volume Splitting
      if (splitSizeMB != null && splitSizeMB > 0) {
        final chunkSize = splitSizeMB * 1024 * 1024;
        if (encodedBytes.length > chunkSize) {
          int partNum = 1;
          for (int i = 0; i < encodedBytes.length; i += chunkSize) {
            int end = (i + chunkSize > encodedBytes.length) ? encodedBytes.length : i + chunkSize;
            final chunk = encodedBytes.sublist(i, end);
            final partExt = partNum.toString().padLeft(3, '0');
            final partFile = File('$destinationPath.$partExt');
            partFile.writeAsBytesSync(chunk);
            partNum++;
          }
          outFile.deleteSync();
        }
      }
    }
  }

  /// Extracts an archive to the specified destination directory.
  static Future<void> extractArchive({
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    return compute(_decodeArchiveTask, {
      'archivePath': archivePath,
      'destinationDir': destinationDir,
      'password': password,
    });
  }

  static void _decodeArchiveTask(Map<String, dynamic> args) {
    String archivePath = args['archivePath'] as String;
    final destinationDir = args['destinationDir'] as String;
    final password = args['password'] as String?;

    File? tempCombinedFile;

    try {
      // Check for multi-volume archive (.001)
      if (archivePath.endsWith('.001')) {
        final baseName = archivePath.substring(0, archivePath.length - 4);
        final tempDir = Directory.systemTemp.createTempSync('extract_part');
        tempCombinedFile = File(p.join(tempDir.path, 'combined_archive'));
        final raf = tempCombinedFile.openSync(mode: FileMode.write);
        int partNum = 1;
        while (true) {
          final partExt = partNum.toString().padLeft(3, '0');
          final partFile = File('$baseName.$partExt');
          if (!partFile.existsSync()) break;
          raf.writeFromSync(partFile.readAsBytesSync());
          partNum++;
        }
        raf.closeSync();
        archivePath = tempCombinedFile.path;
      }

      final file = File(archivePath);
      final bytes = file.readAsBytesSync();
      Archive? archive;

      final lowerPath = archivePath.toLowerCase();

      if (lowerPath.endsWith('.zip') || lowerPath.contains('.zip.')) {
        archive = ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
      } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
        final tarBytes = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(tarBytes);
      } else if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
        final tarBytes = BZip2Decoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(tarBytes);
      } else if (lowerPath.endsWith('.tar')) {
        archive = TarDecoder().decodeBytes(bytes);
      } else if (lowerPath.endsWith('.gz')) {
        final decodedBytes = GZipDecoder().decodeBytes(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(decodedBytes);
        return;
      } else if (lowerPath.endsWith('.bz2')) {
        final decodedBytes = BZip2Decoder().decodeBytes(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(decodedBytes);
        return;
      } else {
        // Default attempt zip decoder
        archive = ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
      }

      if (archive != null) {
        for (final file in archive) {
          final filename = file.name;
          if (file.isFile) {
            final data = file.content as List<int>;
            final destFile = File(p.join(destinationDir, filename));
            destFile.createSync(recursive: true);
            destFile.writeAsBytesSync(data);
          } else {
            Directory(p.join(destinationDir, filename)).createSync(recursive: true);
          }
        }
      }
    } finally {
      if (tempCombinedFile != null && tempCombinedFile.existsSync()) {
        try {
          tempCombinedFile.parent.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
  }

  static Future<void> _deleteEntity(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      }
    } catch (_) {}
  }
}
