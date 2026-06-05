import 'package:flutter/services.dart';
import 'remote_client.dart';

class SafRemoteClient implements RemoteClient {
  final String rootUri;
  static const _channel = MethodChannel('com.rubex.nfile/saf');

  SafRemoteClient({required this.rootUri});

  @override
  Future<void> connect() async {
    // No-op for SAF
  }

  @override
  Future<void> disconnect() async {
    // No-op
  }

  @override
  Future<List<RemoteFileItem>> listDirectory(String path) async {
    final String pathUri = (path == '/' || path == rootUri) ? '' : path;
    final List<dynamic> result = await _channel.invokeMethod('listDirectory', {
      'rootUri': rootUri,
      'pathUri': pathUri,
    });

    return result.map((e) {
      final map = Map<String, dynamic>.from(e);
      return RemoteFileItem(
        name: map['name'] as String,
        path: map['path'] as String,
        isDirectory: map['isDirectory'] as bool,
        size: map['size'] as int,
        modified: DateTime.fromMillisecondsSinceEpoch(map['modified'] as int),
      );
    }).toList();
  }

  @override
  Future<void> createDirectory(String path) async {
    final int lastSlash = path.lastIndexOf('/');
    final String parentUri = lastSlash != -1 ? path.substring(0, lastSlash) : '';
    final String folderName = lastSlash != -1 ? path.substring(lastSlash + 1) : 'New Folder';

    await _channel.invokeMethod('createDirectory', {
      'rootUri': rootUri,
      'parentUri': parentUri,
      'name': folderName,
    });
  }

  @override
  Future<void> delete(String path, bool isDir) async {
    await _channel.invokeMethod('delete', {
      'rootUri': rootUri,
      'uri': path,
    });
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath, Function(double progress) onProgress) async {
    onProgress(0.0);
    await _channel.invokeMethod('downloadFile', {
      'rootUri': rootUri,
      'uri': remotePath,
      'localPath': localPath,
    });
    onProgress(1.0);
  }

  @override
  Future<void> uploadFile(String localPath, String remotePath, Function(double progress) onProgress) async {
    onProgress(0.0);
    final int lastSlash = remotePath.lastIndexOf('/');
    final String parentUri = lastSlash != -1 ? remotePath.substring(0, lastSlash) : '';
    final String fileName = lastSlash != -1 ? remotePath.substring(lastSlash + 1) : 'file';

    await _channel.invokeMethod('uploadFile', {
      'rootUri': rootUri,
      'parentUri': parentUri,
      'localPath': localPath,
      'fileName': fileName,
    });
    onProgress(1.0);
  }
}
