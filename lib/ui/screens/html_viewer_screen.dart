import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:path/path.dart' as p;
import '../../core/icon_fonts/broken_icons.dart';

class HtmlViewerScreen extends StatefulWidget {
  final String filePath;

  const HtmlViewerScreen({super.key, required this.filePath});

  @override
  State<HtmlViewerScreen> createState() => _HtmlViewerScreenState();
}

class _HtmlViewerScreenState extends State<HtmlViewerScreen> {
  String _htmlContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        _htmlContent = await file.readAsString();
      } else {
        _htmlContent = '<p>File not found.</p>';
      }
    } catch (e) {
      _htmlContent = '<p>Error loading HTML: $e</p>';
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
            Text('HTML Preview', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Broken.refresh_2),
            tooltip: 'Reload',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadHtml();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: HtmlWidget(
                _htmlContent,
                textStyle: theme.textTheme.bodyMedium,
              ),
            ),
    );
  }
}
