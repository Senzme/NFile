import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive_io.dart';
import 'package:dart_lz4/dart_lz4.dart';
import 'package:just_zstd/just_zstd.dart';
import '../providers/file_manager_provider.dart';
import 'package:provider/provider.dart';
import '../ui/widgets/background_operation_progress_dialog.dart';

class BackgroundOperation {
  final String id;
  final String title;
  final String archiveName;
  final bool isCompression;
  double progress; // 0.0 to 1.0
  String currentFile;
  bool isRunningInBackground;

  BackgroundOperation({
    required this.id,
    required this.title,
    required this.archiveName,
    required this.isCompression,
    this.progress = 0.0,
    this.currentFile = '',
    this.isRunningInBackground = false,
  });
}

class _FileEntry {
  final String fullPath;
  final String relPath;
  _FileEntry(this.fullPath, this.relPath);
}

class BackgroundArchiveService {
  static final BackgroundArchiveService instance = BackgroundArchiveService._();
  BackgroundArchiveService._();

  static const _channel = MethodChannel('com.rubex.nfile/notifications');

  final ValueNotifier<BackgroundOperation?> activeOperation = ValueNotifier(null);

  Isolate? _activeIsolate;
  ReceivePort? _receivePort;

  Future<void> startCompression({
    required BuildContext context,
    required List<String> sourcePaths,
    required String destinationPath,
    required String format,
    required int level,
    required bool deleteSource,
  }) async {
    final archiveName = p.basename(destinationPath);
    final operation = BackgroundOperation(
      id: 'compress_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Compressing Files',
      archiveName: archiveName,
      isCompression: true,
    );

    activeOperation.value = operation;

    // Show progress dialog
    BackgroundOperationProgressDialog.show(context, this);

    _receivePort = ReceivePort();

    _activeIsolate = await Isolate.spawn(
      _compressIsolateTask,
      {
        'sendPort': _receivePort!.sendPort,
        'sourcePaths': sourcePaths,
        'destinationPath': destinationPath,
        'format': format,
        'level': level,
        'deleteSource': deleteSource,
      },
    );

    _receivePort!.listen((message) {
      if (message is Map<String, dynamic>) {
        final status = message['status'] as String;
        if (status == 'progress') {
          final progress = message['progress'] as double;
          final currentFile = message['currentFile'] as String;

          operation.progress = progress;
          operation.currentFile = currentFile;
          activeOperation.value = operation;
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          activeOperation.notifyListeners();

          if (operation.isRunningInBackground) {
            _updateNotification(operation);
          }
        } else if (status == 'completed') {
          _onOperationComplete(context, operation, 'Archive created successfully');
        } else if (status == 'error') {
          final error = message['error'] as String;
          _onOperationComplete(context, operation, 'Compression failed: $error', isError: true);
        }
      }
    });
  }

  Future<void> startExtraction({
    required BuildContext context,
    required String archivePath,
    required String destinationDir,
    String? password,
  }) async {
    final archiveName = p.basename(archivePath);
    final operation = BackgroundOperation(
      id: 'extract_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Extracting Archive',
      archiveName: archiveName,
      isCompression: false,
    );

    activeOperation.value = operation;

    BackgroundOperationProgressDialog.show(context, this);

    _receivePort = ReceivePort();

    _activeIsolate = await Isolate.spawn(
      _extractIsolateTask,
      {
        'sendPort': _receivePort!.sendPort,
        'archivePath': archivePath,
        'destinationDir': destinationDir,
        'password': password,
      },
    );

    _receivePort!.listen((message) {
      if (message is Map<String, dynamic>) {
        final status = message['status'] as String;
        if (status == 'progress') {
          final progress = message['progress'] as double;
          final currentFile = message['currentFile'] as String;

          operation.progress = progress;
          operation.currentFile = currentFile;
          activeOperation.value = operation;
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          activeOperation.notifyListeners();

          if (operation.isRunningInBackground) {
            _updateNotification(operation);
          }
        } else if (status == 'completed') {
          _onOperationComplete(context, operation, 'Archive extracted successfully');
        } else if (status == 'error') {
          final error = message['error'] as String;
          _onOperationComplete(context, operation, 'Extraction failed: $error', isError: true);
        }
      }
    });
  }

  void cancelOperation() {
    _activeIsolate?.kill(priority: Isolate.beforeNextEvent);
    _activeIsolate = null;
    _receivePort?.close();
    _receivePort = null;

    final operation = activeOperation.value;
    if (operation != null) {
      _cancelNotification(operation);
      activeOperation.value = null;
    }
  }

  void runInBackground() async {
    final operation = activeOperation.value;
    if (operation == null) return;

    final status = await Permission.notification.request();
    if (status.isGranted) {
      operation.isRunningInBackground = true;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      activeOperation.notifyListeners();
      _updateNotification(operation);
    } else {
      operation.isRunningInBackground = true;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      activeOperation.notifyListeners();
    }
  }

  Future<void> _updateNotification(BackgroundOperation operation) async {
    if (!Platform.isAndroid) return;
    try {
      final progressInt = (operation.progress * 100).toInt();
      await _channel.invokeMethod('showProgressNotification', {
        'id': operation.id.hashCode,
        'title': operation.title,
        'message': '${operation.archiveName} ($progressInt%)',
        'progress': progressInt,
        'max': 100,
        'indeterminate': operation.progress <= 0.0,
      });
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  Future<void> _cancelNotification(BackgroundOperation operation) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelNotification', {
        'id': operation.id.hashCode,
      });
    } catch (_) {}
  }

  void _onOperationComplete(BuildContext context, BackgroundOperation operation, String message, {bool isError = false}) async {
    _activeIsolate = null;
    _receivePort?.close();
    _receivePort = null;

    if (operation.isRunningInBackground) {
      if (Platform.isAndroid) {
        final id = operation.id.hashCode;
        await _channel.invokeMethod('showProgressNotification', {
          'id': id,
          'title': isError ? 'Operation Failed' : 'Operation Completed',
          'message': isError ? 'Compression/extraction failed.' : '${operation.archiveName} processed successfully.',
          'progress': 100,
          'max': 100,
          'indeterminate': false,
        });
        Future.delayed(const Duration(seconds: 5), () {
          _channel.invokeMethod('cancelNotification', {'id': id});
        });
      }
    }

    try {
      final provider = Provider.of<FileManagerProvider>(context, listen: false);
      await provider.loadDirectory(provider.currentPath, showLoading: false);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );

    activeOperation.value = null;
  }

  static void _compressIsolateTask(Map<String, dynamic> args) async {
    final sendPort = args['sendPort'] as SendPort;
    final sourcePaths = args['sourcePaths'] as List<String>;
    final destinationPath = args['destinationPath'] as String;
    final format = args['format'] as String;
    final level = args['level'] as int;
    final deleteSource = args['deleteSource'] as bool;

    try {
      sendPort.send({'status': 'progress', 'progress': 0.0, 'currentFile': 'Scanning files...'});

      final allFiles = <_FileEntry>[];
      for (final path in sourcePaths) {
        final entityType = FileSystemEntity.typeSync(path);
        if (entityType == FileSystemEntityType.file) {
          allFiles.add(_FileEntry(path, p.basename(path)));
        } else if (entityType == FileSystemEntityType.directory) {
          final dir = Directory(path);
          if (dir.existsSync()) {
            final list = dir.listSync(recursive: true);
            for (final sub in list) {
              if (sub is File) {
                final relPath = p.relative(sub.path, from: p.dirname(path));
                allFiles.add(_FileEntry(sub.path, relPath));
              }
            }
          }
        }
      }

      if (allFiles.isEmpty) {
        sendPort.send({'status': 'error', 'error': 'No files found to compress'});
        return;
      }

      final archive = Archive();
      for (int i = 0; i < allFiles.length; i++) {
        final entry = allFiles[i];
        final progress = (i / allFiles.length) * 0.4;
        sendPort.send({
          'status': 'progress',
          'progress': progress,
          'currentFile': entry.relPath,
        });

        final bytes = File(entry.fullPath).readAsBytesSync();
        archive.addFile(ArchiveFile(entry.relPath, bytes.length, bytes));
      }

      sendPort.send({
        'status': 'progress',
        'progress': 0.5,
        'currentFile': 'Encoding archive structure...',
      });

      List<int>? encodedBytes;
      if (format == 'zip') {
        encodedBytes = ZipEncoder().encode(archive, level: level);
      } else if (format == 'tar') {
        encodedBytes = TarEncoder().encode(archive);
      } else if (format == 'tar.gz') {
        final tarBytes = TarEncoder().encode(archive);
        sendPort.send({'status': 'progress', 'progress': 0.7, 'currentFile': 'Applying GZIP compression...'});
        encodedBytes = GZipEncoder().encode(tarBytes);
      } else if (format == 'tar.bz2') {
        final tarBytes = TarEncoder().encode(archive);
        sendPort.send({'status': 'progress', 'progress': 0.7, 'currentFile': 'Applying BZIP2 compression...'});
        encodedBytes = BZip2Encoder().encode(tarBytes);
      } else if (format == 'tar.lz4') {
        final tarBytes = TarEncoder().encode(archive);
        sendPort.send({'status': 'progress', 'progress': 0.7, 'currentFile': 'Applying LZ4 compression...'});
        encodedBytes = lz4FrameEncode(Uint8List.fromList(tarBytes));
      } else if (format == 'tar.zst') {
        final tarBytes = TarEncoder().encode(archive);
        sendPort.send({'status': 'progress', 'progress': 0.7, 'currentFile': 'Applying ZSTD compression...'});
        encodedBytes = const ZstdEncoder().encodeBytes(Uint8List.fromList(tarBytes));
      }

      if (encodedBytes == null) {
        sendPort.send({'status': 'error', 'error': 'Unsupported format'});
        return;
      }

      sendPort.send({
        'status': 'progress',
        'progress': 0.9,
        'currentFile': 'Saving archive to disk...',
      });

      final outFile = File(destinationPath);
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(encodedBytes);

      if (deleteSource) {
        for (final path in sourcePaths) {
          final type = FileSystemEntity.typeSync(path);
          if (type == FileSystemEntityType.directory) {
            Directory(path).deleteSync(recursive: true);
          } else if (type == FileSystemEntityType.file) {
            File(path).deleteSync();
          }
        }
      }

      sendPort.send({'status': 'completed'});
    } catch (e) {
      sendPort.send({'status': 'error', 'error': e.toString()});
    }
  }

  static void _extractIsolateTask(Map<String, dynamic> args) async {
    final sendPort = args['sendPort'] as SendPort;
    final archivePath = args['archivePath'] as String;
    final destinationDir = args['destinationDir'] as String;
    final password = args['password'] as String?;

    try {
      sendPort.send({'status': 'progress', 'progress': 0.0, 'currentFile': 'Reading archive bytes...'});

      final file = File(archivePath);
      if (!file.existsSync()) {
        sendPort.send({'status': 'error', 'error': 'Archive file not found'});
        return;
      }
      final bytes = file.readAsBytesSync();
      late Archive archive;
      final lowerPath = archivePath.toLowerCase();

      sendPort.send({'status': 'progress', 'progress': 0.1, 'currentFile': 'Decompressing archive...'});

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
        sendPort.send({'status': 'completed'});
        return;
      } else if (lowerPath.endsWith('.bz2')) {
        final decodedBytes = BZip2Decoder().decodeBytes(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(decodedBytes);
        sendPort.send({'status': 'completed'});
        return;
      } else if (lowerPath.endsWith('.lz4')) {
        final decodedBytes = lz4FrameDecode(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(Uint8List.fromList(decodedBytes));
        sendPort.send({'status': 'completed'});
        return;
      } else if (lowerPath.endsWith('.zst') || lowerPath.endsWith('.zstd')) {
        final decodedBytes = const ZstdDecoder().decodeBytes(bytes);
        final name = p.basenameWithoutExtension(archivePath);
        final destFile = File(p.join(destinationDir, name));
        destFile.createSync(recursive: true);
        destFile.writeAsBytesSync(Uint8List.fromList(decodedBytes));
        sendPort.send({'status': 'completed'});
        return;
      } else {
        archive = ZipDecoder().decodeBytes(bytes, password: password != null && password.isNotEmpty ? password : null);
      }

      sendPort.send({'status': 'progress', 'progress': 0.3, 'currentFile': 'Extracting files...'});

      final totalFiles = archive.length;
      for (int i = 0; i < totalFiles; i++) {
        final file = archive[i];
        final progress = 0.3 + (i / totalFiles) * 0.7;
        sendPort.send({
          'status': 'progress',
          'progress': progress,
          'currentFile': file.name,
        });

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

      sendPort.send({'status': 'completed'});
    } catch (e) {
      sendPort.send({'status': 'error', 'error': e.toString()});
    }
  }
}
