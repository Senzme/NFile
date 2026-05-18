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

  static bool isTextOrCode(String path) {
    final lower = path.toLowerCase();
    const exts = [
      '.txt', '.md', '.json', '.xml', '.py', '.js', '.ts', '.dart', '.html', '.css',
      '.scss', '.java', '.kt', '.cpp', '.c', '.h', '.hpp', '.cs', '.php', '.rb', '.go',
      '.rs', '.swift', '.sql', '.yaml', '.yml', '.ini', '.cfg', '.conf', '.sh', '.bat',
      '.ps1', '.cmd', '.env', '.log', '.csv', '.tsv', '.properties', '.gradle', '.pom', '.err'
    ];
    for (final ext in exts) {
      if (lower.endsWith(ext)) return true;
    }
    final mime = lookupMimeType(path);
    return mime != null && mime.startsWith('text/');
  }

  static IconData getIconForFile(String path) {
    if (isArchive(path)) return Broken.archive;
    if (isTextOrCode(path)) return Broken.document_code;

    final mimeType = lookupMimeType(path);
    if (mimeType == null) return Broken.document;

    if (mimeType.startsWith('image/')) return Broken.image;
    if (mimeType.startsWith('video/')) return Broken.video;
    if (mimeType.startsWith('audio/')) return Broken.music;
    if (mimeType == 'application/pdf') return Broken.document;
    if (mimeType.startsWith('application/vnd.android.package-archive')) {
      return Broken.mobile;
    }

    return Broken.document;
  }
  
  static Color getColorForFile(String path, BuildContext context) {
    if (isArchive(path)) return Colors.brown;
    if (isTextOrCode(path)) return Colors.blueAccent;

    final mimeType = lookupMimeType(path);
    if (mimeType == null) return Theme.of(context).colorScheme.primary;

    if (mimeType.startsWith('image/')) return Colors.purpleAccent;
    if (mimeType.startsWith('video/')) return Colors.redAccent;
    if (mimeType.startsWith('audio/')) return Colors.orangeAccent;
    if (mimeType == 'application/pdf') return Colors.red;

    return Theme.of(context).colorScheme.primary;
  }

  static IconData getFolderIcon(String option) {
    switch (option) {
      case 'solid': return Icons.folder;
      case 'rounded': return Icons.folder_rounded;
      case 'special': return Icons.folder_special_rounded;
      case 'snippet': return Icons.snippet_folder_rounded;
      case 'outlined': return Icons.folder_outlined;
      case 'broken':
      default:
        return Broken.folder;
    }
  }
}
