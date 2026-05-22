import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../services/ftp_server_service.dart';
import 'internal_file_picker_screen.dart';

class FtpServerScreen extends StatefulWidget {
  const FtpServerScreen({super.key});

  @override
  State<FtpServerScreen> createState() => _FtpServerScreenState();
}

class _FtpServerScreenState extends State<FtpServerScreen> {
  final _ftpService = FtpServerService.instance;
  bool _ftpesEnabled = false;

  @override
  void initState() {
    super.initState();
    _ftpService.onStatusChanged = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  @override
  void dispose() {
    // Reset status callback to prevent memory leak
    _ftpService.onStatusChanged = null;
    super.dispose();
  }

  Future<void> _toggleServer() async {
    if (_ftpService.isActive) {
      _ftpService.stop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FTP Server stopped successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Prompt for Notification permission as noted by user
      try {
        await Permission.notification.request();
      } catch (_) {}

      try {
        await _ftpService.start();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('FTP Server started at ftp://${_ftpService.ipAddress}:${_ftpService.port}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting FTP Server: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickHomeDirectory() async {
    if (_ftpService.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please stop the server before changing configuration'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final picked = await InternalFilePickerScreen.show(
      context,
      rootPath: _ftpService.homeDir,
      pickDirectory: true,
    );

    if (picked != null && picked.isNotEmpty) {
      _ftpService.configure(homeDir: picked.first);
      setState(() {});
    }
  }

  void _showPortDialog() {
    if (_ftpService.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please stop the server before changing configuration'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = TextEditingController(text: _ftpService.port.toString());
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Change Port', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Port Number',
              hintText: 'e.g., 9999',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final port = int.tryParse(controller.text);
                if (port != null && port > 0 && port < 65536) {
                  _ftpService.configure(port: port);
                  Navigator.pop(context);
                  setState(() {});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid port number')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showUserDialog() {
    if (_ftpService.isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please stop the server before changing configuration'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final controller = TextEditingController(text: _ftpService.username);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Set Username', style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Username',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  _ftpService.configure(username: controller.text.trim(), anonymous: false);
                  Navigator.pop(context);
                  setState(() {});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username cannot be empty')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isActive = _ftpService.isActive;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'FTP Server',
          style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              switch (value) {
                case 'cwd':
                  _pickHomeDirectory();
                  break;
                case 'port':
                  _showPortDialog();
                  break;
                case 'user':
                  _showUserDialog();
                  break;
                case 'anon':
                  if (_ftpService.isActive) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stop the server before editing settings')),
                    );
                    return;
                  }
                  _ftpService.configure(
                    anonymous: !_ftpService.anonymous,
                    username: !_ftpService.anonymous ? 'Anonymous' : 'admin',
                  );
                  setState(() {});
                  break;
                case 'shortcut':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('FTP Server shortcut added to home screen!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'cwd',
                child: Row(
                  children: [
                    Icon(Broken.folder, size: 18),
                    SizedBox(width: 10),
                    Text('Change directory'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'port',
                child: Row(
                  children: [
                    Icon(Icons.numbers_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Change port'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'user',
                child: Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Set user'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'anon',
                child: Row(
                  children: [
                    Icon(
                      _ftpService.anonymous ? Icons.check_box : Icons.check_box_outline_blank,
                      size: 18,
                      color: _ftpService.anonymous ? theme.colorScheme.primary : null,
                    ),
                    const SizedBox(width: 10),
                    const Text('Anonymous access'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'shortcut',
                child: Row(
                  children: [
                    Icon(Icons.add_to_home_screen_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Create shortcut'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Active/Inactive Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isActive ? Colors.teal : Colors.amber,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isActive ? Colors.teal : Colors.amber).withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Network status',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                                ),
                                const Text(
                                  'Connected',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Server address',
                                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
                                ),
                                SelectableText(
                                  'ftp://${_ftpService.ipAddress}:${_ftpService.port}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Settings Card
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.surfaceVariant.withOpacity(0.3) : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
                        ),
                        child: Column(
                          children: [
                            // Home Directory Field
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                              child: InkWell(
                                onTap: _pickHomeDirectory,
                                borderRadius: BorderRadius.circular(16),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Home directory',
                                    labelStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    suffixIcon: const Icon(Broken.folder),
                                  ),
                                  child: Text(
                                    _ftpService.homeDir,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ),

                            // User Name Row
                            ListTile(
                              title: const Text('User name', style: TextStyle(fontWeight: FontWeight.w500)),
                              trailing: Text(
                                _ftpService.anonymous ? 'Anonymous' : _ftpService.username,
                                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.bold),
                              ),
                              onTap: _showUserDialog,
                            ),

                            // Show Hidden Files Row
                            SwitchListTile(
                              title: const Text('Show hidden files', style: TextStyle(fontWeight: FontWeight.w500)),
                              value: _ftpService.showHidden,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (val) {
                                _ftpService.configure(showHidden: val);
                                setState(() {});
                              },
                            ),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Divider(color: theme.colorScheme.onSurface.withOpacity(0.08)),
                            ),

                             // FTPES Row
                             SwitchListTile(
                               title: const Text('FTPES', style: TextStyle(fontWeight: FontWeight.w500)),
                               subtitle: const Text('Secure FTP connection over explicit TLS', style: TextStyle(fontSize: 11.5)),
                               value: _ftpesEnabled,
                               activeColor: theme.colorScheme.primary,
                               onChanged: (val) {
                                 setState(() {
                                   _ftpesEnabled = val;
                                 });
                               },
                             ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Start/Stop Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _toggleServer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.redAccent.shade200 : theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  child: Text(
                    isActive ? 'Stop' : 'Start',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
