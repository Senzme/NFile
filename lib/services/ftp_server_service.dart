import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class FtpServerService {
  static final FtpServerService instance = FtpServerService._internal();
  FtpServerService._internal();

  static const _channel = MethodChannel('com.rubex.nfile/ftp_service');

  ServerSocket? _controlSocket;
  int _port = 9999;
  String _homeDir = '/storage/emulated/0';
  String _username = 'Anonymous';
  bool _anonymous = true;
  bool _showHidden = false;
  bool _isActive = false;
  String _ipAddress = '127.0.0.1';

  final List<Socket> _activeSockets = [];
  final List<ServerSocket> _activeDataSockets = [];

  VoidCallback? onStatusChanged;

  bool get isActive => _isActive;
  int get port => _port;
  String get homeDir => _homeDir;
  String get username => _username;
  bool get anonymous => _anonymous;
  bool get showHidden => _showHidden;
  String get ipAddress => _ipAddress;

  void configure({
    int? port,
    String? homeDir,
    String? username,
    bool? anonymous,
    bool? showHidden,
  }) {
    if (port != null) _port = port;
    if (homeDir != null) _homeDir = homeDir;
    if (username != null) _username = username;
    if (anonymous != null) _anonymous = anonymous;
    if (showHidden != null) _showHidden = showHidden;
    onStatusChanged?.call();
  }

  Future<void> start() async {
    if (_isActive) return;
    try {
      _ipAddress = await _getLocalIp();
      _controlSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _port, shared: true);
      _isActive = true;
      _controlSocket!.listen(_handleConnection, onError: (e) {
        if (kDebugMode) print('FTP Control Server error: $e');
      });
      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod('startFtpService', {
            'ip': _ipAddress,
            'port': _port,
          });
        } catch (e) {
          if (kDebugMode) print('Failed to start background notification service: $e');
        }
      }
      onStatusChanged?.call();
    } catch (e) {
      if (kDebugMode) print('Failed to start FTP server: $e');
      stop();
      rethrow;
    }
  }

  void stop() {
    _isActive = false;
    _controlSocket?.close();
    _controlSocket = null;
    for (var socket in _activeSockets) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _activeSockets.clear();
    for (var server in _activeDataSockets) {
      try {
        server.close();
      } catch (_) {}
    }
    _activeDataSockets.clear();
    if (Platform.isAndroid) {
      try {
        _channel.invokeMethod('stopFtpService');
      } catch (e) {
        if (kDebugMode) print('Failed to stop background notification service: $e');
      }
    }
    onStatusChanged?.call();
  }

  Future<String> _getLocalIp() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  void _handleConnection(Socket client) {
    _activeSockets.add(client);
    final session = FtpSession(this, client);
    session.start();
  }
}

class FtpSession {
  final FtpServerService server;
  final Socket controlSocket;
  String currentDir = '/';
  
  ServerSocket? passiveServer;
  Socket? passiveDataSocket;
  
  String? activeHost;
  int? activePort;

  String? renameFromPath;

  FtpSession(this.server, this.controlSocket);

  void start() {
    sendResponse('220 NFile FTP Server ready.');
    
    controlSocket.listen(
      (bytes) {
        final data = utf8.decode(bytes);
        final lines = data.split('\r\n');
        for (var line in lines) {
          if (line.trim().isEmpty) continue;
          _processCommand(line);
        }
      },
      onError: (e) {
        close();
      },
      onDone: () {
        close();
      },
    );
  }

  void sendResponse(String response) {
    try {
      controlSocket.write('$response\r\n');
    } catch (_) {}
  }

  void close() {
    try {
      controlSocket.destroy();
    } catch (_) {}
    server._activeSockets.remove(controlSocket);
    passiveServer?.close();
  }

  String _getAbsolutePath(String relPath) {
    String path = relPath;
    if (!path.startsWith('/')) {
      path = p.join(currentDir, path);
    }
    path = p.normalize(path);
    final fullPath = p.join(server.homeDir, path.startsWith('/') ? path.substring(1) : path);
    return p.normalize(fullPath);
  }

  void _processCommand(String rawLine) async {
    final parts = rawLine.trim().split(' ');
    final cmd = parts[0].toUpperCase();
    final arg = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    switch (cmd) {
      case 'USER':
        if (server.anonymous) {
          sendResponse('230 Anonymous user logged in.');
        } else {
          sendResponse('331 User name okay, need password.');
        }
        break;
      case 'PASS':
        sendResponse('230 User logged in, proceed.');
        break;
      case 'SYST':
        sendResponse('215 UNIX Type: L8');
        break;
      case 'FEAT':
        sendResponse('211-Features:\n UTF8\n211 End');
        break;
      case 'OPTS':
        if (arg.toUpperCase() == 'UTF8 ON') {
          sendResponse('200 UTF8 Option Enabled');
        } else {
          sendResponse('501 Option not understood');
        }
        break;
      case 'PWD':
        sendResponse('257 "$currentDir" is current directory.');
        break;
      case 'TYPE':
        sendResponse('200 Type set to $arg');
        break;
      case 'PASV':
        await _enterPassiveMode();
        break;
      case 'PORT':
        _enterActiveMode(arg);
        break;
      case 'LIST':
        await _handleList(arg);
        break;
      case 'CWD':
        _handleCwd(arg);
        break;
      case 'CDUP':
        _handleCwd('..');
        break;
      case 'SIZE':
        _handleSize(arg);
        break;
      case 'RETR':
        await _handleRetrieve(arg);
        break;
      case 'STOR':
        await _handleStore(arg);
        break;
      case 'DELE':
        _handleDelete(arg);
        break;
      case 'MKD':
        _handleMakeDir(arg);
        break;
      case 'RMD':
        _handleRemoveDir(arg);
        break;
      case 'RNFR':
        renameFromPath = _getAbsolutePath(arg);
        sendResponse('350 File exists, ready for destination name.');
        break;
      case 'RNTO':
        _handleRenameTo(arg);
        break;
      case 'NOOP':
        sendResponse('200 OK');
        break;
      case 'QUIT':
        sendResponse('221 Goodbye.');
        close();
        break;
      default:
        sendResponse('502 Command not implemented.');
    }
  }

  Future<void> _enterPassiveMode() async {
    try {
      passiveServer?.close();
      passiveServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
      server._activeDataSockets.add(passiveServer!);

      final port = passiveServer!.port;
      final ipParts = server.ipAddress.split('.');
      if (ipParts.length != 4) {
        sendResponse('500 Internal error');
        return;
      }
      final p1 = port >> 8;
      final p2 = port & 0xFF;
      sendResponse('227 Entering Passive Mode (${ipParts.join(",")},$p1,$p2)');

      passiveServer!.listen((socket) {
        passiveDataSocket = socket;
      }, onDone: () {
        passiveServer = null;
      });
    } catch (e) {
      sendResponse('451 Local error in processing.');
    }
  }

  void _enterActiveMode(String arg) {
    final parts = arg.split(',');
    if (parts.length != 6) {
      sendResponse('501 Syntax error');
      return;
    }
    activeHost = parts.sublist(0, 4).join('.');
    activePort = (int.parse(parts[4]) << 8) + int.parse(parts[5]);
    sendResponse('200 PORT command successful.');
  }

  Future<Socket?> _getDataSocket() async {
    if (passiveServer != null) {
      int elapsed = 0;
      while (passiveDataSocket == null && elapsed < 5000) {
        await Future.delayed(const Duration(milliseconds: 100));
        elapsed += 100;
      }
      final sock = passiveDataSocket;
      passiveDataSocket = null;
      passiveServer?.close();
      passiveServer = null;
      return sock;
    } else if (activeHost != null && activePort != null) {
      try {
        final sock = await Socket.connect(activeHost, activePort!);
        activeHost = null;
        activePort = null;
        return sock;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _handleList(String arg) async {
    final dataSocket = await _getDataSocket();
    if (dataSocket == null) {
      sendResponse('425 Can\'t open data connection.');
      return;
    }
    sendResponse('150 Opening ASCII mode data connection for file list.');

    try {
      final targetPath = _getAbsolutePath(arg);
      final dir = Directory(targetPath);
      if (await dir.exists()) {
        final buffer = StringBuffer();
        await for (var entity in dir.list()) {
          final stat = await entity.stat();
          final name = p.basename(entity.path);
          if (!server.showHidden && name.startsWith('.')) continue;

          final size = stat.size;
          final isDir = stat.type == FileSystemEntityType.directory;
          
          final typeChar = isDir ? 'd' : '-';
          final permissions = isDir ? 'rwxr-xr-x' : 'rw-r--r--';
          final dateStr = _formatDate(stat.modified);
          
          buffer.write('$typeChar$permissions 1 owner group $size $dateStr $name\r\n');
        }
        dataSocket.write(buffer.toString());
      }
      await dataSocket.flush();
    } catch (_) {} finally {
      await dataSocket.close();
      sendResponse('226 Transfer complete.');
    }
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final day = dt.day.toString().padLeft(2);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$month $day $hour:$minute';
  }

  void _handleCwd(String arg) {
    String target = arg;
    if (target == '..') {
      if (currentDir != '/') {
        final parts = currentDir.split('/');
        parts.removeLast();
        currentDir = parts.join('/');
        if (currentDir.isEmpty) currentDir = '/';
      }
      sendResponse('250 Directory successfully changed.');
      return;
    }

    if (target.startsWith('/')) {
      currentDir = p.normalize(target);
    } else {
      currentDir = p.normalize(p.join(currentDir, target));
    }
    if (!currentDir.startsWith('/')) {
      currentDir = '/$currentDir';
    }

    final absPath = _getAbsolutePath('');
    if (!Directory(absPath).existsSync()) {
      sendResponse('550 Directory not found.');
    } else {
      sendResponse('250 Directory successfully changed.');
    }
  }

  void _handleSize(String arg) async {
    final absPath = _getAbsolutePath(arg);
    final file = File(absPath);
    if (await file.exists()) {
      final len = await file.length();
      sendResponse('213 $len');
    } else {
      sendResponse('550 File not found.');
    }
  }

  Future<void> _handleRetrieve(String arg) async {
    final absPath = _getAbsolutePath(arg);
    final file = File(absPath);
    if (!await file.exists()) {
      sendResponse('550 File not found.');
      return;
    }

    final dataSocket = await _getDataSocket();
    if (dataSocket == null) {
      sendResponse('425 Can\'t open data connection.');
      return;
    }

    sendResponse('150 Opening BINARY mode data connection.');
    try {
      await dataSocket.addStream(file.openRead());
    } catch (_) {} finally {
      await dataSocket.close();
      sendResponse('226 Transfer complete.');
    }
  }

  Future<void> _handleStore(String arg) async {
    final absPath = _getAbsolutePath(arg);
    final file = File(absPath);

    final dataSocket = await _getDataSocket();
    if (dataSocket == null) {
      sendResponse('425 Can\'t open data connection.');
      return;
    }

    sendResponse('150 Opening BINARY mode data connection.');
    try {
      final sink = file.openWrite();
      await sink.addStream(dataSocket);
      await sink.close();
    } catch (_) {} finally {
      await dataSocket.close();
      sendResponse('226 Transfer complete.');
    }
  }

  void _handleDelete(String arg) async {
    final absPath = _getAbsolutePath(arg);
    final file = File(absPath);
    if (await file.exists()) {
      await file.delete();
      sendResponse('250 File deleted successfully.');
    } else {
      sendResponse('550 File not found.');
    }
  }

  void _handleMakeDir(String arg) async {
    final absPath = _getAbsolutePath(arg);
    final dir = Directory(absPath);
    try {
      await dir.create(recursive: true);
      sendResponse('257 "$arg" directory created.');
    } catch (_) {
      sendResponse('550 Can\'t create directory.');
    }
  }

  void _handleRemoveDir(String arg) async {
    final absPath = _getAbsolutePath(arg);
    final dir = Directory(absPath);
    try {
      await dir.delete(recursive: true);
      sendResponse('250 Directory deleted successfully.');
    } catch (_) {
      sendResponse('550 Can\'t delete directory.');
    }
  }

  void _handleRenameTo(String arg) async {
    if (renameFromPath == null) {
      sendResponse('503 Bad sequence of commands.');
      return;
    }
    final toPath = _getAbsolutePath(arg);
    try {
      final type = await FileSystemEntity.type(renameFromPath!);
      if (type == FileSystemEntityType.file) {
        await File(renameFromPath!).rename(toPath);
      } else if (type == FileSystemEntityType.directory) {
        await Directory(renameFromPath!).rename(toPath);
      } else {
        throw Exception();
      }
      sendResponse('250 File renamed successfully.');
    } catch (_) {
      sendResponse('550 File rename failed.');
    } finally {
      renameFromPath = null;
    }
  }
}
