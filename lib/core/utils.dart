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

  static String formatDate(DateTime date, {bool use24Hour = true}) {
    final timePattern = use24Hour ? 'HH:mm' : 'hh:mm a';
    return DateFormat('MMM dd, yyyy  $timePattern').format(date);
  }

  static bool isArchive(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.zip') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.tar.gz') ||
        lower.endsWith('.tgz') ||
        lower.endsWith('.tar.bz2') ||
        lower.endsWith('.tbz2') ||
        lower.endsWith('.tar.lz4') ||
        lower.endsWith('.tlz4') ||
        lower.endsWith('.lz4') ||
        lower.endsWith('.tar.zst') ||
        lower.endsWith('.tzst') ||
        lower.endsWith('.zst') ||
        lower.endsWith('.zstd') ||
        lower.endsWith('.gz') ||
        lower.endsWith('.bz2') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.001');
  }

  static bool isTextOrCode(String path) {
    final lower = path.toLowerCase();
    
    // Fallback for files without extension (e.g. hosts)
    final filename = path.split('/').last.split('\\').last;
    if (!filename.contains('.') && filename.isNotEmpty) {
      return true;
    }

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

  static bool isImage(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.3ds') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.psd') ||
        lower.endsWith('.tiff') ||
        lower.endsWith('.tif') ||
        lower.endsWith('.xcf')) {
      return false;
    }
    final mimeType = lookupMimeType(path);
    if (mimeType != null && mimeType.startsWith('image/')) {
      final lowerMime = mimeType.toLowerCase();
      if (lowerMime.contains('x-3ds') ||
          lowerMime.contains('svg') ||
          lowerMime.contains('photoshop') ||
          lowerMime.contains('tiff') ||
          lowerMime.contains('xcf') ||
          lowerMime.contains('gimp')) {
        return false;
      }
      return true;
    }
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.avif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  static bool isVideo(String path) {
    final mimeType = lookupMimeType(path);
    if (mimeType != null && mimeType.startsWith('video/')) return true;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.ts') || lower.endsWith('.mts') || lower.endsWith('.mkv') || lower.endsWith('.webm') || lower.endsWith('.avi') || lower.endsWith('.mov') || lower.endsWith('.flv');
  }

  static bool isAudio(String path) {
    final mimeType = lookupMimeType(path);
    if (mimeType != null && mimeType.startsWith('audio/')) return true;
    final lower = path.toLowerCase();
    return lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a') || lower.endsWith('.ogg') || lower.endsWith('.flac') || lower.endsWith('.aac') || lower.endsWith('.wma') || lower.endsWith('.opus');
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

  static int compareNatural(String a, String b) {
    int i = 0;
    int j = 0;
    
    final aLower = a.toLowerCase();
    final bLower = b.toLowerCase();

    while (i < aLower.length && j < bLower.length) {
      int charA = aLower.codeUnitAt(i);
      int charB = bLower.codeUnitAt(j);

      if (_isDigit(charA) && _isDigit(charB)) {
        int startA = i;
        while (i < aLower.length && _isDigit(aLower.codeUnitAt(i))) {
          i++;
        }
        int startB = j;
        while (j < bLower.length && _isDigit(bLower.codeUnitAt(j))) {
          j++;
        }

        String subA = aLower.substring(startA, i);
        String subB = bLower.substring(startB, j);

        BigInt? numA = BigInt.tryParse(subA);
        BigInt? numB = BigInt.tryParse(subB);

        if (numA != null && numB != null) {
          int cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
          if (subA.length != subB.length) {
            return subA.length.compareTo(subB.length);
          }
        } else {
          int cmp = subA.compareTo(subB);
          if (cmp != 0) return cmp;
        }
      } else {
        if (charA != charB) {
          return charA.compareTo(charB);
        }
        i++;
        j++;
      }
    }

    if (i < aLower.length) return 1;
    if (j < bLower.length) return -1;
    return a.compareTo(b);
  }

  static bool _isDigit(int codeUnit) {
    return codeUnit >= 48 && codeUnit <= 57;
  }
}
