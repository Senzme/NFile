import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../models/network_connection_model.dart';
import '../../services/remote/remote_client.dart';
import '../../services/remote/ftp_client.dart';
import '../../services/remote/sftp_client.dart';
import '../../services/remote/webdav_client.dart';
import '../../services/remote/lan_client.dart';

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

  // Active download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadingFileName = '';

  @override
  void initState() {
    super.initState();
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
      _client = WebDavRemoteClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
    } else if (conn.type == 'LAN/SMB') {
      _client = LanClient(host: conn.host, port: conn.port, username: conn.username, password: conn.password);
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
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
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
      _showDetailsSheet(item);
    }
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    if (parts.isNotEmpty) parts.removeLast();
    var parent = parts.join('/');
    if (parent.isEmpty) {
      parent = '/';
    }
    _loadDirectoryContents(parent);
  }

  void _navigateToBreadcrumb(String path) {
    _loadDirectoryContents(path);
  }

  // File download
  Future<void> _startDownload(RemoteFileItem item) async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadingFileName = item.name;
    });

    try {
      Directory? downloadDir = Directory('/storage/emulated/0/Download');
      if (!downloadDir.existsSync()) {
        downloadDir = await getExternalStorageDirectory();
      }
      if (downloadDir == null) {
        final dir = await getApplicationDocumentsDirectory();
        downloadDir = dir;
      }
      
      final nfileDownloadsDir = Directory(p.join(downloadDir.path, 'NFile_Downloads'));
      if (!nfileDownloadsDir.existsSync()) {
        nfileDownloadsDir.createSync(recursive: true);
      }
      
      final localPath = p.join(nfileDownloadsDir.path, item.name);

      await _client!.downloadFile(item.path, localPath, (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      });

      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Broken.document_download, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('"${item.name}" downloaded to Downloads/NFile_Downloads/')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Create Directory Dialog
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to create folder: $e'), backgroundColor: Colors.redAccent),
                      );
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

  // Delete remote item
  Future<void> _deleteItem(RemoteFileItem item) async {
    setState(() => _isLoading = true);
    try {
      await _client?.delete(item.path, item.isDirectory);
      await _loadDirectoryContents(_currentPath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${item.name}" successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Details sheet
  void _showDetailsSheet(RemoteFileItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Icon(
                    item.isDirectory ? Broken.folder_open : Broken.document,
                    size: 38,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'LexendDeca',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.isDirectory ? 'Remote Directory' : 'Remote File',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),

              _buildDetailRow('Server Name', widget.connection.name, theme),
              _buildDetailRow('Protocol Type', widget.connection.type, theme),
              _buildDetailRow('Remote Address', widget.connection.host, theme),
              _buildDetailRow('Full Location Path', item.path, theme),
              if (!item.isDirectory) _buildDetailRow('Total File Size', item.formattedSize, theme),
              _buildDetailRow('Last Modified', item.modified.toLocal().toString().substring(0, 19), theme),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (item.isDirectory) {
                    _navigateTo(item);
                  } else {
                    _startDownload(item);
                  }
                },
                icon: Icon(item.isDirectory ? Icons.arrow_forward : Icons.download),
                label: Text(item.isDirectory ? 'Explore Directory' : 'Download Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pathNodes = _currentPath == '/' ? ['Root'] : ['Root', ..._currentPath.split('/').where((n) => n.isNotEmpty)];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_currentPath != '/') {
              _navigateUp();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.connection.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
            ),
            Text(
              '${widget.connection.type} Server',
              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: _isConnected
            ? [
                IconButton(
                  icon: const Icon(Broken.folder_add, size: 20),
                  tooltip: 'Add Remote Folder',
                  onPressed: _showAddFolderDialog,
                ),
              ]
            : null,
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
                    Text(
                      'Connection Lost',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMsg = '';
                        });
                        _initClient();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Connection'),
                    )
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                // Breadcrumbs panel
                Container(
                  height: 48,
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

                        String reconstructedPath = '/';
                        if (idx > 0) {
                          reconstructedPath = '/' + pathNodes.sublist(1, idx + 1).join('/');
                        }

                        return Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: isLast ? null : () => _navigateToBreadcrumb(reconstructedPath),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                                child: Text(
                                  pathNodes[idx],
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                                    color: isLast
                                        ? theme.colorScheme.onSurface.withOpacity(0.9)
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            if (!isLast)
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface.withOpacity(0.3),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                // Remote items browser list
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Broken.folder_open,
                                size: 56,
                                color: theme.colorScheme.onSurface.withOpacity(0.2),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'This Directory is Empty',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap the top-right button to append virtual sub-folders.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                                ),
                              ),
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
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  item.isDirectory ? 'Directory' : '${item.formattedSize} • ${item.modified.toLocal().toString().substring(0, 10)}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 18,
                                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'details') {
                                      _showDetailsSheet(item);
                                    } else if (value == 'download') {
                                      _startDownload(item);
                                    } else if (value == 'delete') {
                                      _deleteItem(item);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(Broken.info_circle, size: 16, color: theme.colorScheme.primary),
                                          const SizedBox(width: 8),
                                          const Text('Properties', style: TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    if (!item.isDirectory)
                                      PopupMenuItem(
                                        value: 'download',
                                        child: Row(
                                          children: [
                                            Icon(Broken.document_download, size: 16, color: theme.colorScheme.primary),
                                            const SizedBox(width: 8),
                                            const Text('Download File', style: TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Broken.trash, size: 16, color: Colors.redAccent.withOpacity(0.8)),
                                          const SizedBox(width: 8),
                                          const Text('Delete', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _navigateTo(item),
                                onLongPress: () => _showDetailsSheet(item),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),

          // Download circular overlay animation
          if (_isDownloading)
            Container(
              color: Colors.black.withOpacity(0.4),
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 16,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 72,
                          width: 72,
                          child: CircularProgressIndicator(
                            strokeWidth: 5,
                            value: _downloadProgress,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Downloading File...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withOpacity(0.9),
                            fontFamily: 'LexendDeca',
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 180,
                          child: Text(
                            _downloadingFileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
