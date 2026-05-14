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

  static IconData getIconForFile(String path) {
    final mimeType = lookupMimeType(path);
    if (mimeType == null) return Broken.document;

    if (mimeType.startsWith('image/')) return Broken.image;
    if (mimeType.startsWith('video/')) return Broken.video;
    if (mimeType.startsWith('audio/')) return Broken.music;
    if (mimeType.startsWith('text/')) return Broken.document_text;
    if (mimeType == 'application/pdf') return Broken.document;
    if (mimeType.contains('zip') || mimeType.contains('tar') || mimeType.contains('rar')) {
      return Broken.folder_connection;
    }
    if (mimeType.startsWith('application/vnd.android.package-archive')) {
      return Broken.mobile;
    }

    return Broken.document;
  }
  
  static Color getColorForFile(String path, BuildContext context) {
    final mimeType = lookupMimeType(path);
    if (mimeType == null) return Theme.of(context).colorScheme.primary;

    if (mimeType.startsWith('image/')) return Colors.purpleAccent;
    if (mimeType.startsWith('video/')) return Colors.redAccent;
    if (mimeType.startsWith('audio/')) return Colors.orangeAccent;
    if (mimeType.startsWith('text/')) return Colors.blueAccent;
    if (mimeType == 'application/pdf') return Colors.red;
    if (mimeType.contains('zip') || mimeType.contains('tar') || mimeType.contains('rar')) {
      return Colors.brown;
    }

    return Theme.of(context).colorScheme.primary;
  }
}
