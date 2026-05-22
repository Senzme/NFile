import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../models/network_connection_model.dart';

class RemoteExplorerScreen extends StatefulWidget {
  final NetworkConnectionModel connection;

  const RemoteExplorerScreen({super.key, required this.connection});

  @override
  State<RemoteExplorerScreen> createState() => _RemoteExplorerScreenState();
}

class _RemoteItem {
  final String name;
  final bool isDir;
  final String size;
  final String modified;
  final String parentPath;

  _RemoteItem({
    required this.name,
    required this.isDir,
    required this.size,
    required this.modified,
    required this.parentPath,
  });

  String get fullPath => parentPath == '/' ? '/$name' : '$parentPath/$name';
}

class _RemoteExplorerScreenState extends State<RemoteExplorerScreen> {
  String _currentPath = '/';
  final List<_RemoteItem> _virtualFileSystem = [];

  // Active download state
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadingFileName = '';

  @override
  void initState() {
    super.initState();
    _populateInitialItems();
  }

  void _populateInitialItems() {
    final type = widget.connection.type;

    // Root items
    _virtualFileSystem.addAll([
      _RemoteItem(name: 'Backups', isDir: true, size: '', modified: 'May 18, 2026', parentPath: '/'),
      _RemoteItem(name: 'Photos', isDir: true, size: '', modified: 'May 20, 2026', parentPath: '/'),
      _RemoteItem(name: 'Documents', isDir: true, size: '', modified: 'May 21, 2026', parentPath: '/'),
    ]);

    if (['Google Drive', 'OneDrive', 'Dropbox', 'Box'].contains(type)) {
      // Cloud Specific Items
      _virtualFileSystem.addAll([
        _RemoteItem(name: 'Shared With Me', isDir: true, size: '', modified: 'May 10, 2026', parentPath: '/'),
        _RemoteItem(name: 'project_proposal.pdf', isDir: false, size: '2.4 MB', modified: 'May 22, 2026', parentPath: '/'),
        _RemoteItem(name: 'budget_2026.xlsx', isDir: false, size: '1.8 MB', modified: 'May 19, 2026', parentPath: '/'),
        _RemoteItem(name: 'vacation_itinerary.docx', isDir: false, size: '420 KB', modified: 'May 15, 2026', parentPath: '/'),
      ]);
    } else {
      // FTP, SFTP, SMB, WebDav Items
      _virtualFileSystem.addAll([
        _RemoteItem(name: 'Public Share', isDir: true, size: '', modified: 'May 12, 2026', parentPath: '/'),
        _RemoteItem(name: 'server_config.yaml', isDir: false, size: '12 KB', modified: 'May 22, 2026', parentPath: '/'),
        _RemoteItem(name: 'database_dump.sql.gz', isDir: false, size: '45.7 MB', modified: 'May 21, 2026', parentPath: '/'),
        _RemoteItem(name: 'site_logo.png', isDir: false, size: '144 KB', modified: 'May 04, 2026', parentPath: '/'),
      ]);
    }

    // Subdirectory item contents
    // /Photos
    _virtualFileSystem.addAll([
      _RemoteItem(name: 'beach_trip.jpg', isDir: false, size: '3.1 MB', modified: 'May 20, 2026', parentPath: '/Photos'),
      _RemoteItem(name: 'family_dinner.jpg', isDir: false, size: '2.4 MB', modified: 'May 19, 2026', parentPath: '/Photos'),
      _RemoteItem(name: 'sunset_horizon.png', isDir: false, size: '5.6 MB', modified: 'May 18, 2026', parentPath: '/Photos'),
      _RemoteItem(name: 'Memories 2025', isDir: true, size: '', modified: 'Jan 01, 2026', parentPath: '/Photos'),
    ]);

    // /Photos/Memories 2025
    _virtualFileSystem.addAll([
      _RemoteItem(name: 'new_year_party.jpg', isDir: false, size: '1.9 MB', modified: 'Jan 01, 2026', parentPath: '/Photos/Memories 2025'),
    ]);

    // /Backups
    _virtualFileSystem.addAll([
      _RemoteItem(name: 'iphone_backup_full.tar', isDir: false, size: '8.4 GB', modified: 'May 15, 2026', parentPath: '/Backups'),
      _RemoteItem(name: 'contacts_vcf.zip', isDir: false, size: '14.2 MB', modified: 'May 10, 2026', parentPath: '/Backups'),
    ]);

    // /Documents
    _virtualFileSystem.addAll([
      _RemoteItem(name: 'Corporate Contract.pdf', isDir: false, size: '1.2 MB', modified: 'May 21, 2026', parentPath: '/Documents'),
      _RemoteItem(name: 'Taxes_2025.pdf', isDir: false, size: '890 KB', modified: 'Apr 12, 2026', parentPath: '/Documents'),
      _RemoteItem(name: 'Ideas.txt', isDir: false, size: '4 KB', modified: 'May 22, 2026', parentPath: '/Documents'),
    ]);
  }

  List<_RemoteItem> get _currentItems {
    return _virtualFileSystem.where((item) => item.parentPath == _currentPath).toList();
  }

  void _navigateTo(_RemoteItem item) {
    if (item.isDir) {
      setState(() {
        _currentPath = item.fullPath;
      });
    } else {
      _startSimulatedDownload(item);
    }
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    setState(() {
      _currentPath = parts.join('/');
      if (_currentPath.isEmpty) {
        _currentPath = '/';
      }
    });
  }

  void _navigateToBreadcrumb(String path) {
    setState(() {
      _currentPath = path;
    });
  }

  // File download simulation
  void _startSimulatedDownload(_RemoteItem item) {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadingFileName = item.name;
    });

    const steps = 20;
    int currentStep = 0;

    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      currentStep++;
      if (mounted) {
        setState(() {
          _downloadProgress = currentStep / steps;
        });
      }

      if (currentStep >= steps) {
        timer.cancel();
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
                  Text('"${item.name}" downloaded to Downloads/NFile_Downloads/'),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    });
  }

  // Create Virtual Directory Dialog
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
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _virtualFileSystem.add(_RemoteItem(
                      name: name,
                      isDir: true,
                      size: '',
                      modified: 'Today',
                      parentPath: _currentPath,
                    ));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // Delete virtual remote item
  void _deleteItem(_RemoteItem item) {
    setState(() {
      _virtualFileSystem.removeWhere((x) => x.fullPath == item.fullPath || x.parentPath.startsWith(item.fullPath));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Simulated deletion of "${item.name}" complete.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Details sheet
  void _showDetailsSheet(_RemoteItem item) {
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
              // Sheet Handle
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
                    item.isDir ? Broken.folder_open : Broken.document,
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
                          item.isDir ? 'Remote Directory' : 'Remote File',
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
              _buildDetailRow('Full Location Path', item.fullPath, theme),
              if (!item.isDir) _buildDetailRow('Total File Size', item.size, theme),
              _buildDetailRow('Last Modified', item.modified, theme),

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
                  if (item.isDir) {
                    _navigateTo(item);
                  } else {
                    _startSimulatedDownload(item);
                  }
                },
                icon: Icon(item.isDir ? Icons.arrow_forward : Icons.download),
                label: Text(item.isDir ? 'Explore Directory' : 'Download Now'),
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
        actions: [
          IconButton(
            icon: const Icon(Broken.folder_add, size: 20),
            tooltip: 'Add Virtual Folder',
            onPressed: _showAddFolderDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
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

                      // Reconstruct path for nodes click
                      String reconstructedPath = '/';
                      if (idx > 0) {
                        reconstructedPath = '/' +
                            pathNodes
                                .sublist(1, idx + 1)
                                .join('/');
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
                child: _currentItems.isEmpty
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
                          itemCount: _currentItems.length,
                          itemBuilder: (context, index) {
                            final item = _currentItems[index];

                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withOpacity(item.isDir ? 0.1 : 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  item.isDir ? Broken.folder_open : Broken.document,
                                  size: 20,
                                  color: theme.colorScheme.primary.withOpacity(item.isDir ? 0.9 : 0.6),
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
                                item.isDir ? '${item.modified}' : '${item.size} • ${item.modified}',
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
                                    _startSimulatedDownload(item);
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
                                  if (!item.isDir)
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
                                        const Text('Unmount / Delete', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
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
