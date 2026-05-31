import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../models/drag_payload.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import 'drag_drop_action_dialog.dart';

class DragDropHandler extends StatefulWidget {
  final Widget child;
  final String path;
  final bool isDirectory;
  final VoidCallback? onLongPress;

  const DragDropHandler({
    super.key,
    required this.child,
    required this.path,
    required this.isDirectory,
    this.onLongPress,
  });

  @override
  State<DragDropHandler> createState() => _DragDropHandlerState();
}

class _DragDropHandlerState extends State<DragDropHandler> {
  bool _isDragOver = false;
  bool _hasMoved = false;
  Timer? _hoverTimer;
  Timer? _scrollTimer;
  Offset? _currentDragPosition;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _startScrollTimerIfNeeded() {
    if (_scrollTimer != null) return;
    
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_currentDragPosition == null || !mounted) {
        timer.cancel();
        _scrollTimer = null;
        return;
      }
      
      final scrollable = Scrollable.maybeOf(context);
      if (scrollable == null) {
        timer.cancel();
        _scrollTimer = null;
        return;
      }
      
      final renderBox = scrollable.context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      
      final scrollableHeight = renderBox.size.height;
      final localY = renderBox.globalToLocal(_currentDragPosition!).dy;
      
      const double edgeThreshold = 70.0;
      const double baseScrollSpeed = 16.0;
      
      if (localY < edgeThreshold && localY > 0) {
        final fraction = (edgeThreshold - localY) / edgeThreshold;
        final speed = baseScrollSpeed * fraction.clamp(0.2, 1.0);
        final target = (scrollable.position.pixels - speed).clamp(
          scrollable.position.minScrollExtent,
          scrollable.position.maxScrollExtent,
        );
        if (target != scrollable.position.pixels) {
          scrollable.position.jumpTo(target);
        }
      } else if (localY > scrollableHeight - edgeThreshold && localY < scrollableHeight) {
        final fraction = (localY - (scrollableHeight - edgeThreshold)) / edgeThreshold;
        final speed = baseScrollSpeed * fraction.clamp(0.2, 1.0);
        final target = (scrollable.position.pixels + speed).clamp(
          scrollable.position.minScrollExtent,
          scrollable.position.maxScrollExtent,
        );
        if (target != scrollable.position.pixels) {
          scrollable.position.jumpTo(target);
        }
      } else {
        timer.cancel();
        _scrollTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    
    // If drag & drop is disabled in settings, return the child widget directly
    if (!provider.enableDragDrop) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final fileName = p.basename(widget.path);

    final isSelected = provider.selectedPaths.contains(widget.path);
    final dragPaths = (isSelected && provider.selectedPaths.length > 1)
        ? provider.selectedPaths.toList()
        : [widget.path];

    final isMultiDrag = dragPaths.length > 1;
    final displayName = isMultiDrag ? '${dragPaths.length} items' : fileName;

    // Elevated, semi-transparent feedback widget shown while dragging
    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMultiDrag
                  ? Broken.document_copy
                  : (widget.isDirectory ? Broken.folder : FileUtils.getIconForFile(widget.path)),
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              displayName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    Widget itemWidget = LongPressDraggable<DragPayload>(
      data: DragPayload(
        path: widget.path,
        isDirectory: widget.isDirectory,
        paths: dragPaths,
      ),
      feedback: feedback,
      dragAnchorStrategy: childDragAnchorStrategy,
      feedbackOffset: const Offset(0, -30),
      delay: const Duration(milliseconds: 500),
      onDragStarted: () {
        _hasMoved = false;
      },
      onDragUpdate: (details) {
        if (details.delta.dx.abs() > 1.0 || details.delta.dy.abs() > 1.0) {
          _hasMoved = true;
        }
        _currentDragPosition = details.globalPosition;
        _startScrollTimerIfNeeded();
      },
      onDragEnd: (details) {
        _scrollTimer?.cancel();
        _scrollTimer = null;
        _currentDragPosition = null;
        if (!_hasMoved && widget.onLongPress != null) {
          widget.onLongPress!();
        }
      },
      onDraggableCanceled: (velocity, offset) {
        _scrollTimer?.cancel();
        _scrollTimer = null;
        _currentDragPosition = null;
      },
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: widget.child,
      ),
      child: widget.child,
    );

    // If it's a directory, wrap in a DragTarget to allow dropping items onto it
    if (widget.isDirectory) {
      return DragTarget<DragPayload>(
        onWillAccept: (data) {
          if (data == null || data.paths.isEmpty) return false;
          if (data.paths.contains(widget.path)) return false;
          if (data.paths.any((x) => widget.path.startsWith(x + p.separator))) return false;
          
          setState(() {
            _isDragOver = true;
          });

          _hoverTimer?.cancel();
          _hoverTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted) {
              provider.loadDirectory(widget.path);
            }
          });

          return true;
        },
        onLeave: (data) {
          setState(() {
            _isDragOver = false;
          });
          _hoverTimer?.cancel();
        },
        onAccept: (data) async {
          setState(() {
            _isDragOver = false;
          });
          _hoverTimer?.cancel();
          if (provider.showDragDropDialog) {
            DragDropActionDialog.show(
              context: Navigator.of(context).context,
              sourcePaths: data.paths,
              initialTargetPath: widget.path,
            );
          } else {
            await Future.wait(data.paths.map((p) => provider.moveItem(context, p, widget.path, showToast: false)));
            provider.clearSelection();
          }
        },
        builder: (context, candidateData, rejectedData) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _isDragOver
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              border: _isDragOver
                  ? Border.all(color: theme.colorScheme.primary, width: 2.0)
                  : null,
            ),
            child: itemWidget,
          );
        },
      );
    }

    return itemWidget;
  }
}
