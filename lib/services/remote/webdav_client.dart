import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'remote_client.dart';

class WebDavRemoteClient implements RemoteClient {
  final String host;
  final int port;
  final String username;
  final String password;
  
  late HttpClient _httpClient;

  WebDavRemoteClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  }) {
    _httpClient = HttpClient();
    _httpClient.connectionTimeout = const Duration(seconds: 15);
  }

  String get _baseUrl {
    final scheme = (port == 443) ? 'https' : 'http';
    return '$scheme://$host:$port';
  }

  String _authHeader() {
    if (username.isEmpty && password.isEmpty) return '';
    final bytes = utf8.encode('$username:$password');
    final base64Str = base64.encode(bytes);
    return 'Basic $base64Str';
  }

  @override
  Future<void> connect() async {
    final url = Uri.parse('$_baseUrl/');
    final request = await _httpClient.openUrl('PROPFIND', url);
    request.headers.set('Depth', '0');
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw Exception('Failed to connect to WebDAV: ${response.statusCode}');
    }
    await response.drain();
  }

  @override
  Future<void> disconnect() async {
    _httpClient.close();
  }

  @override
  Future<List<RemoteFileItem>> listDirectory(String path) async {
    var normalizedPath = path;
    if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }
    if (!normalizedPath.endsWith('/') && normalizedPath != '/') {
      normalizedPath = '$normalizedPath/';
    }

    final url = Uri.parse(_baseUrl + Uri.encodeFull(normalizedPath));
    final request = await _httpClient.openUrl('PROPFIND', url);
    request.headers.set('Depth', '1');
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw Exception('WebDAV list error: ${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    final document = xml.XmlDocument.parse(body);
    
    // Find response tags under any namespace
    final responses = document.findAllElements('d:response').isNotEmpty 
        ? document.findAllElements('d:response') 
        : document.findAllElements('response');

    final list = <RemoteFileItem>[];

    for (final element in responses) {
      final hrefElement = element.findElements('d:href').firstOrNull ?? element.findElements('href').firstOrNull;
      if (hrefElement == null) continue;
      
      var href = Uri.decodeFull(hrefElement.innerText);
      if (href.startsWith('http://') || href.startsWith('https://')) {
        final uri = Uri.parse(href);
        href = uri.path;
      }
      
      if (href == normalizedPath || href == normalizedPath.substring(0, normalizedPath.length - 1)) {
        continue;
      }

      final propstats = element.findAllElements('d:propstat').isNotEmpty 
          ? element.findAllElements('d:propstat') 
          : element.findAllElements('propstat');
      
      var isCollection = false;
      var size = 0;
      var modified = DateTime.now();

      for (final propstat in propstats) {
        final resourcetype = propstat.findAllElements('d:resourcetype').firstOrNull ?? propstat.findAllElements('resourcetype').firstOrNull;
        if (resourcetype != null) {
          isCollection = resourcetype.findAllElements('d:collection').isNotEmpty || resourcetype.findAllElements('collection').isNotEmpty;
        }

        final getcontentlength = propstat.findAllElements('d:getcontentlength').firstOrNull ?? propstat.findAllElements('getcontentlength').firstOrNull;
        if (getcontentlength != null) {
          size = int.tryParse(getcontentlength.innerText) ?? 0;
        }

        final getlastmodified = propstat.findAllElements('d:getlastmodified').firstOrNull ?? propstat.findAllElements('getlastmodified').firstOrNull;
        if (getlastmodified != null) {
          try {
            modified = HttpDate.parse(getlastmodified.innerText);
          } catch (_) {}
        }
      }

      final name = href.endsWith('/') 
          ? href.substring(0, href.length - 1).split('/').last 
          : href.split('/').last;

      if (name.isEmpty) continue;

      list.add(RemoteFileItem(
        name: name,
        path: href,
        isDirectory: isCollection,
        size: size,
        modified: modified,
      ));
    }
    return list;
  }

  @override
  Future<void> createDirectory(String path) async {
    var normalizedPath = path;
    if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }
    final url = Uri.parse(_baseUrl + Uri.encodeFull(normalizedPath));
    final request = await _httpClient.openUrl('MKCOL', url);
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw Exception('WebDAV folder create error: ${response.statusCode}');
    }
    await response.drain();
  }

  @override
  Future<void> delete(String path, bool isDir) async {
    final url = Uri.parse(_baseUrl + Uri.encodeFull(path));
    final request = await _httpClient.openUrl('DELETE', url);
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw Exception('WebDAV delete error: ${response.statusCode}');
    }
    await response.drain();
  }

  @override
  Future<void> downloadFile(String remotePath, String localPath, Function(double progress) onProgress) async {
    final url = Uri.parse(_baseUrl + Uri.encodeFull(remotePath));
    final request = await _httpClient.openUrl('GET', url);
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    final response = await request.close();
    if (response.statusCode >= 400) {
      throw Exception('WebDAV download error: ${response.statusCode}');
    }

    final totalSize = response.contentLength;
    final file = File(localPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final sink = file.openWrite();
    int downloaded = 0;

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (totalSize > 0) {
          onProgress(downloaded / totalSize);
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  @override
  Future<void> uploadFile(
    String localPath,
    String remotePath,
    Function(double progress) onProgress,
  ) async {
    final localFile = File(localPath);
    if (!localFile.existsSync()) throw Exception('Local file not found: $localPath');

    final totalSize = await localFile.length();

    var normalizedPath = remotePath;
    if (!normalizedPath.startsWith('/')) normalizedPath = '/$normalizedPath';

    final url = Uri.parse(_baseUrl + Uri.encodeFull(normalizedPath));
    final request = await _httpClient.openUrl('PUT', url);
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    request.headers.contentLength = totalSize;
    request.headers.contentType = ContentType.binary;

    int uploaded = 0;
    onProgress(0.0);

    await for (final chunk in localFile.openRead()) {
      request.add(chunk);
      uploaded += chunk.length;
      if (totalSize > 0) {
        onProgress((uploaded / totalSize).clamp(0.0, 1.0));
      }
    }

    final response = await request.close();
    await response.drain();

    if (response.statusCode >= 400) {
      throw Exception('WebDAV upload error: ${response.statusCode}');
    }
    onProgress(1.0);
  }
}
