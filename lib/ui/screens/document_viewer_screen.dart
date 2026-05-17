import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:xml/xml.dart';
import '../../core/icon_fonts/broken_icons.dart';

class DocumentViewerScreen extends StatefulWidget {
  final String filePath;

  const DocumentViewerScreen({super.key, required this.filePath});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  String get _fileName => widget.filePath.split('/').last;
  String get _ext =>
      _fileName.contains('.')
          ? _fileName.substring(_fileName.lastIndexOf('.')).toLowerCase()
          : '';

  bool get _isPdf => _ext == '.pdf';
  bool get _isWord => _ext == '.doc' || _ext == '.docx';
  bool get _isExcel => _ext == '.xls' || _ext == '.xlsx';
  bool get _isPpt => _ext == '.ppt' || _ext == '.pptx';

  bool get _isText =>
      _ext == '.txt' ||
      _ext == '.csv' ||
      _ext == '.rtf' ||
      _ext == '.log' ||
      _ext == '.md';

  String _textContent = '';
  final Map<String, List<List<dynamic>>> _excelSheets = {};
  String _selectedSheet = '';
  List<String> _pptSlides = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    if (_isText) {
      _loadTextFile();
    } else if (_isWord) {
      _loadWordFile();
    } else if (_isExcel) {
      _loadExcelFile();
    } else if (_isPpt) {
      _loadPptFile();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadTextFile() async {
    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _textController.text = content;
        _textContent = content;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWordFile() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final text = docxToText(bytes);
      _textContent = text;
      _textController.text = text;
    } catch (e) {
      debugPrint('Error reading Word: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadExcelFile() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final excel = excel_pkg.Excel.decodeBytes(bytes);

      _excelSheets.clear();
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table]!;
        final List<List<dynamic>> rows = [];
        for (final row in sheet.rows) {
          final List<dynamic> rowData = [];
          for (final cell in row) {
            rowData.add(cell?.value?.toString() ?? '');
          }
          rows.add(rowData);
        }
        _excelSheets[table] = rows;
      }
      if (_excelSheets.isNotEmpty) {
        _selectedSheet = _excelSheets.keys.first;
      }
    } catch (e) {
      debugPrint('Error reading Excel: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPptFile() async {
    try {
      final file = File(widget.filePath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final slideMap = <int, String>{};

      for (final file in archive.files) {
        if (file.name.startsWith('ppt/slides/slide') && file.name.endsWith('.xml')) {
          final match = RegExp(r'slide(\d+)\.xml').firstMatch(file.name);
          if (match != null) {
            final slideNum = int.parse(match.group(1)!);
            final contentStr = utf8.decode(file.content as List<int>);
            final doc = XmlDocument.parse(contentStr);
            final textNodes = doc.findAllElements('a:t');
            final slideText = textNodes.map((node) => node.innerText).where((t) => t.trim().isNotEmpty).join('\n');
            slideMap[slideNum] = slideText.isEmpty ? '(Empty Slide)' : slideText;
          }
        }
      }

      final sortedKeys = slideMap.keys.toList()..sort();
      _pptSlides = sortedKeys.map((k) => slideMap[k]!).toList();
    } catch (e) {
      debugPrint('Error reading PPTX: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveFile() async {
    setState(() => _isSaving = true);
    try {
      final file = File(widget.filePath);
      await file.writeAsString(_textController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved successfully ✓'),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openExternal() async {
    await OpenFilex.open(widget.filePath);
  }

  IconData get _fileIcon {
    switch (_ext) {
      case '.pdf':
        return Broken.document;
      case '.doc':
      case '.docx':
        return Broken.document_text;
      case '.xls':
      case '.xlsx':
        return Broken.document_text;
      case '.ppt':
      case '.pptx':
        return Broken.presention_chart;
      case '.txt':
      case '.md':
        return Broken.note_2;
      default:
        return Broken.document;
    }
  }

  Color get _fileColor {
    switch (_ext) {
      case '.pdf':
        return Colors.redAccent;
      case '.doc':
      case '.docx':
        return Colors.blueAccent;
      case '.xls':
      case '.xlsx':
        return Colors.green;
      case '.ppt':
      case '.pptx':
        return Colors.orangeAccent;
      case '.txt':
      case '.md':
        return Colors.purpleAccent;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _fileName,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isText) ...[
            if (_isEditing) ...[
              if (_isSaving)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save_rounded),
                  onPressed: _saveFile,
                  tooltip: 'Save',
                ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _textController.text = _textContent;
                  });
                },
                tooltip: 'Cancel',
              ),
            ] else
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => setState(() => _isEditing = true),
                tooltip: 'Edit',
              ),
          ],
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openExternal,
            tooltip: 'Open with',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isText
              ? _buildTextViewer(theme, isDark)
              : _isWord
                  ? _buildWordViewer(theme, isDark)
                  : _isExcel
                      ? _buildExcelViewer(theme, isDark)
                      : _isPpt
                          ? _buildPptViewer(theme, isDark)
                          : _isPdf
                              ? _buildPdfViewer(theme, isDark)
                              : _buildDocumentPreview(theme, isDark),
    );
  }

  Widget _buildPdfViewer(ThemeData theme, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF9F9FF),
      child: SfPdfViewer.file(
        File(widget.filePath),
        canShowScrollHead: true,
        canShowScrollStatus: true,
        canShowPaginationDialog: true,
      ),
    );
  }

  Widget _buildWordViewer(ThemeData theme, bool isDark) {
    if (_textContent.isEmpty) return _buildDocumentPreview(theme, isDark);

    return Container(
      color: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF9F9FF),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SelectableText(
            _textContent,
            style: TextStyle(
              fontSize: 15,
              height: 1.8,
              color: isDark ? Colors.white : const Color(0xFF2B2B36),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExcelViewer(ThemeData theme, bool isDark) {
    if (_excelSheets.isEmpty) return _buildDocumentPreview(theme, isDark);

    final rows = _excelSheets[_selectedSheet] ?? [];

    return Column(
      children: [
        if (_excelSheets.length > 1)
          Container(
            height: 50,
            color: theme.colorScheme.surface,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _excelSheets.keys.length,
              itemBuilder: (context, index) {
                final sheetName = _excelSheets.keys.elementAt(index);
                final isSelected = sheetName == _selectedSheet;
                return InkWell(
                  onTap: () => setState(() => _selectedSheet = sheetName),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Colors.green : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(
                      sheetName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('Empty Sheet'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Table(
                        border: TableBorder.all(
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                          width: 1,
                        ),
                        defaultColumnWidth: const IntrinsicColumnWidth(),
                        children: rows.map((row) {
                          final isHeader = rows.indexOf(row) == 0;
                          return TableRow(
                            decoration: BoxDecoration(
                              color: isHeader
                                  ? Colors.green.withOpacity(0.15)
                                  : (rows.indexOf(row) % 2 == 0
                                      ? theme.colorScheme.surface.withOpacity(0.5)
                                      : Colors.transparent),
                            ),
                            children: row.map((cell) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  cell.toString(),
                                  style: TextStyle(
                                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPptViewer(ThemeData theme, bool isDark) {
    if (_pptSlides.isEmpty) return _buildDocumentPreview(theme, isDark);

    return Container(
      color: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF9F9FF),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: _pptSlides.length,
        itemBuilder: (context, index) {
          final slideText = _pptSlides[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SLIDE ${index + 1}',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 12,
                      ),
                    ),
                    const Icon(Broken.presention_chart, color: Colors.orangeAccent, size: 20),
                  ],
                ),
                const Divider(height: 24),
                SelectableText(
                  slideText,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: isDark ? Colors.white : const Color(0xFF2B2B36),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextViewer(ThemeData theme, bool isDark) {
    if (_isEditing) {
      return Container(
        color: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF9F9FF),
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _textController,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            filled: true,
            fillColor: isDark ? const Color(0xFF121220) : Colors.white,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      );
    }

    return Container(
      color: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF9F9FF),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _textController.text.isEmpty ? '(Empty file)' : _textController.text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentPreview(ThemeData theme, bool isDark) {
    final fileColor = _fileColor;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: fileColor.withOpacity(0.3), width: 1.5),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_fileIcon, color: fileColor, size: 48),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: fileColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _ext.toUpperCase().replaceAll('.', ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            _fileName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          FutureBuilder<FileStat>(
            future: FileStat.stat(widget.filePath),
            builder: (context, snap) {
              if (snap.hasData) {
                final size = snap.data!.size;
                final sizeStr = size < 1024
                    ? '$size B'
                    : size < 1024 * 1024
                        ? '${(size / 1024).toStringAsFixed(1)} KB'
                        : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
                return Text(
                  sizeStr,
                  style: TextStyle(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 13,
                  ),
                );
              }
              return const SizedBox();
            },
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open with App'),
              style: FilledButton.styleFrom(
                backgroundColor: fileColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openExternal,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.share, color: fileColor),
              label: Text('Share', style: TextStyle(color: fileColor)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: fileColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share coming soon')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
