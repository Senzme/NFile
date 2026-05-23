import 'dart:io';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'remote_client.dart';

class SftpRemoteClient implements RemoteClient {
  final String host;
  final int port;
  final String username;
  final String password;
  
  SSHClient? _sshClient;
  SftpClient? _sftpClient;

  SftpRemoteClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  @override
  Future<void> connect() async {
    final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 15));
    _sshClient = SSHClient(
      socket,
      username: username,
      onPasswordRequest: () => password,
    );
    _sftpClient = await _sshClient!.sftp();
  }

  @override
  Future<void> disconnect() async {
    _sshClient?.close();
    await _sshClient?.done;
    _sshClient = null;
    _sftpClient = null;
  }

  @override
  Future<List<RemoteFileItem>> listDirectory(String path) async {
    if (_sftpClient == null) throw Exception('SFTP not connected');
    final absolutePath = path.isEmpty || path == '/' ? '.' : path;
    final items = await _sftpClient!.listdir(absolutePath);
    
    final list = <RemoteFileItem>[];
    for (final item in items) {
      if (item.filename == '.' || item.filename == '..') continue;
      final isDir = item.attr.isDirectory;
      final fullPath = path == '/' ? '/${item.filename}' : '$path/${item.filename}';
      
      final modifyTimeSeconds = item.attr.modifyTime;
      final modifiedDate = modifyTimeSeconds != null
          ? DateTime.fromMillisecondsSinceEpoch(modifyTimeSeconds * 1000)
          : DateTime.now();

      list.add(RemoteFileItem(
        name: item.filename,
        path: fullPath,
        isDirectory: isDir,
        size: item.attr.size ?? 0,
        modified: modifiedDate,
      ));
    }
    return list;
  }

  @override
  Future<void> createDirectory(String path) async {
    if (_sftpClient == null) throw Exception('SFTP not connected');
    await _sftpClient!.mkdir(path);
  }

  @override
  Future<void> delete(String path, bool isDir) async {
    if (_sftpClient == null) throw Exception('SFTP not connected');
    if (isDir) {
      await _sftpClient!.rmdir(path);
    } else {
      await _sftpClient!.remove(path);
    }
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath, Function(double progress) onProgress) async {
    if (_sftpClient == null) throw Exception('SFTP not connected');
    
    final file = await _sftpClient!.open(remotePath);
    final stat = await _sftpClient!.stat(remotePath);
    final totalSize = stat.size ?? 0;
    
    final localFile = File(localPath);
    if (localFile.existsSync()) {
      localFile.deleteSync();
    }
    final sink = localFile.openWrite();
    
    int downloaded = 0;
    try {
      final stream = file.read();
      await for (final chunk in stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (totalSize > 0) {
          onProgress(downloaded / totalSize);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
      await file.close();
    }
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath,
    Function(double progress) onProgress,
  ) async {
    if (_sftpClient == null) throw Exception('SFTP not connected');

    final localFile = File(localPath);
    if (!localFile.existsSync()) throw Exception('Local file not found: $localPath');

    final totalSize = await localFile.length();

    // Open remote file for writing
    final remoteFile = await _sftpClient!.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.truncate | SftpFileOpenMode.write,
    );

    onProgress(0.0);

    try {
      final writer = remoteFile.write(
        localFile.openRead().map((chunk) => Uint8List.fromList(chunk)),
        onProgress: (bytesWritten) {
          if (totalSize > 0) {
            onProgress((bytesWritten / totalSize).clamp(0.0, 1.0));
          }
        },
      );
      await writer.done;
    } finally {
      await remoteFile.close();
    }

    onProgress(1.0);
  }
}
