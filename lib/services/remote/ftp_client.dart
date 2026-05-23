import 'dart:io';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as p;
import 'remote_client.dart';

class FtpRemoteClient implements RemoteClient {
  final String host;
  final int port;
  final String username;
  final String password;

  FTPConnect? _ftpConnect;

  FtpRemoteClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  @override
  Future<void> connect() async {
    _ftpConnect = FTPConnect(
      host,
      port: port,
      user: username.isEmpty ? 'anonymous' : username,
      pass: password.isEmpty ? 'anonymous@' : password,
      timeout: 15,
    );
    final success = await _ftpConnect!.connect();
    if (!success) {
      throw Exception('FTP connection failed: could not connect to $host:$port');
    }
  }

  @override
  Future<void> disconnect() async {
    await _ftpConnect?.disconnect();
    _ftpConnect = null;
  }

  @override
  Future<List<RemoteFileItem>> listDirectory(String path) async {
    if (_ftpConnect == null) throw Exception('FTP not connected');

    // Navigate to directory
    final targetPath = (path.isEmpty || path == '/') ? '/' : path;
    if (targetPath != '/') {
      final ok = await _ftpConnect!.changeDirectory(targetPath);
      if (!ok) throw Exception('Cannot open directory: $targetPath');
    } else {
      await _ftpConnect!.changeDirectory('/');
    }

    final allEntries = await _ftpConnect!.listDirectoryContent();

    final list = <RemoteFileItem>[];
    for (final entry in allEntries) {
      if (entry.name == '.' || entry.name == '..') continue;
      if (entry.type == FTPEntryType.unknown) continue;

      final fullPath = path == '/' ? '/${entry.name}' : '$path/${entry.name}';
      final isDir = entry.type == FTPEntryType.dir;

      list.add(RemoteFileItem(
        name: entry.name,
        path: fullPath,
        isDirectory: isDir,
        size: entry.size ?? 0,
        modified: entry.modifyTime ?? DateTime.now(),
      ));
    }
    return list;
  }

  @override
  Future<void> createDirectory(String path) async {
    if (_ftpConnect == null) throw Exception('FTP not connected');
    final dirName = p.basename(path);
    final parentPath = p.dirname(path);

    if (parentPath.isNotEmpty && parentPath != '/') {
      await _ftpConnect!.changeDirectory(parentPath);
    }

    final ok = await _ftpConnect!.makeDirectory(dirName);
    if (!ok) throw Exception('Failed to create directory: $path');
  }

  @override
  Future<void> delete(String path, bool isDir) async {
    if (_ftpConnect == null) throw Exception('FTP not connected');
    if (isDir) {
      final ok = await _ftpConnect!.deleteDirectory(path);
      if (!ok) throw Exception('Failed to delete directory: $path');
    } else {
      final fileName = p.basename(path);
      final parentPath = p.dirname(path);
      if (parentPath.isNotEmpty && parentPath != '/') {
        await _ftpConnect!.changeDirectory(parentPath);
      }
      final ok = await _ftpConnect!.deleteFile(fileName);
      if (!ok) throw Exception('Failed to delete file: $path');
    }
  }

  @override
  Future<void> downloadFile(
    String remotePath,
    String localPath,
    Function(double progress) onProgress,
  ) async {
    if (_ftpConnect == null) throw Exception('FTP not connected');

    final fileName = p.basename(remotePath);
    final parentPath = p.dirname(remotePath);

    // Navigate to the parent directory of the file
    if (parentPath.isNotEmpty && parentPath != '/') {
      final ok = await _ftpConnect!.changeDirectory(parentPath);
      if (!ok) throw Exception('Cannot open directory: $parentPath');
    }

    final localFile = File(localPath);
    if (localFile.existsSync()) {
      localFile.deleteSync();
    }

    onProgress(0.0);

    final ok = await _ftpConnect!.downloadFile(
      fileName,
      localFile,
      onProgress: (progressPercent, received, fileSize) {
        // ftpconnect gives progress as 0-100 percent
        onProgress((progressPercent / 100.0).clamp(0.0, 1.0));
      },
    );

    if (!ok) throw Exception('Download failed for: $remotePath');
    onProgress(1.0);
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath,
    Function(double progress) onProgress,
  ) async {
    if (_ftpConnect == null) throw Exception('FTP not connected');

    final localFile = File(localPath);
    if (!localFile.existsSync()) throw Exception('Local file not found: $localPath');

    final remoteFileName = p.basename(remotePath);
    final remoteDir = p.dirname(remotePath);

    // Navigate to the destination directory
    if (remoteDir.isNotEmpty && remoteDir != '/') {
      await _ftpConnect!.createFolderIfNotExist(remoteDir);
      final ok = await _ftpConnect!.changeDirectory(remoteDir);
      if (!ok) throw Exception('Cannot open remote directory: $remoteDir');
    }

    onProgress(0.0);

    final ok = await _ftpConnect!.uploadFile(
      localFile,
      sRemoteName: remoteFileName,
      onProgress: (progressPercent, sent, fileSize) {
        onProgress((progressPercent / 100.0).clamp(0.0, 1.0));
      },
    );

    if (!ok) throw Exception('Upload failed for: $localPath');
    onProgress(1.0);
  }
}
