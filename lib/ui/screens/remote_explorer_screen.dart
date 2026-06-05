import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../models/network_connection_model.dart';
import '../../providers/file_manager_provider.dart';
import '../../services/remote/remote_client.dart';
import '../../services/remote/ftp_client.dart';
import '../../services/remote/sftp_client.dart';
import '../../services/remote/webdav_client.dart';
import '../../services/remote/lan_client.dart';
import '../../services/remote/saf_client.dart';

// Clipboard for remote→local operations
class _RemoteClipboard {
  final List<RemoteFileItem> items;
  final bool isCut;

  const _RemoteClipboard({required this.items, required this.isCut});
}

class RemoteExplorerScreen extends StatefulWidget {
  final NetworkConnectionModel connection;

  const RemoteExplorerScreen({super.key, required this.connection});

  @override
  State<RemoteExplorerScreen> createState() => _RemoteExplorerScreenState();
}

class _RemoteExplorerScreenState extends State<RemoteExplorerScreen> {
  RemoteClient? _client;
  bool _isConnected = false;
  bool _isLoading = true;
  String _errorMsg = '';
  String _currentPath = '/';
  List<RemoteFileItem> _items = [];

  // Transfer overlay
  bool _isTransferring = false;
  double _transferProgress = 0.0;
  String _transferFileName = '';
  String _transferLabel = 'Transferring...';

  @override
  void initState() {
    super.initState();
    _currentPath = widget.connection.rootPath;
    _initClient();
  }

  @override
  void dispose() {
    _client?.disconnect();
    super.dispose();
  }

  Future<void> _initClient() async {
    final conn = widget.connection;
    if (conn.type == 'FTP') {
      _client = FtpRemoteClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'SFTP') {
      _client = SftpRemoteClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'WebDav') {
      _client = WebDavRemoteClient(
        host: conn.host,
        port: conn.port,
        username: conn.username,
        password: conn.password,
        protocol: conn.protocol,
        rootPath: conn.rootPath,
      );
    } else if (conn.type == 'LAN/SMB') {
      _client = LanClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'saf') {
      _client = SafRemoteClient(rootUri: conn.rootPath);
    }

    try {
      await _client?.connect();
      _isConnected = true;
      await _loadDirectoryContents(_currentPath);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDirectoryContents(String path) async {
    if (_client == null || !_isConnected) return;
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      final items = await _client!.listDirectory(path);
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return FileUtils.compareNatural(a.name, b.name);
      });
      if (mounted) {
        setState(() {
          _items = items;
          _currentPath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(RemoteFileItem item) {
    if (item.isDirectory) {
      _loadDirectoryContents(item.path);
    } else {
      _showItemActions(item);
    }
  }

  String _getSafParentUri(String currentUri, String rootUri) {
    if (currentUri == rootUri) return rootUri;
    final docIndex = currentUri.indexOf('/document/');
    if (docIndex == -1) return rootUri;
    
    final baseUri = currentUri.substring(0, docIndex + 10); // includes "content://.../document/"
    final documentId = Uri.decodeComponent(currentUri.substring(docIndex + 10));
    final docParts = documentId.split('/');
    if (docParts.isEmpty) return rootUri;
    
    docParts.removeLast();
    if (docParts.isEmpty) return rootUri;
    
    final parentDocId = docParts.join('/');
    return '$baseUri${Uri.encodeComponent(parentDocId)}';
  }

  void _navigateUp() {
    if (_currentPath == widget.connection.rootPath) return;
    if (widget.connection.type == 'saf') {
      final parentUri = _getSafParentUri(_currentPath, widget.connection.rootPath);
      _loadDirectoryContents(parentUri);
      return;
    }
    final parts = _currentPath.split('/');
    if (parts.isNotEmpty) parts.removeLast();
    var parent = parts.join('/');
    if (parent.isEmpty) parent = '/';
    if (parent.length < widget.connection.rootPath.length) {
      parent = widget.connection.rootPath;
    }
    _loadDirectoryContents(parent);
  }

  void _navigateToBreadcrumb(String path) {
    _loadDirectoryContents(path);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COPY / CUT / PASTE - Remote items
  // ─────────────────────────────────────────────────────────────────────────

  void _copyRemoteItem(RemoteFileItem item) {
    context.read<FileManagerProvider>().setRemoteClipboard(
      [item],
      isCut: false,
      connection: widget.connection,
    );
    _showSnack('Copied "${item.name}" to clipboard');
  }

  void _cutRemoteItem(RemoteFileItem item) {
    context.read<FileManagerProvider>().setRemoteClipboard(
      [item],
      isCut: true,
      connection: widget.connection,
    );
    _showSnack('Cut "${item.name}" to clipboard');
  }

  /// Paste remote clipboard items to current remote directory
  Future<void> _pasteRemoteClipboard() async {
    final provider = context.read<FileManagerProvider>();
    if (!provider.isRemoteClipboard || _client == null) return;
    final clipItems = provider.remoteClipboardItems;
    final isCut = provider.isCut;

    for (final item in clipItems) {
      final destPath = _currentPath == '/'
          ? '/${item.name}'
          : '$_currentPath/${item.name}';

      if (destPath == item.path) {
        _showSnack('Cannot paste to the same location');
        return;
      }

      setState(() {
        _isTransferring = true;
        _transferProgress = 0.0;
        _transferFileName = item.name;
        _transferLabel = isCut ? 'Moving...' : 'Copying...';
      });

      try {
        // Download to temp, then upload to new path
        final tempDir = await getTemporaryDirectory();
        final tempPath = p.join(tempDir.path, item.name);

        await _client!.downloadFile(item.path, tempPath, (p) {
          if (mounted) setState(() => _transferProgress = p * 0.5);
        });

        await _client!.uploadFile(tempPath, destPath, (p) {
          if (mounted) setState(() => _transferProgress = 0.5 + p * 0.5);
        });

        if (isCut) {
          await _client!.delete(item.path, item.isDirectory);
        }

        // Cleanup temp
        try { File(tempPath).deleteSync(); } catch (_) {}
      } catch (e) {
        if (mounted) {
          setState(() => _isTransferring = false);
          _showSnack('Transfer failed: $e', isError: true);
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _isTransferring = false;
      });
      if (isCut) provider.clearClipboard();
      _showSnack('Pasted items successfully');
      await _loadDirectoryContents(_currentPath);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPLOAD - Local device → Remote server
  // ─────────────────────────────────────────────────────────────────────────

  /// Upload all files from local app clipboard to current remote directory
  Future<void> _uploadFromLocalClipboard() async {
    final provider = context.read<FileManagerProvider>();
    if (!provider.hasClipboard) {
      _showSnack('Local clipboard is empty. Copy files in the file manager first.', isError: true);
      return;
    }
    if (_client == null) return;

    final paths = List<String>.from(provider.clipboardPaths);
    final isCut = provider.isCut;

    for (final localPath in paths) {
      final file = File(localPath);
      if (!file.existsSync()) continue;

      final fileName = p.basename(localPath);
      final remoteDest = _currentPath == '/' ? '/$fileName' : '$_currentPath/$fileName';

      setState(() {
        _isTransferring = true;
        _transferProgress = 0.0;
        _transferFileName = fileName;
        _transferLabel = 'Uploading to server...';
      });

      try {
        await _client!.uploadFile(localPath, remoteDest, (prog) {
          if (mounted) setState(() => _transferProgress = prog);
        });

        if (isCut) {
          try { file.deleteSync(); } catch (_) {}
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isTransferring = false);
          _showSnack('Upload failed for "$fileName": $e', isError: true);
          return;
        }
      }
    }

    if (mounted) {
      setState(() => _isTransferring = false);
      if (isCut) provider.clearClipboard();
      _showSnack('Uploaded ${paths.length} file(s) successfully');
      await _loadDirectoryContents(_currentPath);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOWNLOAD - Remote → Local device clipboard / downloads folder
  // ─────────────────────────────────────────────────────────────────────────

  /// Download remote file to local Downloads and then put path in local clipboard
  Future<void> _downloadToLocalClipboard(RemoteFileItem item, {bool isCut = false}) async {
    if (_client == null) return;

    setState(() {
      _isTransferring = true;
      _transferProgress = 0.0;
      _transferFileName = item.name;
      _transferLabel = 'Downloading from server...';
    });

    try {
      Directory? downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) {
        downloadDir = await getExternalStorageDirectory();
      }
      downloadDir ??= await getApplicationDocumentsDirectory();

      final nfileDir = Directory(p.join(downloadDir.path, 'NFile_Remote'));
      if (!nfileDir.existsSync()) nfileDir.createSync(recursive: true);

      final localPath = p.join(nfileDir.path, item.name);

      await _client!.downloadFile(item.path, localPath, (prog) {
        if (mounted) setState(() => _transferProgress = prog);
      });

      if (isCut) {
        await _client!.delete(item.path, item.isDirectory);
      }

      if (mounted) {
        setState(() => _isTransferring = false);
        // Put downloaded file in local clipboard
        context.read<FileManagerProvider>().setClipboard([localPath], isCut: false);
        _showSnack('"${item.name}" downloaded → local clipboard ready to paste');
        if (isCut) await _loadDirectoryContents(_currentPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTransferring = false);
        _showSnack('Download failed: $e', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _deleteItem(RemoteFileItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text('Delete Item', style: TextStyle(fontFamily: 'LexendDeca', fontWeight: FontWeight.bold)),
          content: Text('Delete "${item.name}" permanently from the server?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await _client?.delete(item.path, item.isDirectory);
      await _loadDirectoryContents(_currentPath);
      _showSnack('Deleted "${item.name}"');
    } catch (e) {
      _showSnack('Failed to delete: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE FOLDER
  // ─────────────────────────────────────────────────────────────────────────

  void _showAddFolderDialog() {
    final controller = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'New Remote Folder',
            style: TextStyle(fontFamily: 'LexendDeca', fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Folder name',
              hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.35)),
              prefixIcon: Icon(Broken.folder_open, size: 18, color: theme.colorScheme.primary),
              filled: true,
              fillColor: theme.colorScheme.primary.withOpacity(0.04),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    final folderPath = _currentPath == '/' ? '/$name' : '$_currentPath/$name';
                    await _client?.createDirectory(folderPath);
                    await _loadDirectoryContents(_currentPath);
                  } catch (e) {
                    if (mounted) {
                      _showSnack('Failed to create folder: $e', isError: true);
                      setState(() => _isLoading = false);
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ITEM ACTIONS BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────

  void _showItemActions(RemoteFileItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.read<FileManagerProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.isDirectory ? Broken.folder_open : Broken.document,
                      size: 22, color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'LexendDeca'),
                          overflow: TextOverflow.ellipsis),
                        Text(
                          item.isDirectory ? 'Remote Directory' : item.formattedSize,
                          style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Actions ──
              // Copy remote item
              _buildActionTile(
                ctx, icon: Broken.copy, label: 'Copy',
                color: theme.colorScheme.primary,
                onTap: () { Navigator.pop(ctx); _copyRemoteItem(item); },
              ),

              // Cut remote item
              _buildActionTile(
                ctx, icon: Broken.scissor, label: 'Cut',
                color: Colors.orange,
                onTap: () { Navigator.pop(ctx); _cutRemoteItem(item); },
              ),

              // Copy to local device (downloads file and puts in local clipboard)
              if (!item.isDirectory)
                _buildActionTile(
                  ctx, icon: Icons.download_for_offline_rounded, label: 'Copy to Local Device',
                  subtitle: 'Downloads file → local clipboard',
                  color: const Color(0xFF0D9488),
                  onTap: () { Navigator.pop(ctx); _downloadToLocalClipboard(item, isCut: false); },
                ),

              // Cut from remote to local device
              if (!item.isDirectory)
                _buildActionTile(
                  ctx, icon: Icons.drive_file_move_rtl_rounded, label: 'Move to Local Device',
                  subtitle: 'Downloads and deletes from server',
                  color: const Color(0xFF7C3AED),
                  onTap: () { Navigator.pop(ctx); _downloadToLocalClipboard(item, isCut: true); },
                ),

              // Delete
              _buildActionTile(
                ctx, icon: Broken.trash, label: 'Delete',
                color: Colors.redAccent,
                onTap: () { Navigator.pop(ctx); _deleteItem(item); },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    String? subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(ctx);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.45))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.redAccent : Theme.of(context).colorScheme.primary,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<FileManagerProvider>();

    final isSaf = widget.connection.type == 'saf';
    final rootPath = widget.connection.rootPath;
    
    List<String> pathNodes = [];
    List<String> pathUris = [];
    
    if (isSaf) {
      pathNodes.add('Root');
      pathUris.add(rootPath);
      
      final docIndex = _currentPath.indexOf('/document/');
      if (docIndex != -1) {
        final baseUri = _currentPath.substring(0, docIndex + 10);
        final documentId = Uri.decodeComponent(_currentPath.substring(docIndex + 10));
        final docParts = documentId.split('/').where((n) => n.isNotEmpty).toList();
        
        for (int i = 0; i < docParts.length; i++) {
          final part = docParts[i];
          String displayName = part;
          if (part.contains(':')) {
            displayName = part.split(':').last;
            if (displayName.isEmpty) {
              displayName = part;
            }
          }
          pathNodes.add(displayName);
          
          final subParts = docParts.sublist(0, i + 1);
          final subDocId = subParts.join('/');
          pathUris.add('$baseUri${Uri.encodeComponent(subDocId)}');
        }
      }
    } else {
      String relativePath = _currentPath;
      if (_currentPath.startsWith(rootPath)) {
        relativePath = _currentPath.substring(rootPath.length);
      }
      if (relativePath.isEmpty || relativePath == '/') relativePath = '';

      pathNodes = relativePath.isEmpty
          ? ['Root']
          : ['Root', ...relativePath.split('/').where((n) => n.isNotEmpty)];
    }

    final hasLocalClipboard = provider.clipboardPaths.isNotEmpty;
    final hasRemoteClipboard = provider.isRemoteClipboard;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_currentPath != widget.connection.rootPath) _navigateUp();
            else Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.connection.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5)),
            Text('${widget.connection.type} Server',
              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: _isConnected ? [
          // Paste local clipboard to remote
          if (hasLocalClipboard)
            IconButton(
              icon: Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(Broken.copy, size: 20, color: theme.colorScheme.primary),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 1)),
                  ),
                ],
              ),
              tooltip: 'Upload local clipboard to server',
              onPressed: _uploadFromLocalClipboard,
            ),
          // Paste remote clipboard
          if (hasRemoteClipboard)
            IconButton(
              icon: Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(Icons.content_paste_rounded, size: 20, color: theme.colorScheme.primary),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: provider.isCut ? Colors.orange : Colors.green, shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 1)),
                  ),
                ],
              ),
              tooltip: provider.isCut ? 'Move here' : 'Paste remote clipboard',
              onPressed: _pasteRemoteClipboard,
            ),
          IconButton(
            icon: const Icon(Broken.folder_add, size: 20),
            tooltip: 'New Folder',
            onPressed: _showAddFolderDialog,
          ),
        ] : null,
      ),

      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMsg.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Broken.info_circle, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text('Connection Lost', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_errorMsg, textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setState(() { _isLoading = true; _errorMsg = ''; });
                        _initClient();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Connection'),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Clipboard status banner
                if (hasLocalClipboard || hasRemoteClipboard)
                  _buildClipboardBanner(theme, hasLocalClipboard, hasRemoteClipboard, provider),

                // Breadcrumbs
                Container(
                  height: 44,
                  width: double.infinity,
                  color: theme.colorScheme.onSurface.withOpacity(0.03),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ScrollConfiguration(
                    behavior: const ScrollBehavior().copyWith(overscroll: false),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: pathNodes.length,
                      itemBuilder: (context, idx) {
                        final isLast = idx == pathNodes.length - 1;
                        final String reconstructedPath = isSaf
                            ? pathUris[idx]
                            : (idx > 0
                                ? (rootPath.endsWith('/') ? '$rootPath${pathNodes.sublist(1, idx + 1).join('/')}' : '$rootPath/${pathNodes.sublist(1, idx + 1).join('/')}')
                                : rootPath);
                        return Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: isLast ? null : () => _navigateToBreadcrumb(reconstructedPath),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                                child: Text(pathNodes[idx],
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                                    color: isLast
                                        ? theme.colorScheme.onSurface.withOpacity(0.9)
                                        : theme.colorScheme.primary,
                                  )),
                              ),
                            ),
                            if (!isLast)
                              Icon(Icons.chevron_right_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // File list
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Broken.folder_open, size: 56, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                              const SizedBox(height: 14),
                              Text('Empty Directory',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withOpacity(0.4))),
                              if (hasLocalClipboard) ...[
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _uploadFromLocalClipboard,
                                  icon: const Icon(Icons.upload_rounded, size: 16),
                                  label: const Text('Upload Clipboard Here'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(overscroll: false),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final isInRemoteClip = provider.isRemoteClipboard && provider.remoteClipboardItems.any((e) => e.path == item.path);

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(item.isDirectory ? 0.1 : 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    item.isDirectory ? Broken.folder_open : Broken.document,
                                    size: 20,
                                    color: theme.colorScheme.primary.withOpacity(item.isDirectory ? 0.9 : 0.6),
                                  ),
                                ),
                                title: Text(item.name,
                                  style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600,
                                    color: isInRemoteClip ? theme.colorScheme.primary.withOpacity(0.6) : null,
                                    decoration: (isInRemoteClip && provider.isCut)
                                        ? TextDecoration.lineThrough : null,
                                  ),
                                  overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                  item.isDirectory
                                      ? 'Directory'
                                      : '${item.formattedSize} • ${item.modified.toLocal().toString().substring(0, 10)}',
                                  style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'copy': _copyRemoteItem(item); break;
                                      case 'cut': _cutRemoteItem(item); break;
                                      case 'paste': await _pasteRemoteClipboard(); break;
                                      case 'copy_to_local': await _downloadToLocalClipboard(item); break;
                                      case 'move_to_local': await _downloadToLocalClipboard(item, isCut: true); break;
                                      case 'delete': await _deleteItem(item); break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    _popItem('copy', Broken.copy, 'Copy', theme.colorScheme.primary),
                                    _popItem('cut', Broken.scissor, 'Cut', Colors.orange),
                                    if (hasRemoteClipboard)
                                      _popItem('paste', Icons.content_paste_rounded, 'Paste Here', const Color(0xFF0D9488)),
                                    if (!item.isDirectory) ...[
                                      const PopupMenuDivider(),
                                      _popItem('copy_to_local', Icons.download_for_offline_rounded, 'Copy to Device', const Color(0xFF7C3AED)),
                                      _popItem('move_to_local', Icons.drive_file_move_rtl_rounded, 'Move to Device', const Color(0xFF0D9488)),
                                    ],
                                    const PopupMenuDivider(),
                                    _popItem('delete', Broken.trash, 'Delete', Colors.redAccent),
                                  ],
                                ),
                                onTap: () => _navigateTo(item),
                                onLongPress: () => _showItemActions(item),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),

          // Transfer overlay
          if (_isTransferring)
            _buildTransferOverlay(theme, isDark),
        ],
      ),
    );
  }

  PopupMenuItem<String> _popItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildClipboardBanner(ThemeData theme, bool hasLocal, bool hasRemote, FileManagerProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primary.withOpacity(0.08),
      child: Row(
        children: [
          Icon(hasLocal ? Icons.upload_rounded : Icons.content_paste_rounded,
            size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasLocal
                  ? '${provider.clipboardPaths.length} local file(s) ready to upload'
                  : '${provider.remoteClipboardItems.length} remote item(s) ${provider.isCut ? "cut" : "copied"}',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
          if (hasLocal)
            TextButton(
              onPressed: _uploadFromLocalClipboard,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Upload', style: TextStyle(fontSize: 12)),
            ),
          if (hasRemote)
            TextButton(
              onPressed: _pasteRemoteClipboard,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Paste', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              provider.clearClipboard();
            },
            child: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferOverlay(ThemeData theme, bool isDark) {
    return Container(
      color: Colors.black.withOpacity(0.45),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Card(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 16,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 72, width: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 5,
                    value: _transferProgress,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  ),
                ),
                const SizedBox(height: 20),
                Text(_transferLabel,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.9), fontFamily: 'LexendDeca')),
                const SizedBox(height: 4),
                SizedBox(
                  width: 200,
                  child: Text(_transferFileName,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(height: 10),
                Text('${(_transferProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
