import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/icon_fonts/broken_icons.dart';

class DatabaseReaderScreen extends StatefulWidget {
  final String filePath;

  const DatabaseReaderScreen({super.key, required this.filePath});

  @override
  State<DatabaseReaderScreen> createState() => _DatabaseReaderScreenState();
}

class _DatabaseReaderScreenState extends State<DatabaseReaderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Database? _db;
  bool _isLoading = true;
  String? _errorMessage;

  List<String> _tables = [];
  String? _selectedTable;

  // Browse Tab State
  List<Map<String, dynamic>> _tableRows = [];
  List<String> _tableColumns = [];
  int _limit = 50;
  int _offset = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Schema Tab State
  List<Map<String, dynamic>> _schemaColumns = [];

  // SQL Console Tab State
  final TextEditingController _sqlController = TextEditingController();
  List<Map<String, dynamic>> _sqlResultRows = [];
  List<String> _sqlResultColumns = [];
  String? _sqlErrorMessage;
  bool _isSqlRunning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initDatabase();
  }

  Future<void> _initDatabase() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Standard SQLite opening
      _db = await openDatabase(widget.filePath, readOnly: true);

      // Load tables
      final List<Map<String, dynamic>> tablesMap = await _db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name ASC;"
      );

      _tables = tablesMap.map((row) => row['name'].toString()).toList();

      if (_tables.isNotEmpty) {
        _selectedTable = _tables.first;
        await _loadTableData();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTableData() async {
    if (_db == null || _selectedTable == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Load Schema
      final List<Map<String, dynamic>> schema = await _db!.rawQuery("PRAGMA table_info('$_selectedTable');");
      _schemaColumns = schema;

      // Columns extraction
      _tableColumns = schema.map((col) => col['name'].toString()).toList();

      // Load Rows
      String query = "SELECT * FROM '$_selectedTable'";
      List<dynamic> arguments = [];

      if (_searchQuery.isNotEmpty && _tableColumns.isNotEmpty) {
        final likeClauses = _tableColumns.map((col) => "'$col' LIKE ?").join(" OR ");
        query += " WHERE $likeClauses";
        arguments = List.filled(_tableColumns.length, "%$_searchQuery%");
      }

      query += " LIMIT $_limit OFFSET $_offset;";

      final List<Map<String, dynamic>> rows = await _db!.rawQuery(query, arguments);

      setState(() {
        _tableRows = rows;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runCustomSql() async {
    if (_db == null) return;
    final sql = _sqlController.text.trim();
    if (sql.isEmpty) return;

    setState(() {
      _isSqlRunning = true;
      _sqlErrorMessage = null;
      _sqlResultRows = [];
      _sqlResultColumns = [];
    });

    try {
      final results = await _db!.rawQuery(sql);
      if (results.isNotEmpty) {
        _sqlResultColumns = results.first.keys.toList();
        _sqlResultRows = results;
      } else {
        _sqlResultRows = [];
        _sqlResultColumns = [];
      }
    } catch (e) {
      _sqlErrorMessage = e.toString();
    } finally {
      setState(() {
        _isSqlRunning = false;
      });
    }
  }

  Future<void> _exportToCsv(List<String> columns, List<Map<String, dynamic>> rows, String suffix) async {
    try {
      if (columns.isEmpty || rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data to export.')),
        );
        return;
      }

      final buffer = StringBuffer();
      // Write Header
      buffer.writeln(columns.join(','));

      // Write Rows
      for (final row in rows) {
        final rowValues = columns.map((col) {
          final val = row[col];
          if (val == null) return '';
          // Escape commas & quotes
          final valStr = val.toString().replaceAll('"', '""');
          if (valStr.contains(',') || valStr.contains('"') || valStr.contains('\n')) {
            return '"$valStr"';
          }
          return valStr;
        });
        buffer.writeln(rowValues.join(','));
      }

      // Save to downloads or documents
      final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final baseName = p.basenameWithoutExtension(widget.filePath);
      final exportFile = File('${directory.path}/${baseName}_${suffix}_export.csv');
      await exportFile.writeAsString(buffer.toString());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully exported to ${p.basename(exportFile.path)}'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  void dispose() {
    _db?.close();
    _tabController.dispose();
    _searchController.dispose();
    _sqlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.basename(widget.filePath),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'SQLite Database Reader',
              style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(text: 'Browse Data', icon: Icon(Broken.document, size: 20)),
            Tab(text: 'Table Schema', icon: Icon(Broken.info_circle, size: 20)),
            Tab(text: 'SQL Console', icon: Icon(Broken.code, size: 20)),
          ],
        ),
      ),
      body: _isLoading && _tables.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Broken.danger, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to open database',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBrowseTab(theme),
                    _buildSchemaTab(theme),
                    _buildConsoleTab(theme),
                  ],
                ),
    );
  }

  Widget _buildBrowseTab(ThemeData theme) {
    if (_tables.isEmpty) {
      return Center(
        child: Text('No tables found in this database.', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
      );
    }

    return Column(
      children: [
        // Controls bar (dropdown + search)
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTable,
                          isExpanded: true,
                          items: _tables.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Row(
                                children: [
                                  Icon(Broken.folder, size: 18, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedTable = val;
                                _offset = 0;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                              _loadTableData();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Broken.import, size: 20),
                    onPressed: () => _exportToCsv(_tableColumns, _tableRows, _selectedTable ?? 'table'),
                    tooltip: 'Export Table to CSV',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Search rows...',
                          prefixIcon: const Icon(Broken.search_normal, size: 16),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _offset = 0;
                                    });
                                    _loadTableData();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                            _offset = 0;
                          });
                          _loadTableData();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Table grid View
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tableRows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Broken.info_circle, size: 36, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                          const SizedBox(height: 8),
                          Text('No rows found', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    )
                  : Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 40,
                            dataRowMinHeight: 36,
                            dataRowMaxHeight: 48,
                            headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceVariant.withOpacity(0.4)),
                            columns: _tableColumns.map((col) {
                              return DataColumn(
                                label: Text(
                                  col,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              );
                            }).toList(),
                            rows: _tableRows.map((row) {
                              return DataRow(
                                cells: _tableColumns.map((col) {
                                  final val = row[col];
                                  return DataCell(
                                    Text(
                                      val == null ? 'NULL' : val.toString(),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: val == null ? theme.colorScheme.onSurface.withOpacity(0.3) : theme.colorScheme.onSurface,
                                        fontStyle: val == null ? FontStyle.italic : FontStyle.normal,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
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

        // Pagination Panel
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${_offset + 1} - ${_offset + _tableRows.length}',
                style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Broken.arrow_left_2, size: 18),
                    onPressed: _offset > 0
                        ? () {
                            setState(() {
                              _offset = (_offset - _limit).clamp(0, double.infinity).toInt();
                            });
                            _loadTableData();
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Broken.arrow_right_3, size: 18),
                    onPressed: _tableRows.length == _limit
                        ? () {
                            setState(() {
                              _offset += _limit;
                            });
                            _loadTableData();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSchemaTab(ThemeData theme) {
    if (_schemaColumns.isEmpty) {
      return Center(
        child: Text('No schema details loaded.', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
      );
    }

    return ListView.builder(
      itemCount: _schemaColumns.length,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, i) {
        final col = _schemaColumns[i];
        final isPk = col['pk'] == 1 || col['pk'] == true;
        final name = col['name']?.toString() ?? '';
        final type = col['type']?.toString() ?? 'TEXT';
        final notNull = col['notnull'] == 1 || col['notnull'] == true;
        final dfltValue = col['dflt_value'];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPk ? theme.colorScheme.primary.withOpacity(0.15) : theme.colorScheme.surfaceVariant,
              child: Icon(
                isPk ? Broken.key : Broken.document_text,
                color: isPk ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                if (isPk) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PK',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                ],
                if (notNull) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'NOT NULL',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Type: $type', style: TextStyle(fontSize: 12.5, color: theme.colorScheme.onSurface.withOpacity(0.7))),
                  if (dfltValue != null)
                    Text('Default: $dfltValue', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConsoleTab(ThemeData theme) {
    return Column(
      children: [
        // Editor panel
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('SQL Editor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.primary)),
                      Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: const Text('SELECT template', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              if (_selectedTable != null) {
                                _sqlController.text = "SELECT * FROM '$_selectedTable' LIMIT 10;";
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: TextField(
                    controller: _sqlController,
                    maxLines: 4,
                    minLines: 2,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter SELECT query here...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_sqlResultRows.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(Broken.import, size: 20),
                          onPressed: () => _exportToCsv(_sqlResultColumns, _sqlResultRows, 'query'),
                          tooltip: 'Export Results to CSV',
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        icon: _isSqlRunning
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Broken.play, size: 16),
                        label: const Text('Run Query', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _isSqlRunning ? null : _runCustomSql,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Error message if any
        if (_sqlErrorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Broken.danger, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _sqlErrorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Results Grid Panel
        Expanded(
          child: _isSqlRunning
              ? const Center(child: CircularProgressIndicator())
              : _sqlResultRows.isEmpty
                  ? Center(
                      child: Text(
                        _sqlErrorMessage == null ? 'Execute a SELECT query to view results.' : 'Error executing query.',
                        style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4), fontSize: 13),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            'Query returned ${_sqlResultRows.length} rows',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowHeight: 38,
                                  dataRowMinHeight: 34,
                                  dataRowMaxHeight: 46,
                                  headingRowColor: MaterialStateProperty.all(theme.colorScheme.surfaceVariant.withOpacity(0.3)),
                                  columns: _sqlResultColumns.map((col) {
                                    return DataColumn(
                                      label: Text(
                                        col,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      ),
                                    );
                                  }).toList(),
                                  rows: _sqlResultRows.map((row) {
                                    return DataRow(
                                      cells: _sqlResultColumns.map((col) {
                                        final val = row[col];
                                        return DataCell(
                                          Text(
                                            val == null ? 'NULL' : val.toString(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: val == null ? theme.colorScheme.onSurface.withOpacity(0.3) : theme.colorScheme.onSurface,
                                              fontStyle: val == null ? FontStyle.italic : FontStyle.normal,
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
                    ),
        ),
      ],
    );
  }
}
