import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import '../../core/icon_fonts/broken_icons.dart';

class MarkdownViewerScreen extends StatefulWidget {
  final String filePath;

  const MarkdownViewerScreen({super.key, required this.filePath});

  @override
  State<MarkdownViewerScreen> createState() => _MarkdownViewerScreenState();
}

class _MarkdownViewerScreenState extends State<MarkdownViewerScreen> {
  String _markdownContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMarkdown();
  }

  Future<void> _loadMarkdown() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        _markdownContent = await file.readAsString();
      } else {
        _markdownContent = '# File not found';
      }
    } catch (e) {
      _markdownContent = '# Error loading file\n\n`$e`';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.basename(widget.filePath), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Markdown Preview', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Broken.refresh_2),
            tooltip: 'Reload',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadMarkdown();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Markdown(
              data: _markdownContent,
              selectable: true,
              physics: const BouncingScrollPhysics(),
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                h2: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                code: TextStyle(fontFamily: 'monospace', backgroundColor: theme.colorScheme.surfaceContainerHighest),
                codeblockDecoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }
}
