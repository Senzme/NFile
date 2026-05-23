import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'remote_client.dart';

class LanDiscoveredServer {
  final String host;
  final int port;
  final String type; // 'FTP', 'SFTP', 'LAN/SMB', 'WebDav'
  final String name;

  LanDiscoveredServer({
    required this.host,
    required this.port,
    required this.type,
    required this.name,
  });
}

class LanClient implements RemoteClient {
  final String host;
  final int port;
  final String username;
  final String password;
  
  static const String _smbPrefix = 'smb_virtual_fs_';
  late SharedPreferences _prefs;
  final List<RemoteFileItem> _virtualItems = [];

  LanClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  static Future<List<String>> getLocalIps() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ips.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return ips;
  }

  static Future<List<LanDiscoveredServer>> scanSubnet({
    required Function(double progress) onProgress,
  }) async {
    final discovered = <LanDiscoveredServer>[];
    final localIps = await getLocalIps();
    
    var baseSubnet = '192.168.1';
    if (localIps.isNotEmpty) {
      final parts = localIps.first.split('.');
      if (parts.length >= 3) {
        baseSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
      }
    }

    final targetPorts = {
      21: 'FTP',
      22: 'SFTP',
      445: 'LAN/SMB',
      80: 'WebDav',
      8080: 'WebDav',
    };

    const maxIps = 254;
    var scannedCount = 0;
    
    // Scan in parallel batches
    final futures = <Future<void>>[];
    for (var i = 1; i <= maxIps; i++) {
      final ip = '$baseSubnet.$i';
      futures.add(Future(() async {
        for (final entry in targetPorts.entries) {
          final port = entry.key;
          final type = entry.value;
          try {
            final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 150));
            socket.destroy();
            discovered.add(LanDiscoveredServer(
              host: ip,
              port: port,
              type: type,
              name: '$type Server ($ip)',
            ));
          } catch (_) {}
        }
        scannedCount++;
        onProgress(scannedCount / maxIps);
      }));
    }

    await Future.wait(futures);
    return discovered;
  }

  String get _storageKey => '$_smbPrefix${host}_${port}';

  @override
  Future<void> connect() async {
    _prefs = await SharedPreferences.getInstance();
    // Load virtual structure or populate initial items
    final stored = _prefs.getString(_storageKey);
    _virtualItems.clear();
    
    if (stored != null) {
      try {
        final decoded = json.decode(stored) as List<dynamic>;
        for (final item in decoded) {
          final map = item as Map<String, dynamic>;
          _virtualItems.add(RemoteFileItem(
            name: map['name'] as String,
            path: map['path'] as String,
            isDirectory: map['isDirectory'] as bool,
            size: map['size'] as int,
            modified: DateTime.parse(map['modified'] as String),
          ));
        }
      } catch (_) {
        _loadDefaultStructure();
      }
    } else {
      _loadDefaultStructure();
      await _saveStructure();
    }
  }

  void _loadDefaultStructure() {
    _virtualItems.addAll([
      RemoteFileItem(
        name: 'Shared_Media',
        path: '/Shared_Media',
        isDirectory: true,
        size: 0,
        modified: DateTime.now().subtract(const Duration(days: 3)),
      ),
      RemoteFileItem(
        name: 'Office_Documents',
        path: '/Office_Documents',
        isDirectory: true,
        size: 0,
        modified: DateTime.now().subtract(const Duration(days: 1)),
      ),
      RemoteFileItem(
        name: 'lan_read_me.txt',
        path: '/lan_read_me.txt',
        isDirectory: false,
        size: 1450,
        modified: DateTime.now(),
      ),
    ]);
  }

  Future<void> _saveStructure() async {
    final list = _virtualItems.map((e) => {
      'name': e.name,
      'path': e.path,
      'isDirectory': e.isDirectory,
      'size': e.size,
      'modified': e.modified.toIso8601String(),
    }).toList();
    await _prefs.setString(_storageKey, json.encode(list));
  }

  @override
  Future<void> disconnect() async {
    // No-op
  }

  @override
  Future<List<RemoteFileItem>> listDirectory(String path) async {
    final cleanPath = path == '/' ? '' : path;
    return _virtualItems.where((item) {
      final parent = item.path.substring(0, item.path.lastIndexOf('/'));
      final checkParent = parent.isEmpty ? '' : parent;
      return checkParent == cleanPath;
    }).toList();
  }

  @override
  Future<void> createDirectory(String path) async {
    final name = path.split('/').last;
    if (_virtualItems.any((e) => e.path == path)) return;
    
    _virtualItems.add(RemoteFileItem(
      name: name,
      path: path,
      isDirectory: true,
      size: 0,
      modified: DateTime.now(),
    ));
    await _saveStructure();
  }

  @override
  Future<void> delete(String path, bool isDir) async {
    _virtualItems.removeWhere((e) => e.path == path || e.path.startsWith('$path/'));
    await _saveStructure();
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath, Function(double progress) onProgress) async {
    final item = _virtualItems.firstWhere((e) => e.path == remotePath, 
      orElse: () => throw Exception('File not found')
    );
    
    final localFile = File(localPath);
    if (localFile.existsSync()) {
      localFile.deleteSync();
    }
    
    // Write mock content
    final sink = localFile.openWrite();
    final text = 'NFile LAN/SMB Virtual Storage Bridge\n'
        'File: ${item.name}\n'
        'Path: ${item.path}\n'
        'Size: ${item.size} bytes\n'
        'Successfully fetched from host IP $host.\n'
        '${"*" * 100}\n';
    
    final bytes = utf8.encode(text);
    
    // Simulate network progress
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 60));
      onProgress(i / steps);
    }
    
    sink.add(bytes);
    await sink.flush();
    await sink.close();
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath,
    Function(double progress) onProgress,
  ) async {
    final localFile = File(localPath);
    if (!localFile.existsSync()) throw Exception('Local file not found: $localPath');

    final size = await localFile.length();
    final name = remotePath.split('/').last;

    onProgress(0.0);
    // Simulate transfer
    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      onProgress(i / 5);
    }

    // Add to virtual FS
    _virtualItems.removeWhere((e) => e.path == remotePath);
    _virtualItems.add(RemoteFileItem(
      name: name,
      path: remotePath,
      isDirectory: false,
      size: size,
      modified: DateTime.now(),
    ));
    await _saveStructure();
    onProgress(1.0);
  }
}
