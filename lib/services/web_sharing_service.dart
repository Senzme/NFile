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

    // Handle high-speed file uploads via binary stream piping
    if (request.method == 'POST') {
      final fileNameHeader = request.headers.value('x-file-name');
      if (fileNameHeader != null) {
        try {
          final decodedFileName = Uri.decodeComponent(fileNameHeader);
          final uploadDestination = FileSystemEntity.isDirectorySync(targetPath) 
              ? p.join(targetPath, decodedFileName) 
              : p.join(p.dirname(targetPath), decodedFileName);

          // Verify destination path safety to prevent directory traversal
          if (!p.normalize(uploadDestination).startsWith(p.normalize(rootDir))) {
            response.statusCode = HttpStatus.forbidden;
            response.write('403 Forbidden: Invalid file upload destination.');
            await response.close();
            return;
          }

          final file = File(uploadDestination);
          final sink = file.openWrite();
          await request.cast<List<int>>().pipe(sink);

          response.statusCode = HttpStatus.ok;
          response.write('Upload successful');
          await response.close();
          return;
        } catch (e) {
          response.statusCode = HttpStatus.internalServerError;
          response.write('500 Upload failed: $e');
          await response.close();
          return;
        }
      }
    }

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

    // Standard high-fidelity SVGs to avoid emojis and offer a premium, modern layout
    const folderSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"></path></svg>';
    const videoSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="23 7 16 12 23 17 23 7"></polygon><rect x="1" y="5" width="15" height="14" rx="2" ry="2"></rect></svg>';
    const audioSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>';
    const imageSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></svg>';
    const pdfSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line></svg>';
    const fileSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"></path><polyline points="13 2 13 9 20 9"></polyline></svg>';
    const backSvg = '<svg class="svg-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 14 4 9 9 4"></polyline><path d="M20 20v-7a4 4 0 0 0-4-4H4"></path></svg>';
    const downloadSvg = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>';

    if (currentPath != '/') {
      final parentPath = p.posix.dirname(currentPath);
      final parentUrl = parentPath == '.' || parentPath == '' ? '/' : parentPath;
      listHtml += '''
        <div class="explorer-item parent-dir" onclick="window.location.href='$parentUrl'">
          <div class="item-icon-wrapper dir-icon">$backSvg</div>
          <div class="item-details">
            <div class="item-name">.. (Parent Directory)</div>
            <div class="item-meta">Go up one level</div>
          </div>
        </div>
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
      String iconClass = 'file-icon';
      String mimeType = 'application/octet-stream';
      String svgIcon = '';

      if (isDir) {
        iconClass = 'dir-icon';
        svgIcon = folderSvg;
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
          iconClass = 'video-icon';
          mimeType = 'video/mp4';
          svgIcon = videoSvg;
        } else if (['.mp3', '.wav', '.flac', '.m4a'].contains(ext)) {
          iconClass = 'audio-icon';
          mimeType = 'audio/mpeg';
          svgIcon = audioSvg;
        } else if (['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext)) {
          iconClass = 'image-icon';
          mimeType = 'image/png';
          svgIcon = imageSvg;
        } else if (['.pdf'].contains(ext)) {
          iconClass = 'pdf-icon';
          mimeType = 'application/pdf';
          svgIcon = pdfSvg;
        } else {
          iconClass = 'file-icon';
          svgIcon = fileSvg;
        }
      }

      if (isDir) {
        // Folders render completely clean without copy button, action overlays, size or dates
        listHtml += '''
        <div class="explorer-item folder-item" data-name="${name.replaceAll('"', '&quot;')}" data-type="directory" data-url="$relativeUrl" onclick="handleItemClick(this)">
          <div class="item-icon-wrapper dir-icon">$svgIcon</div>
          <div class="item-details">
            <div class="item-name" title="${name.replaceAll('"', '&quot;')}">$name</div>
          </div>
        </div>
        ''';
      } else {
        // Files render with clean hover download actions and explicit item metadata details
        final actionsHtml = '''
          <div class="item-actions">
            <button class="action-btn download-btn" onclick="downloadFile('$relativeUrl', '${name.replaceAll("'", "\\'")}', event)" title="Download File">
              $downloadSvg
            </button>
          </div>
        ''';

        listHtml += '''
        <div class="explorer-item file-item" data-name="${name.replaceAll('"', '&quot;')}" data-type="file" data-url="$relativeUrl" data-size="$sizeStr" data-modified="$dateStr" data-mime="$mimeType" onclick="handleItemClick(this)">
          <div class="item-icon-wrapper $iconClass">$svgIcon</div>
          <div class="item-details">
            <div class="item-name" title="${name.replaceAll('"', '&quot;')}">$name</div>
            <div class="item-meta">
              <span class="item-size">$sizeStr</span>
              <span class="item-sep">•</span>
              <span class="item-date">$dateStr</span>
            </div>
          </div>
          $actionsHtml
        </div>
        ''';
      }
    }

    final badgeHtml = '''
      <div class="header-actions">
        <span class="status-indicator ${isInternet ? 'cloud' : 'local'}" title="${isInternet ? 'Secure Internet Share' : 'Local High-Speed Wi-Fi Share'}"></span>
        <button class="header-upload-btn" onclick="triggerFileInput()" title="Upload Files to this Folder">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line></svg>
          <span>Upload</span>
        </button>
      </div>
    ''';

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
      --primary-rgb: 59, 130, 246;
      --primary-hover: #60A5FA;
      --bg: #090d16;
      --card: rgba(17, 24, 39, 0.45);
      --card-hover: rgba(30, 41, 59, 0.7);
      --text: #F3F4F6;
      --text-muted: #9CA3AF;
      --border: rgba(255, 255, 255, 0.06);
      --border-hover: rgba(59, 130, 246, 0.35);
      --hover-row: rgba(255, 255, 255, 0.03);

      /* Accent colors for file categories */
      --dir-color: #10B981;
      --video-color: #3B82F6;
      --audio-color: #8B5CF6;
      --image-color: #EC4899;
      --pdf-color: #EF4444;
      --file-color: #6B7280;
    }
    body {
      background-color: var(--bg);
      background-image: 
        radial-gradient(circle at 0% 0%, rgba(59, 130, 246, 0.06) 0%, transparent 40%),
        radial-gradient(circle at 100% 100%, rgba(139, 92, 246, 0.05) 0%, transparent 40%);
      background-attachment: fixed;
      color: var(--text);
      font-family: 'Outfit', sans-serif;
      margin: 0;
      padding: 0;
      min-height: 100vh;
      overflow-x: hidden;
    }
    header {
      background: rgba(9, 13, 22, 0.75);
      backdrop-filter: blur(20px);
      -webkit-backdrop-filter: blur(20px);
      padding: 16px 24px;
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
      width: 36px;
      height: 36px;
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 14px rgba(59, 130, 246, 0.3);
      font-weight: 800;
      font-size: 18px;
      color: #fff;
    }
    h1 {
      margin: 0;
      font-size: 20px;
      font-weight: 700;
      letter-spacing: -0.5px;
      background: linear-gradient(to right, #F9FAFB, #D1D5DB);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .header-actions {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .status-indicator {
      width: 9px;
      height: 9px;
      border-radius: 50%;
      position: relative;
      display: inline-block;
    }
    .status-indicator.local {
      background: #34D399;
      box-shadow: 0 0 10px #34D399, 0 0 4px #34D399;
    }
    .status-indicator.cloud {
      background: #60A5FA;
      box-shadow: 0 0 10px #60A5FA, 0 0 4px #60A5FA;
    }
    .status-indicator::after {
      content: "";
      position: absolute;
      top: -2px;
      left: -2px;
      right: -2px;
      bottom: -2px;
      border-radius: 50%;
      border: 1.5px solid transparent;
      animation: statusPulse 2.2s infinite ease-in-out;
    }
    .status-indicator.local::after {
      border-color: rgba(52, 211, 153, 0.45);
    }
    .status-indicator.cloud::after {
      border-color: rgba(96, 165, 250, 0.45);
    }
    @keyframes statusPulse {
      0% { transform: scale(1); opacity: 1; }
      100% { transform: scale(1.6); opacity: 0; }
    }
    .header-upload-btn {
      background: var(--primary);
      border: 1px solid rgba(59, 130, 246, 0.2);
      color: #fff;
      padding: 7px 14px;
      font-size: 12.5px;
      font-weight: 600;
      border-radius: 10px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
      transition: all 0.2s ease;
      font-family: inherit;
    }
    .header-upload-btn:hover {
      background: var(--primary-hover);
      box-shadow: 0 4px 16px rgba(59, 130, 246, 0.45);
      transform: translateY(-1px);
    }
    .header-upload-btn svg {
      width: 14px;
      height: 14px;
    }
    .container {
      max-width: 1100px;
      margin: 24px auto;
      padding: 0 20px;
      box-sizing: border-box;
    }
    .breadcrumbs {
      background: var(--card);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      padding: 12px 18px;
      border-radius: 14px;
      font-size: 14px;
      margin-bottom: 20px;
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
      color: var(--primary-hover);
    }
    .breadcrumbs .arrow {
      color: rgba(255, 255, 255, 0.15);
    }

    /* Modern Toolbar styling */
    .toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      margin-bottom: 20px;
    }
    .search-wrapper {
      position: relative;
      flex: 1;
      max-width: 400px;
    }
    .search-input {
      width: 100%;
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 12px 16px 12px 42px;
      color: var(--text);
      font-family: inherit;
      font-size: 14.5px;
      box-sizing: border-box;
      transition: all 0.2s ease;
    }
    .search-input:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
      background: rgba(17, 24, 39, 0.7);
    }
    .search-icon {
      position: absolute;
      left: 14px;
      top: 50%;
      transform: translateY(-50%);
      width: 18px;
      height: 18px;
      color: var(--text-muted);
      pointer-events: none;
    }
    .toolbar-controls {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .view-toggles {
      display: flex;
      background: var(--card);
      border: 1px solid var(--border);
      padding: 4px;
      border-radius: 12px;
      gap: 4px;
    }
    .toggle-btn {
      background: transparent;
      border: none;
      color: var(--text-muted);
      padding: 8px;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.2s ease;
    }
    .toggle-btn svg {
      width: 18px;
      height: 18px;
      stroke-width: 2.2;
    }
    .toggle-btn:hover {
      color: var(--text);
      background: rgba(255, 255, 255, 0.03);
    }
    .toggle-btn.active {
      color: #fff;
      background: var(--primary);
      box-shadow: 0 2px 8px rgba(59, 130, 246, 0.35);
    }

    /* Core Catalog Grid / List */
    .items-container {
      transition: all 0.3s ease;
    }

    /* Explorer Item Styling */
    .explorer-item {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 16px;
      cursor: pointer;
      display: flex;
      position: relative;
      overflow: hidden;
      box-sizing: border-box;
      transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .explorer-item:hover {
      background: var(--card-hover);
      border-color: var(--border-hover);
      transform: translateY(-2px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.25);
    }
    .item-icon-wrapper {
      display: flex;
      align-items: center;
      justify-content: center;
      border-radius: 12px;
      transition: all 0.2s ease;
    }
    .item-icon-wrapper svg {
      width: 50%;
      height: 50%;
      transition: transform 0.2s ease;
    }
    .explorer-item:hover .item-icon-wrapper svg {
      transform: scale(1.08);
    }

    /* Categorized Accent Styling */
    .dir-icon {
      background: rgba(16, 185, 129, 0.08);
      border: 1px solid rgba(16, 185, 129, 0.15);
      color: var(--dir-color);
    }
    .video-icon {
      background: rgba(59, 130, 246, 0.08);
      border: 1px solid rgba(59, 130, 246, 0.15);
      color: var(--video-color);
    }
    .audio-icon {
      background: rgba(139, 92, 246, 0.08);
      border: 1px solid rgba(139, 92, 246, 0.15);
      color: var(--audio-color);
    }
    .image-icon {
      background: rgba(236, 72, 153, 0.08);
      border: 1px solid rgba(236, 72, 153, 0.15);
      color: var(--image-color);
    }
    .pdf-icon {
      background: rgba(239, 68, 68, 0.08);
      border: 1px solid rgba(239, 68, 68, 0.15);
      color: var(--pdf-color);
    }
    .file-icon {
      background: rgba(107, 114, 128, 0.08);
      border: 1px solid rgba(107, 114, 128, 0.15);
      color: var(--file-color);
    }

    .item-details {
      min-width: 0; /* Prevents overflow */
    }
    .item-name {
      font-weight: 600;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      font-size: 14.5px;
      transition: color 0.15s ease;
    }
    .explorer-item:hover .item-name {
      color: var(--primary-hover);
    }
    .item-meta {
      font-size: 12px;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      gap: 6px;
      margin-top: 4px;
    }
    .item-size {
      font-family: 'JetBrains Mono', monospace;
    }
    .item-date {
      font-family: 'JetBrains Mono', monospace;
    }
    .item-sep {
      opacity: 0.4;
    }

    /* Actions buttons */
    .item-actions {
      display: flex;
      align-items: center;
      gap: 6px;
      opacity: 0;
      transition: opacity 0.2s ease;
    }
    .explorer-item:hover .item-actions {
      opacity: 1;
    }
    .action-btn {
      background: rgba(255, 255, 255, 0.04);
      border: 1px solid var(--border);
      color: var(--text-muted);
      width: 32px;
      height: 32px;
      border-radius: 8px;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s ease;
    }
    .action-btn svg {
      width: 14px;
      height: 14px;
    }
    .action-btn:hover {
      color: #fff;
      background: var(--primary);
      border-color: var(--primary);
      box-shadow: 0 0 10px rgba(59, 130, 246, 0.4);
    }

    /* Grid Layout View Mode */
    .items-container.grid-mode {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
      gap: 16px;
    }
    .items-container.grid-mode .explorer-item {
      flex-direction: column;
      align-items: center;
      text-align: center;
      padding: 24px 16px 16px 16px;
    }
    .items-container.grid-mode .item-icon-wrapper {
      width: 64px;
      height: 64px;
      margin-bottom: 12px;
    }
    .items-container.grid-mode .item-icon-wrapper svg {
      width: 28px;
      height: 28px;
    }
    .items-container.grid-mode .item-details {
      width: 100%;
    }
    .items-container.grid-mode .item-meta {
      justify-content: center;
      margin-top: 6px;
    }
    .items-container.grid-mode .item-actions {
      margin-top: 14px;
      opacity: 0.3; /* Show slightly on grid for mobile compatibility */
    }
    .items-container.grid-mode .explorer-item:hover .item-actions {
      opacity: 1;
    }

    /* List Layout View Mode */
    .items-container.list-mode {
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .items-container.list-mode .explorer-item {
      flex-direction: row;
      align-items: center;
      padding: 10px 16px;
    }
    .items-container.list-mode .item-icon-wrapper {
      width: 36px;
      height: 36px;
      flex-shrink: 0;
    }
    .items-container.list-mode .item-icon-wrapper svg {
      width: 18px;
      height: 18px;
    }
    .items-container.list-mode .item-details {
      flex: 1;
      margin-left: 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
    }
    .items-container.list-mode .item-name {
      flex: 2;
      text-align: left;
    }
    .items-container.list-mode .item-meta {
      flex: 3;
      margin-top: 0;
      justify-content: flex-end;
      gap: 16px;
    }
    .items-container.list-mode .item-actions {
      margin-left: 16px;
      flex-shrink: 0;
    }

    /* Clean representation modifications for folder items in Grid/List views */
    .explorer-item.folder-item {
      padding: 20px 16px !important;
    }
    .items-container.grid-mode .explorer-item.folder-item {
      padding: 24px 16px !important;
    }
    .items-container.list-mode .explorer-item.folder-item .item-details {
      justify-content: flex-start;
    }

    /* Empty Search State */
    .empty-state {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 64px 20px;
      text-align: center;
      border: 1px dashed var(--border);
      border-radius: 20px;
      background: var(--card);
      margin-top: 24px;
    }
    .empty-icon {
      font-size: 32px;
      margin-bottom: 12px;
      opacity: 0.6;
    }
    .empty-state h3 {
      margin: 0 0 6px 0;
      font-weight: 600;
      color: var(--text);
    }
    .empty-state p {
      margin: 0;
      font-size: 13.5px;
      color: var(--text-muted);
    }

    /* Floating Blurred Glass Preview Modal */
    .modal-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(3, 7, 18, 0.45);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      z-index: 1000;
      opacity: 0;
      pointer-events: none;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
      box-sizing: border-box;
      transition: opacity 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    }
    .modal-overlay.active {
      opacity: 1;
      pointer-events: auto;
    }
    .modal-card {
      background: rgba(15, 23, 42, 0.7);
      border: 1px solid rgba(255, 255, 255, 0.1);
      backdrop-filter: blur(30px);
      -webkit-backdrop-filter: blur(30px);
      border-radius: 24px;
      width: 100%;
      max-width: 720px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.6);
      transform: scale(0.95) translateY(10px);
      transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
      display: flex;
      flex-direction: column;
      max-height: 85vh;
      position: relative;
      overflow: hidden;
    }
    .modal-overlay.active .modal-card {
      transform: scale(1) translateY(0);
    }
    .modal-close {
      position: absolute;
      top: 18px;
      right: 18px;
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid rgba(255, 255, 255, 0.08);
      color: var(--text-muted);
      width: 32px;
      height: 32px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s ease;
      z-index: 10;
    }
    .modal-close:hover {
      background: rgba(239, 68, 68, 0.2);
      color: #EF4444;
      border-color: rgba(239, 68, 68, 0.3);
      transform: rotate(90deg);
    }
    .modal-close svg {
      width: 14px;
      height: 14px;
    }
    .modal-header {
      padding: 24px;
      display: flex;
      align-items: center;
      gap: 16px;
      border-bottom: 1px solid var(--border);
    }
    .modal-icon-wrapper {
      width: 44px;
      height: 44px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .modal-icon-wrapper svg {
      width: 20px;
      height: 20px;
    }
    .modal-title-wrapper {
      min-width: 0;
    }
    .modal-title-wrapper h3 {
      margin: 0;
      font-size: 17px;
      font-weight: 700;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .modal-title-wrapper p {
      margin: 4px 0 0 0;
      font-size: 12.5px;
      color: var(--text-muted);
    }
    .modal-body {
      flex: 1;
      padding: 24px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: rgba(0, 0, 0, 0.2);
      min-height: 260px;
    }
    .modal-footer {
      padding: 16px 24px;
      border-top: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: flex-end;
      gap: 12px;
      background: rgba(15, 23, 42, 0.4);
    }
    
    /* Interactive Preview Media Styling */
    .video-container {
      width: 100%;
      border-radius: 14px;
      overflow: hidden;
      background: #000;
      border: 1px solid var(--border);
      box-shadow: 0 8px 24px rgba(0,0,0,0.5);
    }
    .preview-video {
      width: 100%;
      max-height: 45vh;
      display: block;
      outline: none;
    }
    .image-container {
      max-width: 100%;
      max-height: 45vh;
      border-radius: 14px;
      overflow: hidden;
      border: 1px solid var(--border);
      box-shadow: 0 8px 24px rgba(0,0,0,0.4);
    }
    .preview-image {
      max-width: 100%;
      max-height: 45vh;
      object-fit: contain;
      display: block;
    }
    .preview-pdf {
      width: 100%;
      height: 45vh;
      border: 1px solid var(--border);
      border-radius: 14px;
      background: #fff;
    }

    /* Ambient Audio Streaming layout */
    .audio-container {
      width: 100%;
      padding: 40px 24px;
      border-radius: 16px;
      background: radial-gradient(circle at center, rgba(139, 92, 246, 0.12) 0%, rgba(9, 13, 22, 0.4) 100%);
      border: 1px solid rgba(139, 92, 246, 0.2);
      box-sizing: border-box;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 24px;
      position: relative;
    }
    .audio-art-disc {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      background: linear-gradient(135deg, #8B5CF6, #6D28D9);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      box-shadow: 0 0 24px rgba(139, 92, 246, 0.45);
      animation: pulseGlow 2.5s infinite alternate;
    }
    @keyframes pulseGlow {
      0% {
        box-shadow: 0 0 15px rgba(139, 92, 246, 0.3);
        transform: scale(0.98);
      }
      100% {
        box-shadow: 0 0 35px rgba(139, 92, 246, 0.6);
        transform: scale(1.02);
      }
    }
    .preview-audio {
      width: 100%;
      max-width: 450px;
      outline: none;
    }

    /* Scrollable Code/Text preview */
    .preview-text {
      width: 100%;
      max-height: 45vh;
      background: #05070c;
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 16px;
      margin: 0;
      overflow: auto;
      box-sizing: border-box;
      text-align: left;
    }
    .preview-text code {
      font-family: 'JetBrains Mono', monospace;
      font-size: 13px;
      color: #E5E7EB;
      line-height: 1.5;
    }
    .preview-text-loading {
      color: var(--text-muted);
      font-size: 14px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .preview-text-loading::after {
      content: "";
      width: 14px;
      height: 14px;
      border: 2px solid var(--primary);
      border-right-color: transparent;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .preview-text-error {
      color: #EF4444;
      font-size: 14px;
    }

    /* Fallback generic file UI */
    .generic-container {
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 12px;
      padding: 32px;
    }
    .generic-preview-icon {
      width: 72px;
      height: 72px;
      border-radius: 20px;
      background: rgba(255,255,255,0.03);
      border: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--text-muted);
    }
    .generic-preview-icon svg {
      width: 32px;
      height: 32px;
    }
    .generic-preview-text {
      margin: 0;
      font-weight: 600;
      color: var(--text);
      font-size: 15px;
    }
    .generic-preview-subtext {
      margin: 0;
      color: var(--text-muted);
      font-size: 13px;
    }

    /* Modal premium Buttons */
    .btn {
      display: inline-flex;
      align-items: center;
      padding: 10px 18px;
      font-size: 13.5px;
      font-weight: 600;
      border-radius: 10px;
      cursor: pointer;
      text-decoration: none;
      font-family: inherit;
      transition: all 0.2s ease;
    }
    .btn-secondary {
      background: rgba(255, 255, 255, 0.05);
      border: 1px solid var(--border);
      color: var(--text);
    }
    .btn-secondary:hover {
      background: rgba(255, 255, 255, 0.09);
      border-color: rgba(255, 255, 255, 0.15);
    }
    .btn-primary {
      background: var(--primary);
      border: 1px solid rgba(59, 130, 246, 0.2);
      color: #fff;
      box-shadow: 0 4px 14px rgba(59, 130, 246, 0.35);
    }
    .btn-primary:hover {
      background: var(--primary-hover);
      box-shadow: 0 4px 20px rgba(59, 130, 246, 0.5);
      transform: translateY(-1px);
    }

    /* Premium upload progress overlay */
    .upload-progress-overlay {
      position: fixed;
      bottom: 24px;
      right: 24px;
      z-index: 1500;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.3s ease;
    }
    .upload-progress-overlay.active {
      opacity: 1;
      pointer-events: auto;
    }
    .upload-progress-card {
      background: rgba(15, 23, 42, 0.85);
      border: 1px solid rgba(59, 130, 246, 0.3);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      padding: 16px 20px;
      border-radius: 16px;
      width: 320px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.5);
    }
    .upload-progress-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
      font-size: 13.5px;
      font-weight: 600;
    }
    .upload-title {
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 220px;
    }
    .upload-percent {
      color: var(--primary);
    }
    .progress-bar-container {
      width: 100%;
      height: 6px;
      background: rgba(255, 255, 255, 0.08);
      border-radius: 3px;
      overflow: hidden;
    }
    .progress-bar-fill {
      height: 100%;
      width: 0%;
      background: linear-gradient(to right, #3B82F6, #60A5FA);
      border-radius: 3px;
      transition: width 0.1s ease;
      box-shadow: 0 0 8px rgba(59, 130, 246, 0.5);
    }

    /* Dynamic full screen Drag Over Upload Indicator Overlay */
    .drag-overlay {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(9, 13, 22, 0.8);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      z-index: 2500;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      opacity: 0;
      pointer-events: none;
      transition: opacity 0.25s ease;
      border: 3px dashed var(--primary);
      margin: 12px;
      border-radius: 20px;
    }
    .drag-overlay.active {
      opacity: 1;
      pointer-events: auto;
    }
    .drag-overlay-icon {
      width: 80px;
      height: 80px;
      background: rgba(59, 130, 246, 0.1);
      border: 1px solid rgba(59, 130, 246, 0.3);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      color: var(--primary);
      margin-bottom: 20px;
      box-shadow: 0 0 40px rgba(59, 130, 246, 0.2);
    }
    .drag-overlay-icon svg {
      width: 36px;
      height: 36px;
    }
    .drag-overlay h2 {
      margin: 0 0 8px 0;
      font-weight: 700;
      color: #fff;
    }
    .drag-overlay p {
      margin: 0;
      color: var(--text-muted);
      font-size: 14.5px;
    }

    /* Premium dynamic Toast Notification */
    .toast-notification {
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%) translateY(20px);
      background: rgba(17, 24, 39, 0.85);
      border: 1px solid rgba(59, 130, 246, 0.35);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      padding: 12px 24px;
      border-radius: 12px;
      font-weight: 600;
      font-size: 13.5px;
      color: #fff;
      display: flex;
      align-items: center;
      gap: 8px;
      box-shadow: 0 10px 25px rgba(0, 0, 0, 0.5);
      opacity: 0;
      pointer-events: none;
      z-index: 2000;
      transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
    }
    .toast-notification.active {
      transform: translateX(-50%) translateY(0);
      opacity: 1;
    }
    .toast-notification::before {
      content: "✓";
      color: #34D399;
      font-weight: 800;
      font-size: 15px;
    }

    footer {
      text-align: center;
      padding: 40px 24px;
      color: var(--text-muted);
      font-size: 12.5px;
      font-weight: 500;
      letter-spacing: 0.3px;
      border-top: 1px solid rgba(255, 255, 255, 0.03);
      max-width: 1100px;
      margin: 40px auto 0 auto;
    }

    /* Mobile Responsive Optimizations */
    @media (max-width: 640px) {
      .header-content {
        flex-direction: column;
        align-items: flex-start;
      }
      .header-actions {
        align-self: flex-start;
      }
      .toolbar {
        flex-direction: column;
        align-items: stretch;
      }
      .search-wrapper {
        max-width: 100%;
      }
      .toolbar-controls {
        justify-content: space-between;
        margin-top: 4px;
      }
      .items-container.list-mode .item-meta {
        display: none; /* Hide date/size in compressed compact list on mobile */
      }
      .items-container.list-mode .item-actions {
        opacity: 1; /* Keep buttons visible on touch devices */
      }
      .explorer-item {
        padding: 14px !important;
      }
      .modal-card {
        max-height: 90vh;
      }
      .modal-body {
        padding: 16px;
      }
      .modal-footer {
        flex-direction: column-reverse;
        align-items: stretch;
      }
      .modal-footer .btn {
        justify-content: center;
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
    
    <div class="toolbar">
      <div class="search-wrapper">
        <svg class="search-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
        <input type="text" id="searchInput" class="search-input" placeholder="Search files & folders...">
      </div>
      
      <div class="view-toggles">
        <button class="toggle-btn" id="viewToggleList" onclick="setViewMode('list')" title="List View">
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg>
        </button>
        <button class="toggle-btn" id="viewToggleGrid" onclick="setViewMode('grid')" title="Grid View">
          <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>
        </button>
      </div>
    </div>
    
    <div class="items-container grid-mode" id="itemsContainer">
      $listHtml
    </div>

    <div class="empty-state" id="emptyState" style="display: none;">
      <div class="empty-icon">🔍</div>
      <h3>No items match your search</h3>
      <p>Check the spelling or try a different search term.</p>
    </div>
  </div>

  <!-- Floating Preview Drawer Modal -->
  <div class="modal-overlay" id="previewModal" onclick="closeModal(event)">
    <div class="modal-card" onclick="event.stopPropagation()">
      <button class="modal-close" onclick="closeModal(event)" title="Close Modal">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>
      
      <div class="modal-header">
        <div class="modal-icon-wrapper" id="modalIcon"></div>
        <div class="modal-title-wrapper">
          <h3 id="modalTitle">File Name</h3>
          <p id="modalMeta">Size • Modified Date</p>
        </div>
      </div>
      
      <div class="modal-body" id="modalBody">
        <!-- Preview filled dynamically -->
      </div>
      
      <div class="modal-footer">
        <button class="btn btn-secondary" id="modalCopyBtn" onclick="copyModalLink()">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:14px; height:14px; margin-right:8px;"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
          Copy Link
        </button>
        <a class="btn btn-primary" id="modalDownloadBtn" href="" download>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="width:14px; height:14px; margin-right:8px;"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
          Download
        </a>
      </div>
    </div>
  </div>

  <!-- Hidden File Input for high-speed selector upload -->
  <input type="file" id="fileInputElement" multiple style="display: none;" onchange="handleFileSelection(this)">

  <!-- Floating Drag & Drop Fullscreen Overlay -->
  <div class="drag-overlay" id="dragOverlay">
    <div class="drag-overlay-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="17 8 12 3 7 8"></polyline><line x1="12" y1="3" x2="12" y2="15"></line></svg>
    </div>
    <h2>Drop files here to upload</h2>
    <p>Your files will be uploaded instantly to this shared folder</p>
  </div>

  <!-- Floating Progress indicator card -->
  <div class="upload-progress-overlay" id="uploadOverlay">
    <div class="upload-progress-card">
      <div class="upload-progress-header">
        <span class="upload-title" id="uploadTitle">Uploading file...</span>
        <span class="upload-percent" id="uploadPercent">0%</span>
      </div>
      <div class="progress-bar-container">
        <div class="progress-bar-fill" id="uploadBar"></div>
      </div>
    </div>
  </div>

  <footer>
    Securely sharing and streaming files via NFile Server
  </footer>

  <script>
    // Search Filtering logic
    const searchInput = document.getElementById('searchInput');
    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.toLowerCase().trim();
      const items = document.querySelectorAll('.explorer-item:not(.parent-dir)');
      let visibleCount = 0;
      
      items.forEach(item => {
        const name = item.getAttribute('data-name').toLowerCase();
        if (name.includes(query)) {
          item.style.display = '';
          visibleCount++;
        } else {
          item.style.display = 'none';
        }
      });
      
      const emptyState = document.getElementById('emptyState');
      if (visibleCount === 0 && items.length > 0) {
        emptyState.style.display = 'flex';
      } else {
        emptyState.style.display = 'none';
      }
    });

    // List vs Grid View Toggle logic
    const viewToggleList = document.getElementById('viewToggleList');
    const viewToggleGrid = document.getElementById('viewToggleGrid');
    const itemsContainer = document.getElementById('itemsContainer');

    function setViewMode(mode) {
      if (mode === 'grid') {
        itemsContainer.classList.remove('list-mode');
        itemsContainer.classList.add('grid-mode');
        viewToggleGrid.classList.add('active');
        viewToggleList.classList.remove('active');
      } else {
        itemsContainer.classList.remove('grid-mode');
        itemsContainer.classList.add('list-mode');
        viewToggleList.classList.add('active');
        viewToggleGrid.classList.remove('active');
      }
      localStorage.setItem('nfile-view-mode', mode);
    }

    // Default view is list
    const savedMode = localStorage.getItem('nfile-view-mode') || 'list';
    setViewMode(savedMode);

    // File Upload triggering and selection
    function triggerFileInput() {
      document.getElementById('fileInputElement').click();
    }

    async function handleFileSelection(input) {
      const files = input.files;
      if (files.length === 0) return;
      
      const overlay = document.getElementById('uploadOverlay');
      const title = document.getElementById('uploadTitle');
      const percent = document.getElementById('uploadPercent');
      const bar = document.getElementById('uploadBar');
      
      overlay.classList.add('active');
      
      for (let i = 0; i < files.length; i++) {
        const file = files[i];
        title.textContent = `Uploading \${file.name}...`;
        percent.textContent = '0%';
        bar.style.width = '0%';
        
        try {
          await uploadSingleFile(file, (p) => {
            percent.textContent = `\${p}%`;
            bar.style.width = `\${p}%`;
          });
        } catch (err) {
          showToast(`Failed to upload \${file.name}`);
          console.error(err);
        }
      }
      
      overlay.classList.remove('active');
      showToast("Upload completed successfully!");
      setTimeout(() => {
        window.location.reload();
      }, 800);
    }

    function uploadSingleFile(file, onProgress) {
      return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open('POST', window.location.pathname, true);
        xhr.setRequestHeader('x-file-name', encodeURIComponent(file.name));
        
        xhr.upload.onprogress = (e) => {
          if (e.lengthComputable) {
            const p = Math.round((e.loaded / e.total) * 100);
            onProgress(p);
          }
        };
        
        xhr.onload = () => {
          if (xhr.status >= 200 && xhr.status < 300) {
            resolve();
          } else {
            reject(new Error(xhr.responseText || 'Upload failed'));
          }
        };
        
        xhr.onerror = () => reject(new Error('Network error'));
        xhr.send(file);
      });
    }

    // Drag & Drop event bindings
    const dragOverlay = document.getElementById('dragOverlay');
    let dragCounter = 0;

    window.addEventListener('dragenter', (e) => {
      e.preventDefault();
      dragCounter++;
      dragOverlay.classList.add('active');
    });

    window.addEventListener('dragleave', (e) => {
      e.preventDefault();
      dragCounter--;
      if (dragCounter === 0) {
        dragOverlay.classList.remove('active');
      }
    });

    window.addEventListener('dragover', (e) => {
      e.preventDefault();
    });

    window.addEventListener('drop', (e) => {
      e.preventDefault();
      dragCounter = 0;
      dragOverlay.classList.remove('active');
      
      const files = e.dataTransfer.files;
      if (files.length > 0) {
        const input = document.getElementById('fileInputElement');
        input.files = files;
        handleFileSelection(input);
      }
    });

    // Dynamic modal state
    let currentModalUrl = '';

    function handleItemClick(el) {
      const type = el.getAttribute('data-type');
      const url = el.getAttribute('data-url');
      const name = el.getAttribute('data-name');
      const size = el.getAttribute('data-size');
      const modified = el.getAttribute('data-modified');
      const mime = el.getAttribute('data-mime');
      
      if (type === 'directory') {
        window.location.href = url;
        return;
      }
      
      currentModalUrl = url;
      
      // Update basic fields
      document.getElementById('modalTitle').textContent = name;
      document.getElementById('modalMeta').textContent = `\${size} • \${modified}`;
      document.getElementById('modalDownloadBtn').href = url;
      document.getElementById('modalDownloadBtn').setAttribute('download', name);
      
      // Dynamic Icon wrapper styling
      const iconWrapper = document.getElementById('modalIcon');
      iconWrapper.className = 'modal-icon-wrapper ' + el.querySelector('.item-icon-wrapper').className.split(' ')[1];
      iconWrapper.innerHTML = el.querySelector('.item-icon-wrapper').innerHTML;
      
      // Render dedicated preview content
      const body = document.getElementById('modalBody');
      body.innerHTML = '';
      
      const ext = name.split('.').pop().toLowerCase();
      
      if (['mp4', 'mkv', 'avi', 'mov'].includes(ext)) {
        body.innerHTML = `
          <div class="video-container">
            <video controls autoplay class="preview-video">
              <source src="\${url}" type="\${mime}">
              Your browser does not support the video streaming tag.
            </video>
          </div>
        `;
      } else if (['mp3', 'wav', 'flac', 'm4a'].includes(ext)) {
        body.innerHTML = `
          <div class="audio-container">
            <div class="audio-art-disc">🎵</div>
            <audio controls autoplay class="preview-audio">
              <source src="\${url}" type="\${mime}">
              Your browser does not support the audio element.
            </audio>
          </div>
        `;
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].includes(ext)) {
        body.innerHTML = `
          <div class="image-container">
            <img src="\${url}" class="preview-image" alt="\${name}">
          </div>
        `;
      } else if (ext === 'pdf') {
        body.innerHTML = `
          <iframe src="\${url}" class="preview-pdf"></iframe>
        `;
      } else if (['txt', 'log', 'json', 'md', 'xml', 'js', 'css', 'html'].includes(ext)) {
        body.innerHTML = `<div class="preview-text-loading">Loading preview...</div>`;
        fetch(url)
          .then(res => res.text())
          .then(text => {
            const escaped = text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            body.innerHTML = `<pre class="preview-text"><code>\${escaped}</code></pre>`;
          })
          .catch(() => {
            body.innerHTML = `<div class="preview-text-error">Failed to stream document. You can still download it directly.</div>`;
          });
      } else {
        body.innerHTML = `
          <div class="generic-container">
            <div class="generic-preview-icon">\${iconWrapper.innerHTML}</div>
            <p class="generic-preview-text">Preview is not supported for this file type</p>
            <p class="generic-preview-subtext">Click Download below to save it on your system.</p>
          </div>
        `;
      }
      
      const modal = document.getElementById('previewModal');
      modal.classList.add('active');
      document.body.style.overflow = 'hidden';
    }

    function closeModal(event) {
      const modal = document.getElementById('previewModal');
      modal.classList.remove('active');
      document.body.style.overflow = '';
      
      // Stop playing video or audio immediately on close
      const body = document.getElementById('modalBody');
      const video = body.querySelector('video');
      if (video) video.pause();
      const audio = body.querySelector('audio');
      if (audio) audio.pause();
      
      body.innerHTML = '';
    }

    // Download & Share operations
    function downloadFile(url, filename, event) {
      if (event) event.stopPropagation();
      const a = document.createElement('a');
      a.href = url;
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
    }

    function copyFileLink(url, event) {
      if (event) event.stopPropagation();
      const absoluteUrl = new URL(url, window.location.href).href;
      copyToClipboard(absoluteUrl, "Link copied to clipboard!");
    }

    function copyModalLink() {
      const absoluteUrl = new URL(currentModalUrl, window.location.href).href;
      copyToClipboard(absoluteUrl, "Link copied to clipboard!");
    }

    function copyToClipboard(text, successMsg) {
      navigator.clipboard.writeText(text).then(() => {
        showToast(successMsg);
      }).catch(() => {
        // Safe fallback for insecure HTTP contexts
        const textarea = document.createElement("textarea");
        textarea.value = text;
        textarea.style.position = "fixed";
        document.body.appendChild(textarea);
        textarea.select();
        try {
          document.execCommand('copy');
          showToast(successMsg);
        } catch (e) {
          showToast("Failed to copy link.");
        }
        document.body.removeChild(textarea);
      });
    }

    function showToast(message) {
      const existing = document.querySelector('.toast-notification');
      if (existing) document.body.removeChild(existing);

      const toast = document.createElement('div');
      toast.className = 'toast-notification';
      toast.textContent = message;
      document.body.appendChild(toast);
      
      setTimeout(() => {
        toast.classList.add('active');
      }, 20);
      
      setTimeout(() => {
        toast.classList.remove('active');
        setTimeout(() => {
          if (toast.parentNode) {
            document.body.removeChild(toast);
          }
        }, 300);
      }, 2500);
    }
  </script>
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
