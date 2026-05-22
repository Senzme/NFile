import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/file_manager_provider.dart';

class IntentHandlerService {
  static const MethodChannel _channel = MethodChannel('com.rubex.nfile/root_shizuku');

  // Registry to map resolved local cache paths back to their original content:// URIs
  static final Map<String, String> _resolvedUris = {};

  /// Checks if a cache path was resolved from a content URI.
  static bool isIncomingCacheFile(String cachePath) {
    return _resolvedUris.containsKey(cachePath);
  }

  /// Gets the original content URI associated with a cache path, if any.
  static String? getOriginalUri(String cachePath) {
    return _resolvedUris[cachePath];
  }

  /// Resolves an incoming intent path (handling content:// URIs) and opens the file.
  static Future<void> handleIncomingIntent(BuildContext context, String rawPath) async {
    if (rawPath.isEmpty) return;

    String targetPath = rawPath;

    if (rawPath.startsWith('content://')) {
      try {
        final result = await _channel.invokeMethod('resolveContentUri', {'uri': rawPath});
        if (result != null && result['success'] == true) {
          final cachePath = result['cachePath'] as String;
          _resolvedUris[cachePath] = rawPath;
          targetPath = cachePath;
        }
      } catch (e) {
        debugPrint('Error resolving content URI: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading shared file: $e')),
          );
        }
        return;
      }
    }

    if (context.mounted) {
      final provider = context.read<FileManagerProvider>();

      // Bypass "open-with" sheet/loop for incoming file intents by opening natively directly if supported
      if (provider.hasNativeViewer(targetPath)) {
        await provider.openFileNatively(context, targetPath);
      } else {
        await provider.openFile(context, targetPath);
      }
    }
  }

  /// Writes edited file contents back to the original content URI.
  static Future<bool> saveContentUriFile(String cachePath, String content) async {
    final originalUri = _resolvedUris[cachePath];
    if (originalUri == null) return false;

    try {
      final bool? success = await _channel.invokeMethod<bool>('writeContentUri', {
        'uri': originalUri,
        'content': content,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('Error saving to content URI: $e');
      return false;
    }
  }
}
