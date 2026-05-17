import 'package:flutter/material.dart';
import '../../core/icon_fonts/broken_icons.dart';

class ArchiveCreationResult {
  final String archiveName;
  final String format;
  final int compressionLevel;
  final String? password;
  final int? splitSizeMB;
  final bool deleteSource;
  final bool separateArchives;

  ArchiveCreationResult({
    required this.archiveName,
    required this.format,
    required this.compressionLevel,
    this.password,
    this.splitSizeMB,
    required this.deleteSource,
    required this.separateArchives,
  });
}

class CreateArchiveDialog extends StatefulWidget {
  final String initialName;
  final bool isMultiSelection;

  const CreateArchiveDialog({
    super.key,
    required this.initialName,
    this.isMultiSelection = false,
  });

  static Future<ArchiveCreationResult?> show(BuildContext context, {required String initialName, bool isMultiSelection = false}) {
    return showDialog<ArchiveCreationResult>(
      context: context,
      builder: (_) => CreateArchiveDialog(initialName: initialName, isMultiSelection: isMultiSelection),
    );
  }

  @override
  State<CreateArchiveDialog> createState() => _CreateArchiveDialogState();
}

class _CreateArchiveDialogState extends State<CreateArchiveDialog> {
  late TextEditingController _nameController;
  late TextEditingController _passwordController;
  late TextEditingController _splitController;
  String _format = 'zip';
  int _compressionLevel = 6; // Standard
  bool _deleteSource = false;
  bool _separateArchives = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _passwordController = TextEditingController();
    _splitController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _splitController.dispose();
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
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Broken.archive_add, color: theme.colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Create Archive',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Archive Name
              if (!_separateArchives) ...[
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Archive Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Broken.box),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Format Selection
              DropdownButtonFormField<String>(
                value: _format,
                decoration: InputDecoration(
                  labelText: 'Archive Format',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Broken.document_code),
                ),
                items: const [
                  DropdownMenuItem(value: 'zip', child: Text('ZIP')),
                  DropdownMenuItem(value: 'tar', child: Text('TAR')),
                  DropdownMenuItem(value: 'tar.gz', child: Text('TAR.GZ')),
                  DropdownMenuItem(value: 'tar.bz2', child: Text('TAR.BZ2')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _format = val;
                      if (_format != 'zip') {
                        _passwordController.clear();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Compression Level
              Text(
                'Compression Level: ${_getCompressionLabel(_compressionLevel)}',
                style: theme.textTheme.titleSmall,
              ),
              Slider(
                value: _compressionLevel.toDouble(),
                min: 0,
                max: 9,
                divisions: 3,
                label: _getCompressionLabel(_compressionLevel),
                onChanged: (val) {
                  setState(() {
                    _compressionLevel = val.toInt();
                  });
                },
              ),
              const SizedBox(height: 8),

              // Password Protection (ZIP only)
              if (_format == 'zip') ...[
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Broken.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Broken.eye_slash : Broken.eye),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Split Size
              TextField(
                controller: _splitController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Split Volume Size in MB (Optional)',
                  helperText: 'Leave empty for single archive',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Broken.scissor),
                ),
              ),
              const SizedBox(height: 16),

              // Checkbox: Delete Source Files
              CheckboxListTile(
                value: _deleteSource,
                title: const Text('Delete source files after completion'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    _deleteSource = val ?? false;
                  });
                },
              ),

              // Checkbox: Separate Archives
              if (widget.isMultiSelection)
                CheckboxListTile(
                  value: _separateArchives,
                  title: const Text('Create separate archive for each file'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      _separateArchives = val ?? false;
                    });
                  },
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
                      final name = _nameController.text.trim();
                      if (!_separateArchives && name.isEmpty) {
                        return;
                      }
                      final int? split = int.tryParse(_splitController.text.trim());

                      Navigator.pop(
                        context,
                        ArchiveCreationResult(
                          archiveName: name.isEmpty ? 'archive' : name,
                          format: _format,
                          compressionLevel: _compressionLevel,
                          password: _passwordController.text.isNotEmpty ? _passwordController.text : null,
                          splitSizeMB: (split != null && split > 0) ? split : null,
                          deleteSource: _deleteSource,
                          separateArchives: _separateArchives,
                        ),
                      );
                    },
                    child: const Text('Create Archive'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCompressionLabel(int level) {
    if (level == 0) return 'None (Store)';
    if (level == 3) return 'Fast';
    if (level == 6) return 'Standard';
    return 'Maximum';
  }
}
