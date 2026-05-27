import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';

class BatchRenameDialog extends StatefulWidget {
  final FileManagerProvider provider;
  final List<String> selectedPaths;

  const BatchRenameDialog({
    super.key,
    required this.provider,
    required this.selectedPaths,
  });

  static Future<void> show(BuildContext context, FileManagerProvider provider) {
    if (provider.selectedPaths.isEmpty) return Future.value();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => BatchRenameDialog(
        provider: provider,
        selectedPaths: List<String>.from(provider.selectedPaths),
      ),
    );
  }

  @override
  State<BatchRenameDialog> createState() => _BatchRenameDialogState();
}

class _BatchRenameDialogState extends State<BatchRenameDialog> {
  final _patternController = TextEditingController();
  final _extensionController = TextEditingController();
  final _paddingController = TextEditingController(text: '0');
  final _startController = TextEditingController(text: '1');
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();

  bool _isMoreExpanded = false;
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    // Default the extension field if all selected files are files (not directories)
    // and have the same extension. If they differ or include directories, keep it blank.
    if (widget.selectedPaths.isNotEmpty) {
      final firstPath = widget.selectedPaths.first;
      final firstExt = p.extension(firstPath);
      bool allSame = true;
      for (final path in widget.selectedPaths) {
        if (FileSystemEntity.isDirectorySync(path) || p.extension(path) != firstExt) {
          allSame = false;
          break;
        }
      }
      if (allSame && firstExt.isNotEmpty) {
        // Strip the leading dot for cleaner display in the suffix input box
        _extensionController.text = firstExt.startsWith('.') ? firstExt.substring(1) : firstExt;
      }
    }

    // Add listeners to trigger state updates for live preview
    _patternController.addListener(_onInputChanged);
    _extensionController.addListener(_onInputChanged);
    _paddingController.addListener(_onInputChanged);
    _startController.addListener(_onInputChanged);
    _findController.addListener(_onInputChanged);
    _replaceController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _patternController.dispose();
    _extensionController.dispose();
    _paddingController.dispose();
    _startController.dispose();
    _findController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  void _insertPlaceholder(String placeholder) {
    final text = _patternController.text;
    final selection = _patternController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start >= 0) {
      final newText = text.replaceRange(start, end, placeholder);
      _patternController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + placeholder.length),
      );
    } else {
      _patternController.text = text + placeholder;
    }
  }

  String _computeNewName(String path, int index) {
    final isDir = FileSystemEntity.isDirectorySync(path);
    final originalNameWithExt = p.basename(path);
    final originalName = isDir ? originalNameWithExt : p.basenameWithoutExtension(path);
    final originalExt = isDir ? '' : p.extension(path);

    // 1. Find and Replace on original name if Find is not empty
    String processedOriginalName = originalName;
    final findText = _findController.text;
    final replaceText = _replaceController.text;
    if (findText.isNotEmpty) {
      processedOriginalName = originalName.replaceAll(findText, replaceText);
    }

    // 2. Parse sequential numbering parameters
    final start = int.tryParse(_startController.text) ?? 1;
    final padding = int.tryParse(_paddingController.text) ?? 0;
    final currentNumber = start + index;
    final numberStr = currentNumber.toString().padLeft(padding, '0');

    // 3. Format with pattern
    String pattern = _patternController.text;
    String newBaseName = pattern;

    if (newBaseName.isEmpty) {
      newBaseName = processedOriginalName;
    }

    // Replace original name placeholder %
    newBaseName = newBaseName.replaceAll('%', processedOriginalName);

    // Replace advanced placeholders
    newBaseName = newBaseName.replaceAll('{n}', processedOriginalName);
    newBaseName = newBaseName.replaceAll('{de}', originalExt);
    newBaseName = newBaseName.replaceAll('{e}', originalExt.startsWith('.') ? originalExt.substring(1) : originalExt);
    newBaseName = newBaseName.replaceAll('{N}', processedOriginalName + originalExt);

    // Replace sequential numbering placeholder #
    if (newBaseName.contains('#')) {
      final reg = RegExp(r'#+');
      newBaseName = newBaseName.replaceAllMapped(reg, (match) => numberStr);
    } else {
      // Automatic sequential numbering if no placeholder is specified
      // but a custom name (not just keeping original %) is typed
      final hasPlaceholders = pattern.contains('#') || 
                              pattern.contains('%') || 
                              pattern.contains('{n}') || 
                              pattern.contains('{de}') || 
                              pattern.contains('{e}') || 
                              pattern.contains('{N}');
      if (pattern.isNotEmpty && !hasPlaceholders) {
        newBaseName = '$newBaseName ($currentNumber)';
      }
    }

    // 4. Apply extension (only to files, directories don't have extensions)
    if (isDir) {
      return newBaseName;
    } else {
      final customExt = _extensionController.text.trim();
      if (customExt.isEmpty) {
        // If the pattern already contains extension placeholders, don't double-append
        final hasPatternExt = pattern.contains('{de}') || 
                              pattern.contains('{e}') || 
                              pattern.contains('{N}');
        if (hasPatternExt) {
          return newBaseName;
        }
        return newBaseName + originalExt;
      } else {
        final finalExt = customExt.startsWith('.') ? customExt : '.$customExt';
        return newBaseName + finalExt;
      }
    }
  }

  Future<void> _executeRename() async {
    setState(() {
      _isRenaming = true;
    });

    try {
      for (int i = 0; i < widget.selectedPaths.length; i++) {
        final oldPath = widget.selectedPaths[i];
        final newName = _computeNewName(oldPath, i);
        if (newName.isNotEmpty && newName != p.basename(oldPath)) {
          await widget.provider.renameFile(oldPath, newName);
        }
      }
      widget.provider.clearSelection();
    } catch (e) {
      debugPrint('Error in batch rename: $e');
    } finally {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: size.width * 0.9,
          constraints: BoxConstraints(maxHeight: size.height * 0.85),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: _isRenaming
                ? _buildRenamingState(theme)
                : _buildDialogContent(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildRenamingState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3.5,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Renaming files...',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait, updating folder content',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Broken.edit,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batch Rename',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Configuring ${widget.selectedPaths.length} items',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Preview Box
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: widget.selectedPaths.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withOpacity(0.06),
                  ),
                  itemBuilder: (context, index) {
                    final path = widget.selectedPaths[index];
                    final isDir = FileSystemEntity.isDirectorySync(path);
                    final origName = p.basename(path);
                    final previewName = _computeNewName(path, index);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            isDir ? Broken.folder : Broken.document,
                            size: 18,
                            color: isDir
                                ? Colors.amber.shade700
                                : theme.colorScheme.primary.withOpacity(0.7),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Text(
                              origName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                          ),
                          Expanded(
                            flex: 6,
                            child: Text(
                              previewName.isEmpty ? '(empty)' : previewName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: previewName.isEmpty
                                    ? Colors.redAccent
                                    : theme.colorScheme.primary,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // More Panel shortcut buttons
            if (_isMoreExpanded) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildShortcutButton(
                    icon: Icons.copy_rounded,
                    label: '% (Name)',
                    tooltip: 'Original name (%)',
                    onTap: () => _insertPlaceholder('%'),
                    theme: theme,
                  ),
                  _buildShortcutButton(
                    icon: Icons.format_list_numbered_rounded,
                    label: '# (Num)',
                    tooltip: 'Sequential number (#)',
                    onTap: () => _insertPlaceholder('#'),
                    theme: theme,
                  ),
                  _buildShortcutButton(
                    icon: Icons.numbers_rounded,
                    label: '### (001)',
                    tooltip: 'Triple sequential number (###)',
                    onTap: () => _insertPlaceholder('###'),
                    theme: theme,
                  ),
                  _buildShortcutButton(
                    icon: Icons.abc_rounded,
                    label: '{n} (Base)',
                    tooltip: 'File name without extension ({n})',
                    onTap: () => _insertPlaceholder('{n}'),
                    theme: theme,
                  ),
                  _buildShortcutButton(
                    icon: Icons.extension_rounded,
                    label: '{de} (.ext)',
                    tooltip: 'Extension with dot ({de})',
                    onTap: () => _insertPlaceholder('{de}'),
                    theme: theme,
                  ),
                  _buildShortcutButton(
                    icon: Icons.extension_off_rounded,
                    label: '{e} (ext)',
                    tooltip: 'Extension without dot ({e})',
                    onTap: () => _insertPlaceholder('{e}'),
                    theme: theme,
                  ),
                  _buildShortcutButton(
                    icon: Icons.note_rounded,
                    label: '{N} (Full)',
                    tooltip: 'Full name with extension ({N})',
                    onTap: () => _insertPlaceholder('{N}'),
                    theme: theme,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Input Fields: Pattern & Extension
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _patternController,
                    decoration: InputDecoration(
                      labelText: 'Name Pattern',
                      hintText: 'e.g. Image_#',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: Icon(Broken.edit, size: 20, color: theme.colorScheme.primary.withOpacity(0.6)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '.',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _extensionController,
                    decoration: InputDecoration(
                      labelText: 'Extension',
                      hintText: 'txt',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // More Options Expandable Panel
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Numbering fields row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _paddingController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Padding',
                              hintText: 'e.g. 3',
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Start Number',
                              hintText: 'e.g. 1',
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Find and Replace fields row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _findController,
                            decoration: InputDecoration(
                              labelText: 'Find text',
                              hintText: 'Search term',
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _replaceController,
                            decoration: InputDecoration(
                              labelText: 'Replace with',
                              hintText: 'Replacement',
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              crossFadeState: _isMoreExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
            const SizedBox(height: 12),

            // Dialog Actions: Expand Settings & Confirm Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isMoreExpanded = !_isMoreExpanded;
                        });
                      },
                      icon: Icon(
                        _isMoreExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                      ),
                      label: Text(_isMoreExpanded ? 'Less Options' : 'More Options'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showFullPreviewSheet,
                      icon: const Icon(Broken.eye, size: 16),
                      label: const Text('Preview'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton(
                      onPressed: _executeRename,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullPreviewSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rename Preview',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reviewing ${widget.selectedPaths.length} items',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.55),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: widget.selectedPaths.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final path = widget.selectedPaths[index];
                      final isDir = FileSystemEntity.isDirectorySync(path);
                      final origName = p.basename(path);
                      final previewName = _computeNewName(path, index);

                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: theme.colorScheme.surface.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.12),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isDir ? Broken.folder : Broken.document,
                                    size: 16,
                                    color: isDir
                                        ? Colors.amber.shade700
                                        : theme.colorScheme.primary.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      origName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      previewName.isEmpty ? '(empty)' : previewName,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: previewName.isEmpty
                                            ? Colors.redAccent
                                            : theme.colorScheme.primary,
                                        fontSize: 14.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Back to Edit',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx); // Close sheet
                            _executeRename(); // Execute
                          },
                          child: const Text(
                            'Apply Changes',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
