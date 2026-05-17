import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'icon_fonts/broken_icons.dart';

class FileUtils {
  static String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = 0;
    double b = bytes.toDouble();
    while (b > 1024) {
      b /= 1024;
      i++;
    }
    return '${b.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy  HH:mm').format(date);
  }

  static bool isArchive(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz2') ||
        lower.endsWith('.gz') ||
        lower.endsWith('.bz2') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.001');
  }

  static IconData getIconForFile(String path) {
    if (isArchive(path)) return Broken.archive;

    final mimeType = lookupMimeType(path);
    if (mimeType == null) return Broken.document;

    if (mimeType.startsWith('image/')) return Broken.image;
    if (mimeType.startsWith('video/')) return Broken.video;
    if (mimeType.startsWith('audio/')) return Broken.music;
    if (mimeType.startsWith('text/')) return Broken.document_text;
    if (mimeType == 'application/pdf') return Broken.document;
    if (mimeType.startsWith('application/vnd.android.package-archive')) {
      return Broken.mobile;
    }

    return Broken.document;
  }
  
  static Color getColorForFile(String path, BuildContext context) {
    if (isArchive(path)) return Colors.brown;

    final mimeType = lookupMimeType(path);
    if (mimeType == null) return Theme.of(context).colorScheme.primary;

    if (mimeType.startsWith('image/')) return Colors.purpleAccent;
    if (mimeType.startsWith('video/')) return Colors.redAccent;
    if (mimeType.startsWith('audio/')) return Colors.orangeAccent;
    if (mimeType.startsWith('text/')) return Colors.blueAccent;
    if (mimeType == 'application/pdf') return Colors.red;

    return Theme.of(context).colorScheme.primary;
  }
}
