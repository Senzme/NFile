import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../services/root_shizuku_service.dart';
import '../../core/icon_fonts/broken_icons.dart';
import 'package:flutter/services.dart';

class BreadcrumbSegment {
  final String name;
  final String path;
  BreadcrumbSegment({required this.name, required this.path});
}

class NFileAddressBar extends StatefulWidget {
  const NFileAddressBar({super.key});

  @override
  State<NFileAddressBar> createState() => _NFileAddressBarState();
}

class _NFileAddressBarState extends State<NFileAddressBar> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  final ScrollController _breadcrumbsScrollController = ScrollController();
  
  OverlayEntry? _overlayEntry;
  bool _isEditing = false;
  List<FileSystemEntity> _suggestions = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _hideSuggestionsDropdown();
    _focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _controller.dispose();
    _breadcrumbsScrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      setState(() {
        _isEditing = false;
      });
      _hideSuggestionsDropdown();
    }
  }

  void _startEditing() {
    final provider = context.read<FileManagerProvider>();
    setState(() {
      _isEditing = true;
      _controller.text = provider.currentPath;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
        _showSuggestionsDropdown();
        _fetchSuggestions();
      }
    });
  }

  void _stopEditing() {
    _focusNode.unfocus();
    setState(() {
      _isEditing = false;
    });
    _hideSuggestionsDropdown();
  }

  void _onTextChanged() {
    if (_focusNode.hasFocus) {
      _fetchSuggestions();
    }
  }

  // --- Breadcrumbs Parser ---
  List<BreadcrumbSegment> _getBreadcrumbs(String path, List<StorageVolume> volumes) {
    final List<BreadcrumbSegment> list = [];
    
    // Find matched storage volume prefix
    StorageVolume? matchedVol;
    for (final vol in volumes) {
      if (path == vol.path || path.startsWith(vol.path + '/')) {
        if (matchedVol == null || vol.path.length > matchedVol.path.length) {
          matchedVol = vol;
        }
      }
    }

    if (matchedVol != null) {
      list.add(BreadcrumbSegment(name: matchedVol.name, path: matchedVol.path));
      final relative = path.substring(matchedVol.path.length);
      if (relative.isNotEmpty) {
        final parts = relative.split('/').where((e) => e.isNotEmpty).toList();
        String current = matchedVol.path;
        for (final part in parts) {
          current = p.join(current, part);
          list.add(BreadcrumbSegment(name: part, path: current));
        }
      }
    } else {
      // Fallback: Absolute path segments
      list.add(BreadcrumbSegment(name: 'Root', path: '/'));
      final parts = path.split('/').where((e) => e.isNotEmpty).toList();
      String current = '';
      for (final part in parts) {
        current = '$current/$part';
        list.add(BreadcrumbSegment(name: part, path: current));
      }
    }
    return list;
  }

  // --- Dynamic Suggestions Engine ---
  Future<void> _fetchSuggestions() async {
    final provider = context.read<FileManagerProvider>();
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _suggestions = provider.storageVolumes.map((v) => Directory(v.path)).toList();
        _isLoadingSuggestions = false;
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    String parentPath;
    String query;

    if (input.endsWith('/')) {
      parentPath = input.substring(0, input.length - 1);
      query = '';
      if (parentPath.isEmpty) parentPath = '/';
    } else {
      // Check if input is a valid existing directory path
      final isDir = await Directory(input).exists();
      if (isDir) {
        parentPath = input;
        query = '';
      } else {
        parentPath = p.dirname(input);
        query = p.basename(input).toLowerCase();
      }
    }

    List<FileSystemEntity> results = [];
    try {
      if (provider.isRestrictedPath(parentPath)) {
        final items = await RootShizukuService.listFiles(
          parentPath,
          useRoot: provider.useRootMode,
          showHiddenFiles: provider.showHiddenFiles,
        );
        for (final item in items) {
          final name = p.basename(item.path);
          if (query.isEmpty || name.toLowerCase().startsWith(query)) {
            results.add(item.isDirectory ? Directory(item.path) : File(item.path));
          }
        }
      } else {
        final dir = Directory(parentPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: false, followLinks: false)) {
            final name = p.basename(entity.path);
            final isHidden = name.startsWith('.');
            if (!provider.showHiddenFiles && isHidden) {
              continue;
            }
            if (query.isEmpty || name.toLowerCase().startsWith(query)) {
              results.add(entity);
            }
          }
        }
      }

      // Sort folders first, then files
      results.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
      });

    } catch (e) {
      debugPrint('Suggestions query error: $e');
    }

    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoadingSuggestions = false;
      });
      _overlayEntry?.markNeedsBuild();
    }
  }

  // --- Show Overlay Dropdown ---
  void _showSuggestionsDropdown() {
    _hideSuggestionsDropdown();
    final provider = context.read<FileManagerProvider>();
    
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        final size = MediaQuery.of(context).size;
        
        return Positioned(
          width: _layerLink.leaderSize?.width ?? size.width - 32,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 52), // Float directly under the address bar container
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(16),
              color: theme.colorScheme.surface.withOpacity(0.95),
              shadowColor: Colors.black.withOpacity(0.4),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: (size.height * 0.35).clamp(150.0, 300.0),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isLoadingSuggestions
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      : _suggestions.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Text(
                                'No matching directories or files found',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final entity = _suggestions[index];
                                final isDir = entity is Directory;
                                final name = p.basename(entity.path);
                                final fullPath = entity.path;

                                final matchedVol = provider.storageVolumes.firstWhere(
                                  (v) => v.path == fullPath,
                                  orElse: () => StorageVolume(name: '', path: '', isInternal: false),
                                );
                                final displayName = matchedVol.name.isNotEmpty 
                                    ? matchedVol.name 
                                    : (name.isEmpty ? '/' : name);

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    isDir ? Broken.folder : Broken.document,
                                    size: 20,
                                    color: isDir ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    fullPath,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    if (isDir) {
                                      // Tapping a directory suggestion autocompletes the text input
                                      final autocompleted = '$fullPath/';
                                      _controller.text = autocompleted;
                                      _controller.selection = TextSelection.fromPosition(
                                        TextPosition(offset: autocompleted.length),
                                      );
                                      _focusNode.requestFocus(); // Keep focus to allow further diving
                                    } else {
                                      // Tapping a file suggestion closes editor and opens file natively!
                                      _stopEditing();
                                      provider.openFileNatively(context, fullPath);
                                    }
                                  },
                                );
                              },
                            ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestionsDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // --- Go Button & Submitting Navigation ---
  void _submitNavigation() async {
    final path = _controller.text.trim();
    if (path.isEmpty) return;

    final provider = context.read<FileManagerProvider>();
    _focusNode.unfocus();

    // Check if the path exists
    final isDir = await Directory(path).exists();
    if (isDir) {
      provider.loadDirectory(path);
    } else {
      final isFile = await File(path).exists();
      if (isFile) {
        provider.openFileNatively(context, path);
      } else {
        // Restructured path check for restricted mode folders
        if (provider.isRestrictedPath(path)) {
          provider.loadDirectory(path);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Path not found: $path'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<FileManagerProvider>();
    final breadcrumbs = _getBreadcrumbs(provider.currentPath, provider.storageVolumes);

    // Auto-scroll breadcrumbs list to the end on path change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbsScrollController.hasClients && !_isEditing) {
        _breadcrumbsScrollController.animateTo(
          _breadcrumbsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isEditing ? theme.colorScheme.primary.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1),
            width: _isEditing ? 1.5 : 1.0,
          ),
          boxShadow: _isEditing
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Left Edit/Breadcrumb Action Toggle
            IconButton(
              icon: Icon(
                _isEditing ? Broken.arrow_left : Broken.edit,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              onPressed: () {
                if (_isEditing) {
                  _stopEditing();
                } else {
                  _startEditing();
                }
              },
            ),
            
            // Editable Input or Segment Breadcrumbs list
            Expanded(
              child: _isEditing
                  ? TextField(
                      focusNode: _focusNode,
                      controller: _controller,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        hintText: 'Enter absolute path...',
                      ),
                      textInputAction: TextInputAction.go,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      onSubmitted: (_) => _submitNavigation(),
                    )
                  : GestureDetector(
                      onTap: _startEditing,
                      onLongPress: () {
                        Clipboard.setData(ClipboardData(text: provider.currentPath));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied: ${provider.currentPath}'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: theme.colorScheme.secondary,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.centerLeft,
                        child: ListView.builder(
                          controller: _breadcrumbsScrollController,
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: breadcrumbs.length,
                          itemBuilder: (context, index) {
                            final segment = breadcrumbs[index];
                            final isLast = index == breadcrumbs.length - 1;

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    provider.loadDirectory(segment.path);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    child: Text(
                                      segment.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isLast ? FontWeight.bold : FontWeight.w500,
                                        color: isLast
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isLast)
                                  Icon(
                                    Broken.arrow_right_3,
                                    size: 14,
                                    color: theme.colorScheme.onSurface.withOpacity(0.35),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
            ),
            
            // Right Submit Navigation Button (Visible in edit mode)
            if (_isEditing)
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _submitNavigation,
              ),
          ],
        ),
      ),
    );
  }
}
