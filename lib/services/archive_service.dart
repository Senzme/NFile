import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:dart_lz4/dart_lz4.dart';
import 'package:just_zstd/just_zstd.dart';

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
      encodedBytes = GZipEncoder().encode(tarBytes);
    } else if (format == 'tar.bz2') {
      final tarBytes = TarEncoder().encode(archive);
      encodedBytes = BZip2Encoder().encode(tarBytes);
    } else if (format == 'tar.lz4') {
      final tarBytes = TarEncoder().encode(archive);
      encodedBytes = lz4FrameEncode(Uint8List.fromList(tarBytes));
    } else if (format == 'tar.zst') {
      final tarBytes = TarEncoder().encode(archive);
      encodedBytes = const ZstdEncoder().encodeBytes(Uint8List.fromList(tarBytes));
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
      late Archive archive;

      final lowerPath = archivePath.toLowerCase();

      if (lowerPath.endsWith('.zip') || lowerPath.contains('.zip.')) {
        archive = ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
      } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
        final tarBytes = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(tarBytes);
      } else if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
        final tarBytes = BZip2Decoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(tarBytes);
      } else if (lowerPath.endsWith('.tar.lz4') || lowerPath.endsWith('.tlz4')) {
        final tarBytes = lz4FrameDecode(bytes);
        archive = TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
      } else if (lowerPath.endsWith('.tar.zst') || lowerPath.endsWith('.tzst')) {
        final tarBytes = const ZstdDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
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
      } else if (lowerPath.endsWith('.lz4')) {
        final decodedBytes = lz4FrameDecode(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(Uint8List.fromList(decodedBytes));
        return;
      } else if (lowerPath.endsWith('.zst') || lowerPath.endsWith('.zstd')) {
        final decodedBytes = const ZstdDecoder().decodeBytes(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(Uint8List.fromList(decodedBytes));
        return;
      } else {
        // Default attempt zip decoder
        archive = ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
      }

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

  static Future<Archive?> readArchive(String archivePath, {String? password}) async {
    return compute(_readArchiveTask, {'archivePath': archivePath, 'password': password});
  }

  static Archive? _readArchiveTask(Map<String, dynamic> args) {
    final archivePath = args['archivePath'] as String;
    final password = args['password'] as String?;

    try {
      final file = File(archivePath);
      if (!file.existsSync() || file.lengthSync() == 0) return Archive();
      final bytes = file.readAsBytesSync();
      final lowerPath = archivePath.toLowerCase();

      try {
        if (lowerPath.endsWith('.zip') || lowerPath.contains('.zip.')) {
          return ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
        } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
          final tarBytes = GZipDecoder().decodeBytes(bytes);
          return TarDecoder().decodeBytes(tarBytes);
        } else if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
          final tarBytes = BZip2Decoder().decodeBytes(bytes);
          return TarDecoder().decodeBytes(tarBytes);
        } else if (lowerPath.endsWith('.tar.lz4') || lowerPath.endsWith('.tlz4')) {
          final tarBytes = lz4FrameDecode(bytes);
          return TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
        } else if (lowerPath.endsWith('.tar.zst') || lowerPath.endsWith('.tzst')) {
          final tarBytes = const ZstdDecoder().decodeBytes(bytes);
          return TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
        } else if (lowerPath.endsWith('.tar')) {
          return TarDecoder().decodeBytes(bytes);
        } else {
          return ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
        }
      } catch (_) {
        return Archive();
      }
    } catch (e) {
      debugPrint('Error reading archive: $e');
      return Archive();
    }
  }

  static Future<bool> addFileToArchive({
    required String archivePath,
    required String filePathToAdd,
    required String internalPath,
  }) async {
    return compute(_addFileToArchiveTask, {
      'archivePath': archivePath,
      'filePathToAdd': filePathToAdd,
      'internalPath': internalPath,
    });
  }

  static bool _addFileToArchiveTask(Map<String, dynamic> args) {
    final archivePath = args['archivePath'] as String;
    final filePathToAdd = args['filePathToAdd'] as String;
    final internalPath = args['internalPath'] as String;

    try {
      final archiveFile = File(archivePath);
      final fileToAdd = File(filePathToAdd);
      if (!fileToAdd.existsSync()) return false;

      Archive archive = Archive();
      final lowerPath = archivePath.toLowerCase();
      bool isGz = false;
      bool isBz2 = false;
      bool isLz4 = false;
      bool isZst = false;

      if (archiveFile.existsSync() && archiveFile.lengthSync() > 0) {
        final bytes = archiveFile.readAsBytesSync();
        try {
          if (lowerPath.endsWith('.zip')) {
            archive = ZipDecoder().decodeBytes(bytes);
          } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
            isGz = true;
            final tarBytes = GZipDecoder().decodeBytes(bytes);
            archive = TarDecoder().decodeBytes(tarBytes);
          } else if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
            isBz2 = true;
            final tarBytes = BZip2Decoder().decodeBytes(bytes);
            archive = TarDecoder().decodeBytes(tarBytes);
          } else if (lowerPath.endsWith('.tar.lz4') || lowerPath.endsWith('.tlz4')) {
            isLz4 = true;
            final tarBytes = lz4FrameDecode(bytes);
            archive = TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
          } else if (lowerPath.endsWith('.tar.zst') || lowerPath.endsWith('.tzst')) {
            isZst = true;
            final tarBytes = const ZstdDecoder().decodeBytes(bytes);
            archive = TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
          } else if (lowerPath.endsWith('.tar')) {
            archive = TarDecoder().decodeBytes(bytes);
          } else {
            archive = ZipDecoder().decodeBytes(bytes);
          }
        } catch (_) {
          archive = Archive();
        }
      }

      final newFileBytes = fileToAdd.readAsBytesSync();
      final nameInside = p.join(internalPath, p.basename(filePathToAdd)).replaceAll('\\', '/');
      archive.addFile(ArchiveFile(nameInside, newFileBytes.length, newFileBytes));

      List<int>? newArchiveBytes;
      if (lowerPath.endsWith('.tar')) {
        newArchiveBytes = TarEncoder().encode(archive);
      } else if (isGz) {
        final tarBytes = TarEncoder().encode(archive);
        newArchiveBytes = GZipEncoder().encode(tarBytes);
      } else if (isBz2) {
        final tarBytes = TarEncoder().encode(archive);
        newArchiveBytes = BZip2Encoder().encode(tarBytes);
      } else if (isLz4) {
        final tarBytes = TarEncoder().encode(archive);
        newArchiveBytes = lz4FrameEncode(Uint8List.fromList(tarBytes));
      } else if (isZst) {
        final tarBytes = TarEncoder().encode(archive);
        newArchiveBytes = const ZstdEncoder().encodeBytes(Uint8List.fromList(tarBytes));
      } else {
        newArchiveBytes = ZipEncoder().encode(archive);
      }

      if (newArchiveBytes != null) {
        archiveFile.writeAsBytesSync(newArchiveBytes);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding to archive: $e');
      return false;
    }
  }

  static Future<bool> deleteItemsFromArchive({
    required String archivePath,
    required List<String> internalPathsToDelete,
  }) async {
    return compute(_deleteItemsFromArchiveTask, {
      'archivePath': archivePath,
      'internalPathsToDelete': internalPathsToDelete,
    });
  }

  static bool _deleteItemsFromArchiveTask(Map<String, dynamic> args) {
    final archivePath = args['archivePath'] as String;
    final internalPathsToDelete = args['internalPathsToDelete'] as List<String>;

    try {
      final archiveFile = File(archivePath);
      if (!archiveFile.existsSync() || archiveFile.lengthSync() == 0) return false;

      final bytes = archiveFile.readAsBytesSync();
      final lowerPath = archivePath.toLowerCase();
      late Archive archive;
      bool isGz = false;
      bool isBz2 = false;
      bool isLz4 = false;
      bool isZst = false;

      try {
        if (lowerPath.endsWith('.zip')) {
          archive = ZipDecoder().decodeBytes(bytes);
        } else if (lowerPath.endsWith('.tar.gz') || lowerPath.endsWith('.tgz')) {
          isGz = true;
          final tarBytes = GZipDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(tarBytes);
        } else if (lowerPath.endsWith('.tar.bz2') || lowerPath.endsWith('.tbz2')) {
          isBz2 = true;
          final tarBytes = BZip2Decoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(tarBytes);
        } else if (lowerPath.endsWith('.tar.lz4') || lowerPath.endsWith('.tlz4')) {
          isLz4 = true;
          final tarBytes = lz4FrameDecode(bytes);
          archive = TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
        } else if (lowerPath.endsWith('.tar.zst') || lowerPath.endsWith('.tzst')) {
          isZst = true;
          final tarBytes = const ZstdDecoder().decodeBytes(bytes);
          archive = TarDecoder().decodeBytes(Uint8List.fromList(tarBytes));
        } else if (lowerPath.endsWith('.tar')) {
          archive = TarDecoder().decodeBytes(bytes);
        } else {
          archive = ZipDecoder().decodeBytes(bytes);
        }
      } catch (_) {
        return false;
      }

      final newArchive = Archive();
      for (final f in archive.files) {
        var name = f.name.replaceAll('\\', '/');
        while (name.startsWith('/')) {
          name = name.substring(1);
        }
        while (name.startsWith('./')) {
          name = name.substring(2);
        }
        bool shouldDelete = false;
        for (final toDel in internalPathsToDelete) {
          if (toDel.endsWith('/')) {
            if (name.startsWith(toDel) || name == toDel.substring(0, toDel.length - 1)) {
              shouldDelete = true;
              break;
            }
          } else {
            if (name == toDel) {
              shouldDelete = true;
              break;
            }
          }
        }
        if (!shouldDelete) {
          newArchive.addFile(f);
        }
      }

      List<int>? newArchiveBytes;
      if (lowerPath.endsWith('.tar')) {
        newArchiveBytes = TarEncoder().encode(newArchive);
      } else if (isGz) {
        final tarBytes = TarEncoder().encode(newArchive);
        newArchiveBytes = GZipEncoder().encode(tarBytes);
      } else if (isBz2) {
        final tarBytes = TarEncoder().encode(newArchive);
        newArchiveBytes = BZip2Encoder().encode(tarBytes);
      } else if (isLz4) {
        final tarBytes = TarEncoder().encode(newArchive);
        newArchiveBytes = lz4FrameEncode(Uint8List.fromList(tarBytes));
      } else if (isZst) {
        final tarBytes = TarEncoder().encode(newArchive);
        newArchiveBytes = const ZstdEncoder().encodeBytes(Uint8List.fromList(tarBytes));
      } else {
        newArchiveBytes = ZipEncoder().encode(newArchive);
      }

      if (newArchiveBytes != null) {
        archiveFile.writeAsBytesSync(newArchiveBytes);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting from archive: $e');
      return false;
    }
  }
}
