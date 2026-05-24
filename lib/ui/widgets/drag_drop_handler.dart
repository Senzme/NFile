import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../models/drag_payload.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    
    // If drag & drop is disabled in settings, return the child widget directly
    if (!provider.enableDragDrop) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final fileName = p.basename(widget.path);

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
              widget.isDirectory ? Broken.folder : FileUtils.getIconForFile(widget.path),
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              fileName,
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
      data: DragPayload(path: widget.path, isDirectory: widget.isDirectory),
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
      },
      onDragEnd: (details) {
        if (!_hasMoved && widget.onLongPress != null) {
          widget.onLongPress!();
        }
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
          // Cannot drop an item onto itself, or move a folder inside its own subdirectory hierarchy
          if (data == null || data.path == widget.path) return false;
          if (widget.path.startsWith(data.path + p.separator)) return false;
          
          setState(() {
            _isDragOver = true;
          });
          return true;
        },
        onLeave: (data) {
          setState(() {
            _isDragOver = false;
          });
        },
        onAccept: (data) {
          setState(() {
            _isDragOver = false;
          });
          provider.moveItem(context, data.path, widget.path);
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
