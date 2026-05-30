import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:dartssh2/dartssh2.dart';

class WebSharingService extends ChangeNotifier {
  static final WebSharingService instance = WebSharingService._();
  WebSharingService._();

  static const _channel = MethodChannel('com.rubex.nfile/web_sharing_service');

  static const String _ed25519PrivateKeyPem = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAWN3mZdOKrXnP+VFVDS6yuPfVgGbCOa0a/B0YHt7wfpAAAAJj80blj/NG5
YwAAAAtzc2gtZWQyNTUxOQAAACAWN3mZdOKrXnP+VFVDS6yuPfVgGbCOa0a/B0YHt7wfpA
AAAEBbg6hQHydFb0ZGHuYq+gCui5fFtXW1X2e3Ok3UKTfXMhY3eZl04qtec/5UVUNLrK49
9WAZsI5rRr8HRge3vB+kAAAAFWFkbWluQERFU0tUT1AtS1NIUkFVNw==
-----END OPENSSH PRIVATE KEY-----
''';

  SSHClient? _sshClient;
  SSHRemoteForward? _sshForward;

  HttpServer? _localServer;
  bool _isLocalActive = false;
  String _localIpAddress = '';
  final int _port = 8080;

  bool _isInternetActive = false;
  String _internetShareLink = '';

  // Getters
  bool get isLocalActive => _isLocalActive;
  bool get isInternetActive => _isInternetActive;
  String get localIpAddress => _localIpAddress;
  int get port => _port;
  String get internetShareLink => _internetShareLink;
  String get localServerUrl => 'http://$_localIpAddress:$_port';

  // Dynamic active clients state
  final Map<String, ActiveClient> _clientsMap = {};
  Timer? _speedTimer;

  List<Map<String, dynamic>> get activeClients {
    return _clientsMap.values.map((client) {
      final double progress = client.totalBytes > 0
          ? (client.bytesTransferred / client.totalBytes).clamp(0.0, 1.0)
          : 0.0;

      String transferredStr = '';
      if (client.bytesTransferred > 1024 * 1024 * 1024) {
        transferredStr = '${(client.bytesTransferred / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      } else if (client.bytesTransferred > 1024 * 1024) {
        transferredStr = '${(client.bytesTransferred / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        transferredStr = '${(client.bytesTransferred / 1024).toStringAsFixed(0)} KB';
      }

      return {
        'device': client.device,
        'speed': double.parse(client.speed.toStringAsFixed(1)),
        'transferred': transferredStr,
        'file': client.currentFile,
        'progress': progress,
      };
    }).toList();
  }

  // Real HTTP Local Server lifecycle
  Future<void> startLocalServer(String rootDir) async {
    if (_isLocalActive) return;

    try {
      // 1. Resolve local Wi-Fi IP address
      _localIpAddress = await _detectLocalIp();

      // 2. Bind HttpServer
      _localServer = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _isLocalActive = true;
      notifyListeners();

      // 3. Start Native Background Foreground Service
      try {
        await _channel.invokeMethod('startWebSharingService', {
          'url': 'http://$_localIpAddress:$_port',
          'isInternet': false,
        });
      } catch (e) {
        debugPrint('Failed to start native web sharing service: $e');
      }

      // 4. Listen to incoming requests
      _localServer!.listen((HttpRequest request) async {
        try {
          await _handleHttpRequest(request, rootDir);
        } catch (e) {
          debugPrint('Error handling web share HTTP request: $e');
          try {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write('500 Internal Server Error: $e');
            await request.response.close();
          } catch (_) {}
        }
      });
    } catch (e) {
      _isLocalActive = false;
      _localServer = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> stopLocalServer() async {
    if (!_isLocalActive) return;
    await _localServer?.close(force: true);
    _localServer = null;
    _isLocalActive = false;
    _clientsMap.clear();
    _speedTimer?.cancel();
    _speedTimer = null;

    // Stop Native Android Service if the internet tunnel is also stopped
    if (!_isInternetActive) {
      try {
        await _channel.invokeMethod('stopWebSharingService');
      } catch (e) {
        debugPrint('Failed to stop native web sharing service: $e');
      }
    }

    notifyListeners();
  }

  // --- Real HTTP File System Router ---
  Future<void> _handleHttpRequest(HttpRequest request, String rootDir) async {
    final response = request.response;
    final uriPath = Uri.decodeComponent(request.uri.path);

    // Security check: prevent directory traversal attacks
    if (uriPath.contains('..')) {
      response.statusCode = HttpStatus.forbidden;
      response.write('403 Forbidden: Directory traversal is prohibited.');
      await response.close();
      return;
    }

    // Map URL path to target local filesystem path
    final targetPath = p.join(rootDir, uriPath.startsWith('/') ? uriPath.substring(1) : uriPath);
    final entityType = FileSystemEntity.typeSync(targetPath);

    if (entityType == FileSystemEntityType.directory) {
      _trackClientActivity(request, targetPath, 0);
      // 1. Serve beautifully designed dark HTML Directory Explorer
      final dir = Directory(targetPath);
      final items = dir.listSync();
      items.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });

      // Detect if accessed via localhost.run tunnel or local network
      final host = request.headers.value(HttpHeaders.hostHeader) ?? '';
      final isInternet = host.contains('lhr.life') || host.contains('localhost.run');

      final html = _generateExplorerHtml(uriPath, items, rootDir, isInternet);
      response.headers.contentType = ContentType.html;
      response.write(html);
      await response.close();
    } else if (entityType == FileSystemEntityType.file) {
      // 2. Stream real file with dynamic high-speed buffering
      final file = File(targetPath);
      final ext = p.extension(targetPath).toLowerCase();

      // Resolve proper MIME Type for browsers to stream video/audio inline
      String contentType = 'application/octet-stream';
      if (['.mp4', '.m4v'].contains(ext)) {
        contentType = 'video/mp4';
      } else if (['.mp3', '.m4a', '.wav'].contains(ext)) {
        contentType = 'audio/mpeg';
      } else if (['.jpg', '.jpeg'].contains(ext)) {
        contentType = 'image/jpeg';
      } else if (['.png', '.gif', '.webp'].contains(ext)) {
        contentType = 'image/png';
      } else if (['.pdf'].contains(ext)) {
        contentType = 'application/pdf';
      } else if (['.txt'].contains(ext)) {
        contentType = 'text/plain; charset=utf-8';
      }

      final fileSize = file.lengthSync();
      final client = _trackClientActivity(request, targetPath, fileSize);
      response.headers.add(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.contentType = ContentType.parse(contentType);

      // Force attachment headers with UTF-8 encoding support for all files to ensure downloading works flawlessly in every browser
      final encodedFilename = Uri.encodeComponent(p.basename(targetPath));
      response.headers.add(
        'Content-Disposition',
        'attachment; filename="$encodedFilename"; filename*=UTF-8\'\'$encodedFilename',
      );

      // Handle HTTP Range Requests for resumable downloading and seeking
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      int start = 0;
      int end = fileSize - 1;
      bool isRange = false;

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        if (parts.isNotEmpty) {
          final startPart = parts[0].trim();
          if (startPart.isNotEmpty) {
            start = int.parse(startPart);
          }
          if (parts.length > 1) {
            final endPart = parts[1].trim();
            if (endPart.isNotEmpty) {
              end = int.parse(endPart);
            }
          }
        }

        if (start >= fileSize || end >= fileSize || start > end) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.add(HttpHeaders.contentRangeHeader, 'bytes */$fileSize');
          await response.close();
          return;
        }

        response.statusCode = HttpStatus.partialContent;
        response.headers.add(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$fileSize');
        response.headers.contentLength = end - start + 1;
        isRange = true;
      } else {
        response.headers.contentLength = fileSize;
      }

      // Stream the file in 64KB blocks for extreme high-speed data transmission
      try {
        final stream = file.openRead(start, isRange ? end + 1 : null);
        await for (final chunk in stream) {
          response.add(chunk);
          if (client != null) {
            client.bytesTransferred += chunk.length;
            client.lastActivityTime = DateTime.now();
          }
        }
      } catch (e) {
        debugPrint('Error streaming file chunk to client: $e');
      } finally {
        await response.close();
      }
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write('404 Not Found: The specified resource does not exist.');
      await response.close();
    }
  }

  // --- Beautiful served Dark HTML Page Builder ---
  String _generateExplorerHtml(String currentPath, List<FileSystemEntity> items, String rootDir, bool isInternet) {
    final title = currentPath == '/' ? 'Root' : p.posix.basename(currentPath);

    // Build breadcrumbs list
    final parts = currentPath.split('/').where((p) => p.isNotEmpty).toList();
    var breadcrumbsHtml = '<a href="/">Root</a>';
    var pathAccumulator = '';
    for (int i = 0; i < parts.length; i++) {
      pathAccumulator += '/${parts[i]}';
      breadcrumbsHtml += ' <span class="arrow">&gt;</span> <a href="$pathAccumulator">${parts[i]}</a>';
    }

    // Build directories list & files lists
    var listHtml = '';
    if (currentPath != '/') {
      // Back button
      final parentPath = p.posix.dirname(currentPath);
      listHtml += '''
        <tr class="item parent" onclick="window.location.href='${parentPath == '.' || parentPath == '' ? '/' : parentPath}'">
          <td>
            <div class="icon-wrapper dir-icon">⏎</div>
          </td>
          <td><strong>.. (Parent Directory)</strong></td>
          <td><span class="meta-val">-</span></td>
          <td><span class="meta-val">-</span></td>
        </tr>
      ''';
    }

    for (final item in items) {
      final name = p.basename(item.path);
      // Skip hidden files
      if (name.startsWith('.')) continue;

      final isDir = item is Directory;
      final relativeUrl = p.posix.join(currentPath, name);

      String sizeStr = '-';
      String dateStr = '-';
      String emoji = '📄';
      String iconClass = 'file-icon';

      if (isDir) {
        emoji = '📁';
        iconClass = 'dir-icon';
      } else {
        final stat = item.statSync();
        final sizeBytes = stat.size;
        dateStr = stat.modified.toString().substring(0, 16);

        if (sizeBytes > 1024 * 1024 * 1024) {
          sizeStr = '${(sizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
        } else if (sizeBytes > 1024 * 1024) {
          sizeStr = '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        } else {
          sizeStr = '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
        }

        final ext = p.extension(item.path).toLowerCase();
        if (['.mp4', '.mkv', '.avi', '.mov'].contains(ext)) {
          emoji = '🎬';
          iconClass = 'video-icon';
        } else if (['.mp3', '.wav', '.flac', '.m4a'].contains(ext)) {
          emoji = '🎵';
          iconClass = 'audio-icon';
        } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
          emoji = '🖼️';
          iconClass = 'image-icon';
        } else if (['.pdf'].contains(ext)) {
          emoji = '📕';
          iconClass = 'pdf-icon';
        }
      }

      listHtml += '''
        <tr class="item" onclick="window.location.href='$relativeUrl'">
          <td>
            <div class="icon-wrapper $iconClass">$emoji</div>
          </td>
          <td><span class="name">$name</span></td>
          <td><span class="meta-val">$sizeStr</span></td>
          <td><span class="meta-val">$dateStr</span></td>
        </tr>
      ''';
    }

    final badgeHtml = isInternet
        ? '<span class="badge cloud">☁ Secure Internet Share</span>'
        : '<span class="badge local">⚡ Local High-Speed Wi-Fi Share</span>';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>NFile Shared Portal - $title</title>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #3B82F6;
      --primary-glow: rgba(59, 130, 246, 0.15);
      --bg: #030712;
      --card: rgba(17, 24, 39, 0.6);
      --text: #F9FAFB;
      --text-muted: #9CA3AF;
      --border: rgba(255, 255, 255, 0.08);
      --hover-row: rgba(255, 255, 255, 0.02);
    }
    body {
      background-color: var(--bg);
      background-image: radial-gradient(circle at 10% 20%, rgba(17, 24, 39, 1) 0%, rgba(3, 7, 18, 1) 90.1%);
      color: var(--text);
      font-family: 'Outfit', sans-serif;
      margin: 0;
      padding: 0;
      min-height: 100vh;
    }
    header {
      background: rgba(3, 7, 18, 0.7);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      padding: 20px 24px;
      border-bottom: 1px solid var(--border);
      position: sticky;
      top: 0;
      z-index: 100;
    }
    .header-content {
      max-width: 1100px;
      margin: 0 auto;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
    }
    .brand-section {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .logo-container {
      background: linear-gradient(135deg, #3B82F6, #1D4ED8);
      width: 40px;
      height: 40px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 14px rgba(59, 130, 246, 0.4);
      font-weight: 800;
      font-size: 20px;
      color: #fff;
    }
    h1 {
      margin: 0;
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -0.5px;
      background: linear-gradient(to right, #F9FAFB, #D1D5DB);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 11.5px;
      font-weight: 700;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
    }
    .badge.local {
      background: linear-gradient(135deg, rgba(16, 185, 129, 0.12), rgba(5, 150, 105, 0.12));
      color: #34D399;
      border: 1px solid rgba(52, 211, 153, 0.25);
      box-shadow: 0 0 15px rgba(52, 211, 153, 0.1);
    }
    .badge.cloud {
      background: linear-gradient(135deg, rgba(59, 130, 246, 0.12), rgba(37, 99, 235, 0.12));
      color: #60A5FA;
      border: 1px solid rgba(96, 165, 250, 0.25);
      box-shadow: 0 0 15px rgba(96, 165, 250, 0.1);
    }
    .container {
      max-width: 1100px;
      margin: 32px auto;
      padding: 0 20px;
      box-sizing: border-box;
    }
    .breadcrumbs {
      background: var(--card);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      padding: 14px 20px;
      border-radius: 16px;
      font-size: 14.5px;
      margin-bottom: 24px;
      border: 1px solid var(--border);
      color: var(--text-muted);
      display: flex;
      align-items: center;
      flex-wrap: wrap;
      gap: 6px;
    }
    .breadcrumbs a {
      color: var(--primary);
      text-decoration: none;
      font-weight: 600;
      transition: color 0.2s ease;
    }
    .breadcrumbs a:hover {
      color: #60A5FA;
    }
    .breadcrumbs .arrow {
      color: rgba(255, 255, 255, 0.2);
    }
    .card {
      background: var(--card);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-radius: 24px;
      border: 1px solid var(--border);
      overflow: hidden;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
    }
    table {
      width: 100%;
      border-collapse: collapse;
      text-align: left;
    }
    th {
      background: rgba(255, 255, 255, 0.02);
      padding: 18px 24px;
      font-size: 12px;
      font-weight: 700;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border);
      text-transform: uppercase;
      letter-spacing: 0.8px;
    }
    td {
      padding: 16px 24px;
      font-size: 15px;
      border-bottom: 1px solid var(--border);
      vertical-align: middle;
    }
    .item {
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .item:hover {
      background-color: var(--hover-row);
    }
    .item:last-child td {
      border-bottom: none;
    }
    .icon-wrapper {
      width: 38px;
      height: 38px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      box-shadow: inset 0 1px 1px rgba(255, 255, 255, 0.08);
    }
    .icon-wrapper.dir-icon {
      background: rgba(16, 185, 129, 0.1);
      border: 1px solid rgba(16, 185, 129, 0.25);
    }
    .icon-wrapper.video-icon {
      background: rgba(59, 130, 246, 0.1);
      border: 1px solid rgba(59, 130, 246, 0.25);
    }
    .icon-wrapper.audio-icon {
      background: rgba(139, 92, 246, 0.1);
      border: 1px solid rgba(139, 92, 246, 0.25);
    }
    .icon-wrapper.image-icon {
      background: rgba(236, 72, 153, 0.1);
      border: 1px solid rgba(236, 72, 153, 0.25);
    }
    .icon-wrapper.pdf-icon {
      background: rgba(239, 68, 68, 0.1);
      border: 1px solid rgba(239, 68, 68, 0.25);
    }
    .icon-wrapper.file-icon {
      background: rgba(156, 163, 175, 0.1);
      border: 1px solid rgba(156, 163, 175, 0.25);
    }
    .name {
      font-weight: 500;
      color: var(--text);
      transition: color 0.15s ease;
    }
    .item:hover .name {
      color: var(--primary);
    }
    .meta-val {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13.5px;
      color: var(--text-muted);
    }
    .parent {
      color: var(--primary);
    }
    footer {
      text-align: center;
      padding: 48px 24px;
      color: var(--text-muted);
      font-size: 12.5px;
      font-weight: 500;
      letter-spacing: 0.3px;
    }
    @media (max-width: 640px) {
      .header-content {
        flex-direction: column;
        align-items: flex-start;
      }
      .badge {
        align-self: flex-start;
      }
      td, th {
        padding: 12px 16px;
      }
      th:nth-child(3), td:nth-child(3), th:nth-child(4), td:nth-child(4) {
        display: none; /* Hide size & modified date on mobile for clean screen */
      }
    }
  </style>
</head>
<body>
  <header>
    <div class="header-content">
      <div class="brand-section">
        <div class="logo-container">N</div>
        <h1>NFile Portal</h1>
      </div>
      $badgeHtml
    </div>
  </header>
  <div class="container">
    <div class="breadcrumbs">$breadcrumbsHtml</div>
    <div class="card">
      <table>
        <thead>
          <tr>
            <th style="width: 50px;"></th>
            <th>Name</th>
            <th style="width: 150px;">Size</th>
            <th style="width: 200px;">Modified</th>
          </tr>
        </thead>
        <tbody>
          $listHtml
        </tbody>
      </table>
    </div>
  </div>
  <footer>
    Securely streaming files via NFile Sharing Server
  </footer>
</body>
</html>
    ''';
  }

  // Detect WiFi Local IP
  Future<String> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && (addr.address.startsWith('192.') || addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
            return addr.address;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  // --- Real Internet Sharing cloud tunnel ---
  Future<void> startInternetTunnel(String rootDir) async {
    if (_isInternetActive) return;

    try {
      // 1. Ensure local HTTP server is running
      if (!_isLocalActive) {
        await startLocalServer(rootDir);
      }

      _isInternetActive = true;
      _internetShareLink = 'Establishing secure proxy tunnel...';
      notifyListeners();

      // Update Foreground Service with tunnel starting text
      try {
        await _channel.invokeMethod('startWebSharingService', {
          'url': 'Establishing secure proxy tunnel...',
          'isInternet': true,
        });
      } catch (e) {
        debugPrint('Failed to start native web sharing service for tunnel: $e');
      }

      // 2. Connect to localhost.run SSH server
      final socket = await SSHSocket.connect('localhost.run', 22, timeout: const Duration(seconds: 15));
      final keys = SSHKeyPair.fromPem(_ed25519PrivateKeyPem);
      _sshClient = SSHClient(
        socket,
        username: 'nokey',
        identities: keys,
      );
      await _sshClient!.authenticated;

      // 3. Request remote port forwarding
      _sshForward = await _sshClient!.forwardRemote(port: 80);
      if (_sshForward == null) {
        throw Exception('Remote port forwarding request denied by proxy server.');
      }

      // 4. Listen to incoming connection stream and pipe it to local HTTP Server (port 8080)
      _sshForward!.connections.listen((connection) async {
        try {
          final localSocket = await Socket.connect('127.0.0.1', _port);
          
          connection.stream.cast<List<int>>().listen(
            (data) => localSocket.add(data),
            onError: (e) {
              localSocket.close();
              connection.sink.close();
            },
            onDone: () {
              localSocket.close();
              connection.sink.close();
            },
          );

          localSocket.listen(
            (data) => connection.sink.add(data),
            onError: (e) {
              localSocket.close();
              connection.sink.close();
            },
            onDone: () {
              localSocket.close();
              connection.sink.close();
            },
          );
        } catch (e) {
          debugPrint('Error routing forwarded connection to local socket: $e');
          connection.sink.close();
        }
      });

      // 5. Start a session to obtain the allocated dynamic domain name from stdout
      final session = await _sshClient!.execute('');
      var stdoutBuffer = '';
      session.stdout.cast<List<int>>().transform(utf8.decoder).listen((data) async {
        debugPrint('Localhost.run Banner: $data');
        stdoutBuffer += data;
        final regExp = RegExp(r'([a-zA-Z0-9.-]+\.(localhost\.run|lhr\.life))');
        final match = regExp.firstMatch(stdoutBuffer);
        if (match != null) {
          final domain = match.group(1)!;
          _internetShareLink = 'https://$domain';
          notifyListeners();

          // Update Foreground Service with real public URL!
          try {
            await _channel.invokeMethod('startWebSharingService', {
              'url': _internetShareLink,
              'isInternet': true,
            });
          } catch (e) {
            debugPrint('Failed to update native web sharing service with link: $e');
          }
        }
      });

      // Start client real traffic speed timer
      _startSpeedTimer();

    } catch (e) {
      debugPrint('Failed to start internet sharing tunnel: $e');
      stopInternetTunnel();
      rethrow;
    }
  }

  void _startSpeedTimer() {
    if (_speedTimer != null) return;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_clientsMap.isEmpty) {
        _speedTimer?.cancel();
        _speedTimer = null;
        return;
      }

      final now = DateTime.now();
      final toRemove = <String>[];

      _clientsMap.forEach((key, client) {
        // Idle timeout: if no active request chunks or connections for 8 seconds, remove the client display
        if (now.difference(client.lastActivityTime).inSeconds > 8) {
          toRemove.add(key);
          return;
        }

        final bytesDiff = client.bytesTransferred - client._lastBytesTransferred;
        client.speed = bytesDiff / (1024 * 1024); // Convert to MB/s
        client._lastBytesTransferred = client.bytesTransferred;
      });

      if (toRemove.isNotEmpty) {
        for (final key in toRemove) {
          _clientsMap.remove(key);
        }
      }

      notifyListeners();
    });
  }

  ActiveClient? _trackClientActivity(HttpRequest request, String targetPath, int fileSize) {
    final userAgent = request.headers.value(HttpHeaders.userAgentHeader) ?? '';
    if (userAgent.isEmpty) return null;

    final uaLower = userAgent.toLowerCase();
    if (!uaLower.contains('mozilla') ||
        uaLower.contains('bot') ||
        uaLower.contains('crawler') ||
        uaLower.contains('spider') ||
        uaLower.contains('curl') ||
        uaLower.contains('wget') ||
        uaLower.contains('go-http') ||
        uaLower.contains('python') ||
        uaLower.contains('http-client') ||
        uaLower.contains('ping') ||
        uaLower.contains('probe') ||
        uaLower.contains('scan')) {
      return null;
    }

    final ip = request.connectionInfo?.remoteAddress.address ?? 'Unknown';
    final clientKey = '${ip}_$userAgent';

    final device = _parseUserAgent(userAgent);
    final fileName = FileSystemEntity.isDirectorySync(targetPath) ? 'Browsing Directories' : p.basename(targetPath);

    final client = _clientsMap.putIfAbsent(clientKey, () => ActiveClient(
      ip: ip,
      userAgent: userAgent,
      device: device,
      currentFile: fileName,
      totalBytes: fileSize,
    ));

    client.currentFile = fileName;
    client.totalBytes = fileSize;
    client.lastActivityTime = DateTime.now();

    _startSpeedTimer();
    notifyListeners();
    return client;
  }

  String _parseUserAgent(String ua) {
    if (ua.isEmpty) return 'Web Browser';

    final uaLower = ua.toLowerCase();
    String browser = 'Browser';
    if (uaLower.contains('chrome')) {
      browser = 'Chrome';
    } else if (uaLower.contains('safari') && !uaLower.contains('chrome')) {
      browser = 'Safari';
    } else if (uaLower.contains('firefox')) {
      browser = 'Firefox';
    } else if (uaLower.contains('edge') || uaLower.contains('edg')) {
      browser = 'Edge';
    } else if (uaLower.contains('opera') || uaLower.contains('opr')) {
      browser = 'Opera';
    }

    String os = 'Web';
    if (uaLower.contains('windows')) {
      os = 'Windows';
    } else if (uaLower.contains('macintosh') || uaLower.contains('mac os')) {
      os = 'macOS';
    } else if (uaLower.contains('iphone') || uaLower.contains('ipad')) {
      os = 'iOS';
    } else if (uaLower.contains('android')) {
      os = 'Android';
    } else if (uaLower.contains('linux')) {
      os = 'Linux';
    }

    return '$browser on $os';
  }

  void stopInternetTunnel() {
    if (!_isInternetActive) return;
    _speedTimer?.cancel();
    _speedTimer = null;
    _sshForward = null;
    _sshClient?.close();
    _sshClient = null;
    _isInternetActive = false;
    _internetShareLink = '';
    _clientsMap.clear();

    // Manage Native Android Background Service Reversion
    try {
      if (_isLocalActive) {
        _channel.invokeMethod('startWebSharingService', {
          'url': 'http://$_localIpAddress:$_port',
          'isInternet': false,
        });
      } else {
        _channel.invokeMethod('stopWebSharingService');
      }
    } catch (e) {
      debugPrint('Failed to manage native service on tunnel stop: $e');
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _sshClient?.close();
    _localServer?.close(force: true);
    super.dispose();
  }
}

class ActiveClient {
  final String ip;
  final String userAgent;
  final String device;
  String currentFile;
  int bytesTransferred = 0;
  int totalBytes = 0;
  DateTime lastActivityTime;
  double speed = 0.0; // MB/s
  int _lastBytesTransferred = 0;

  ActiveClient({
    required this.ip,
    required this.userAgent,
    required this.device,
    required this.currentFile,
    required this.totalBytes,
  }) : lastActivityTime = DateTime.now();
}
