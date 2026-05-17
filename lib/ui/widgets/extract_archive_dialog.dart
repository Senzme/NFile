import 'package:flutter/material.dart';
import '../../core/icon_fonts/broken_icons.dart';

class ExtractArchiveResult {
  final String destinationDir;
  final String? password;

  ExtractArchiveResult({required this.destinationDir, this.password});
}

class ExtractArchiveDialog extends StatefulWidget {
  final String archiveName;
  final String defaultDestDir;

  const ExtractArchiveDialog({
    super.key,
    required this.archiveName,
    required this.defaultDestDir,
  });

  static Future<ExtractArchiveResult?> show(BuildContext context, {required String archiveName, required String defaultDestDir}) {
    return showDialog<ExtractArchiveResult>(
      context: context,
      builder: (_) => ExtractArchiveDialog(archiveName: archiveName, defaultDestDir: defaultDestDir),
    );
  }

  @override
  State<ExtractArchiveDialog> createState() => _ExtractArchiveDialogState();
}

class _ExtractArchiveDialogState extends State<ExtractArchiveDialog> {
  late TextEditingController _destController;
  late TextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _destController = TextEditingController(text: widget.defaultDestDir);
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _destController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Broken.archive, color: theme.colorScheme.secondary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extract Archive',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.archiveName,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Destination
              TextField(
                controller: _destController,
                decoration: InputDecoration(
                  labelText: 'Extract to Folder',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Broken.folder_open),
                ),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password (if encrypted)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Broken.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Broken.eye_slash : Broken.eye),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      final dest = _destController.text.trim();
                      if (dest.isEmpty) return;

                      Navigator.pop(
                        context,
                        ExtractArchiveResult(
                          destinationDir: dest,
                          password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
                        ),
                      );
                    },
                    child: const Text('Extract'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
