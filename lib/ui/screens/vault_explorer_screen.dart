import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../../providers/file_manager_provider.dart';
import '../../services/vault_service.dart';
import 'image_viewer_screen.dart';
import 'video_player/video_player_screen.dart';
import 'audio_player/audio_player_screen.dart';
import 'text_editor_screen.dart';
import 'internal_file_picker_screen.dart';
import 'archive_viewer_screen.dart';

class VaultExplorerScreen extends StatefulWidget {
  final String password;
  const VaultExplorerScreen({super.key, required this.password});

  @override
  State<VaultExplorerScreen> createState() => _VaultExplorerScreenState();
}

class _VaultExplorerScreenState extends State<VaultExplorerScreen> {
  List<VaultFileRecord> _records = [];
  List<VaultFileRecord> _filteredRecords = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVaultData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadVaultData() async {
    setState(() => _isLoading = true);
    try {
      final data = await VaultService.loadRecords();
      // Verify files actually exist, otherwise we clean up records that are missing
      final validRecords = <VaultFileRecord>[];
      for (final rec in data) {
        if (await File(rec.scrambledPath).exists()) {
          validRecords.add(rec);
        }
      }
      if (validRecords.length != data.length) {
        await VaultService.saveRecords(validRecords);
      }
      if (mounted) {
        setState(() {
          _records = validRecords;
          _filteredRecords = validRecords;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vault: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRecords = _records;
      } else {
        _filteredRecords = _records
            .where((rec) => rec.originalName.toLowerCase().contains(_searchQuery))
            .toList();
      }
    });
  }

  int _calculateTotalBytes() {
    return _records.fold(0, (sum, rec) => sum + rec.size);
  }

  Future<void> _pickAndLockFiles() async {
    final fileManager = context.read<FileManagerProvider>();
    final rootPath = fileManager.rootPath.isNotEmpty ? fileManager.rootPath : '/storage/emulated/0';
    
    // Launch NFile's custom internal picker
    final selectedPaths = await InternalFilePickerScreen.show(context, rootPath: rootPath);
    if (selectedPaths == null || selectedPaths.isEmpty) return;

    if (!mounted) return;

    // Show custom modal to select locking type
    final bool? isSandbox = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Lock Option',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              elevation: 12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Broken.security_safe,
                      color: theme.colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Protection Mode',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                'Choose how you want to protect your selected files. Secured files are XOR scrambled instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.4),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsPadding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              actions: [
                Column(
                  children: [
                    // Premium Button for Sandbox (Safe)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.maxFinite, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context, true), // true = Sandbox move
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Broken.lock, size: 20),
                          SizedBox(width: 8),
                          Text('Secure Import (Sandbox)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Outlined Button for In-place (Fast)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        minimumSize: const Size(double.maxFinite, 52),
                        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context, false), // false = In-place scramble
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Broken.flash_1, size: 20),
                          SizedBox(width: 8),
                          Text('In-Place Scramble (Fast)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isSandbox == null) return;

    // Proceed to encrypt selected files with progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Scrambling & Protecting...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );

    int successCount = 0;
    int failCount = 0;

    for (final path in selectedPaths) {
      try {
        if (FileSystemEntity.isDirectorySync(path)) {
          final dir = Directory(path);
          if (await dir.exists()) {
            await VaultService.lockDirectory(
              directory: dir,
              password: widget.password,
              inPlace: !isSandbox,
            );
            successCount++;
          }
        } else {
          final file = File(path);
          if (await file.exists()) {
            await VaultService.lockFile(
              file: file,
              password: widget.password,
              inPlace: !isSandbox,
            );
            successCount++;
          }
        }
      } catch (e) {
        debugPrint('Error locking entity $path: $e');
        failCount++;
      }
    }

    Navigator.pop(context); // Dismiss loading dialog
    await _loadVaultData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Protected $successCount items successfully.${failCount > 0 ? " Failed to lock $failCount items." : ""}',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _unlockFile(VaultFileRecord record) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await VaultService.unlockFile(record: record, password: widget.password);
      Navigator.pop(context); // Dismiss loader
      await _loadVaultData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored "${record.originalName}" to its original location.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore file: $e')),
        );
      }
    }
  }

  Future<void> _deletePermanently(VaultFileRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text('Are you sure you want to permanently delete "${record.originalName}"? This action CANNOT be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final file = File(record.scrambledPath);
      if (await file.exists()) {
        await file.delete();
      }
      final records = await VaultService.loadRecords();
      records.removeWhere((e) => e.id == record.id);
      await VaultService.saveRecords(records);
      await _loadVaultData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted permanently.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete file: $e')),
        );
      }
    }
  }

  Future<void> _previewFile(VaultFileRecord record) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Decrypting securely...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final tempFile = await VaultService.decryptTemporary(
        record: record,
        password: widget.password,
      );
      Navigator.pop(context); // Dismiss loading dialog

      final path = tempFile.path;

      if (record.isFolder) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArchiveViewerScreen(archivePath: path),
          ),
        );
      } else {
        final mimeType = lookupMimeType(path) ?? '';
        final ext = p.extension(path).toLowerCase();

        if (mimeType.startsWith('image/')) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(imagePath: path)));
        } else if (mimeType.startsWith('video/')) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPlayerScreen(videoPath: path)));
        } else if (mimeType.startsWith('audio/')) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AudioPlayerScreen(
                audioPath: path,
                title: record.originalName,
              ),
            ),
          );
        } else if (FileUtils.isTextOrCode(path)) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => TextEditorScreen(filePath: path)));
        } else {
          await OpenFilex.open(path);
        }
      }

      // Cleanup temporary file safely
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    } catch (e) {
      Navigator.pop(context); // Dismiss loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decrypt and open item: $e')),
        );
      }
    }
  }

  void _showInfoDialog(VaultFileRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Broken.info_circle, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Security Details', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoTile('Original Name', record.originalName, theme),
                _buildInfoTile('Original Path', record.originalPath, theme),
                _buildInfoTile('Scrambled Path', record.scrambledPath, theme),
                _buildInfoTile('Size', FileUtils.formatBytes(record.size, 2), theme),
                _buildInfoTile('Locked At', record.lockedAt, theme),
                _buildInfoTile(
                  'Protection Mode',
                  record.isInPlace ? '⚡ In-Place Scrambling' : '🔒 Isolated Move (Sandbox)',
                  theme,
                  valueColor: record.isInPlace ? Colors.orangeAccent : Colors.greenAccent,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value, ThemeData theme, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: theme.colorScheme.onSurface.withOpacity(0.08)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0B0F19), const Color(0xFF111827), const Color(0xFF030712)]
                : [theme.colorScheme.primaryContainer.withOpacity(0.3), theme.colorScheme.surface, theme.colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Header Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Broken.arrow_left, size: 26),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Private Wallet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Broken.security_card, color: Colors.green, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Storage Overview Card
              _buildStatsCard(theme, isDark),

              // Search Box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search scrambled files...',
                    prefixIcon: const Icon(Broken.search_normal),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // Files List or Placeholder
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredRecords.isEmpty
                        ? _buildPlaceholder(theme, isDark)
                        : _buildFilesList(theme, isDark),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndLockFiles,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Broken.add_square),
        label: const Text(
          'Hide Files',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildStatsCard(ThemeData theme, bool isDark) {
    final totalBytes = _calculateTotalBytes();
    final fileCount = _records.length;
    final totalBytesFormatted = FileUtils.formatBytes(totalBytes, 2);

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [theme.colorScheme.primary.withOpacity(0.04), theme.colorScheme.primary.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.2),
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SECURITY STORAGE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalBytesFormatted,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total Space Secured',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '$fileCount',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hidden Files',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Broken.security_safe,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty ? 'No Matching Files' : 'Your Secure Vault is Empty',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try modifying your search text to locate hidden items.'
                  : 'XOR scrambled signature obfuscation keeps files completely unopenable and hidden from system scanner database. Tap "Hide Files" below to protect them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList(ThemeData theme, bool isDark) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredRecords.length,
      padding: const EdgeInsets.only(bottom: 88, left: 12, right: 12),
      itemBuilder: (context, index) {
        final rec = _filteredRecords[index];
        final fileIcon = rec.isFolder
            ? FileUtils.getFolderIcon(context.watch<FileManagerProvider>().folderIconOption)
            : FileUtils.getIconForFile(rec.originalName);
        final fileColor = rec.isFolder
            ? theme.colorScheme.primary
            : FileUtils.getColorForFile(rec.originalName, context);
        
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5.0),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.01),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.05),
              width: 1.2,
            ),
          ),
          child: ListTile(
            onTap: () => _previewFile(rec),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: fileColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                fileIcon,
                color: fileColor,
                size: 24,
              ),
            ),
            title: Text(
              rec.originalName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Text(
                    rec.isFolder ? 'Folder' : FileUtils.formatBytes(rec.size, 1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    rec.isInPlace ? Broken.flash_1 : Broken.lock,
                    size: 13,
                    color: rec.isInPlace ? Colors.orangeAccent : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rec.isInPlace ? 'In-Place' : 'Sandbox',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: rec.isInPlace ? Colors.orangeAccent : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (val) {
                if (val == 'unlock') {
                  _unlockFile(rec);
                } else if (val == 'info') {
                  _showInfoDialog(rec);
                } else if (val == 'delete') {
                  _deletePermanently(rec);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'unlock',
                  child: Row(
                    children: [
                      Icon(Broken.unlock, size: 18),
                      SizedBox(width: 10),
                      Text('Restore (Unhide)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
                      Icon(Broken.info_circle, size: 18),
                      SizedBox(width: 10),
                      Text('Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Broken.trash, size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Text(
                        'Delete Permanently',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
