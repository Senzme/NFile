import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart' as xml;
import 'remote_client.dart';

class WebDavRemoteClient implements RemoteClient {
  final String host;
  final int port;
  final String username;
  final String password;
  final String protocol;
  final String rootPath;
  
  late HttpClient _httpClient;

  WebDavRemoteClient({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.protocol = 'http',
    this.rootPath = '/',
  }) {
    _httpClient = HttpClient();
    _httpClient.connectionTimeout = const Duration(seconds: 15);
  }

  String get _baseUrl {
    var sanitizedHost = host.trim();
    if (sanitizedHost.startsWith('http://')) {
      sanitizedHost = sanitizedHost.substring(7);
    } else if (sanitizedHost.startsWith('https://')) {
      sanitizedHost = sanitizedHost.substring(8);
    }
    if (sanitizedHost.contains('/')) {
      final parts = sanitizedHost.split('/');
      sanitizedHost = parts.first;
    }
    return '$protocol://$sanitizedHost:$port';
  }

  String _authHeader() {
    if (username.isEmpty && password.isEmpty) return '';
    final bytes = utf8.encode('$username:$password');
    final base64Str = base64.encode(bytes);
    return 'Basic $base64Str';
  }

  @override
  Future<void> connect() async {
    var normalizedRoot = rootPath;
    if (!normalizedRoot.startsWith('/')) {
      normalizedRoot = '/$normalizedRoot';
    }
    if (!normalizedRoot.endsWith('/')) {
      normalizedRoot = '$normalizedRoot/';
    }
    final url = Uri.parse('$_baseUrl$normalizedRoot');
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
    print('[WebDAV DEBUG] PROPFIND URL: $url');
    final request = await _httpClient.openUrl('PROPFIND', url);
    request.headers.set('Depth', '1');
    final auth = _authHeader();
    if (auth.isNotEmpty) {
      request.headers.set('Authorization', auth);
    }
    
    final response = await request.close();
    print('[WebDAV DEBUG] Response status: ${response.statusCode}');
    if (response.statusCode >= 400) {
      throw Exception('WebDAV list error: ${response.statusCode}');
    }

    final body = await response.transform(utf8.decoder).join();
    print('[WebDAV DEBUG] Response body length: ${body.length}');
    print('[WebDAV DEBUG] Response body: $body');
    final document = xml.XmlDocument.parse(body);
    
    // Find response tags under any namespace prefix case-insensitively
    final responses = document.descendants
        .whereType<xml.XmlElement>()
        .where((element) => element.name.local.toLowerCase() == 'response');

    final list = <RemoteFileItem>[];

    for (final element in responses) {
      final hrefElement = element.children
          .whereType<xml.XmlElement>()
          .where((el) => el.name.local.toLowerCase() == 'href')
          .firstOrNull;
      if (hrefElement == null) continue;
      
      var href = Uri.decodeFull(hrefElement.innerText);
      if (href.startsWith('http://') || href.startsWith('https://')) {
        final uri = Uri.parse(href);
        href = uri.path;
      }
      
      if (href == normalizedPath || href == normalizedPath.substring(0, normalizedPath.length - 1)) {
        continue;
      }

      final propstats = element.children
          .whereType<xml.XmlElement>()
          .where((el) => el.name.local.toLowerCase() == 'propstat');
      
      var isCollection = false;
      var size = 0;
      var modified = DateTime.now();

      for (final propstat in propstats) {
        final resourcetype = propstat.descendants
            .whereType<xml.XmlElement>()
            .where((el) => el.name.local.toLowerCase() == 'resourcetype')
            .firstOrNull;
        if (resourcetype != null) {
          isCollection = resourcetype.descendants
              .whereType<xml.XmlElement>()
              .where((el) => el.name.local.toLowerCase() == 'collection')
              .isNotEmpty;
        }

        final getcontentlength = propstat.descendants
            .whereType<xml.XmlElement>()
            .where((el) => el.name.local.toLowerCase() == 'getcontentlength')
            .firstOrNull;
        if (getcontentlength != null) {
          size = int.tryParse(getcontentlength.innerText) ?? 0;
        }

        final getlastmodified = propstat.descendants
            .whereType<xml.XmlElement>()
            .where((el) => el.name.local.toLowerCase() == 'getlastmodified')
            .firstOrNull;
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
