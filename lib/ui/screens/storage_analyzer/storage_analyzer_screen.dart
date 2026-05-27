import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/icon_fonts/broken_icons.dart';
import '../../../providers/file_manager_provider.dart';
import '../../../core/utils.dart';
import '../../../services/app_manager_service.dart';
import '../media_category_screen.dart';
import 'app_manager_screen.dart';

class StorageAnalyzerScreen extends StatefulWidget {
  final String? initialVolumePath;
  const StorageAnalyzerScreen({super.key, this.initialVolumePath});

  @override
  State<StorageAnalyzerScreen> createState() => _StorageAnalyzerScreenState();
}

class _StorageAnalyzerScreenState extends State<StorageAnalyzerScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = true;
  String _currentScanningItem = 'Initializing...';
  
  int _appsSize = 0;
  int _imagesSize = 0;
  int _videosSize = 0;
  int _audioSize = 0;
  int _docsSize = 0;
  int _systemSize = 0;
  int _totalUsedSize = 0;
  int _totalStorageSize = 0;

  late AnimationController _radialController;

  @override
  void initState() {
    super.initState();
    _radialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _startStorageScan();
  }

  @override
  void dispose() {
    _radialController.dispose();
    super.dispose();
  }

  Future<void> _startStorageScan() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _currentScanningItem = 'Reading system memory...';
    });

    final provider = context.read<FileManagerProvider>();
    final path = widget.initialVolumePath ?? '/storage/emulated/0';

    // 1. Fetch total & used storage via provider
    _totalStorageSize = provider.totalStorageBytes > 0 ? provider.totalStorageBytes : 128 * 1024 * 1024 * 1024;
    _totalUsedSize = provider.usedStorageBytes > 0 ? provider.usedStorageBytes : 84 * 1024 * 1024 * 1024;

    // 2. Fetch app sizes from App Manager Service
    setState(() {
      _currentScanningItem = 'Calculating Apps capacity...';
    });
    try {
      final userApps = await AppManagerService.getInstalledApps(includeSystem: false);
      final systemApps = await AppManagerService.getInstalledApps(includeSystem: true);
      
      int appsSum = 0;
      for (final app in userApps) {
        appsSum += app.apkSize;
      }
      for (final app in systemApps) {
        if (app.isSystem) {
          appsSum += app.apkSize;
        }
      }
      _appsSize = appsSum;
    } catch (_) {
      _appsSize = 0;
    }

    // 3. Scan directories recursively in background
    try {
      final rootDir = Directory(path);
      if (rootDir.existsSync()) {
        int imgBytes = 0;
        int vidBytes = 0;
        int audBytes = 0;
        int docBytes = 0;

        final stream = rootDir.list(recursive: true, followLinks: false);
        await for (final entity in stream.handleError((_) {})) {
          if (entity is File) {
            final filePath = entity.path;
            final fileName = filePath.split('/').last.split('\\').last;
            
            if (mounted) {
              setState(() {
                _currentScanningItem = fileName;
              });
            }

            try {
              final size = entity.lengthSync();
              final lowerPath = filePath.toLowerCase();

              if (FileUtils.isImage(lowerPath)) {
                imgBytes += size;
              } else if (FileUtils.isVideo(lowerPath)) {
                vidBytes += size;
              } else if (FileUtils.isAudio(lowerPath)) {
                audBytes += size;
              } else {
                // Check documents
                const docExts = ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt', '.csv', '.odt', '.ods', '.odp', '.rtf', '.epub'];
                if (docExts.any((ext) => lowerPath.endsWith(ext)) || FileUtils.isTextOrCode(lowerPath)) {
                  docBytes += size;
                }
              }
            } catch (_) {}
          }
        }

        _imagesSize = imgBytes;
        _videosSize = vidBytes;
        _audioSize = audBytes;
        _docsSize = docBytes;
      }
    } catch (_) {}

    // Adjust system/other size
    final double calculatedUsed = (_appsSize + _imagesSize + _videosSize + _audioSize + _docsSize).toDouble();
    _systemSize = max(0, _totalUsedSize - calculatedUsed.toInt());

    if (mounted) {
      setState(() {
        _isScanning = false;
      });
      _radialController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Storage Analytics',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _startStorageScan,
            tooltip: 'Rescan Storage',
          ),
        ],
      ),
      body: _isScanning ? _buildScanningView(theme, isDark) : _buildAnalyticsView(theme, isDark),
    );
  }

  Widget _buildScanningView(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Broken.document_filter,
                    size: 38,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Scanning Device Storage',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing files, categorizing assets, and reading installed apps space...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _currentScanningItem,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsView(ThemeData theme, bool isDark) {
    final double usedPercent = _totalStorageSize > 0 ? (_totalUsedSize / _totalStorageSize) * 100 : 0.0;
    final int freeSize = max(0, _totalStorageSize - _totalUsedSize);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Circular progress card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Custom Radial Chart Painter
                AnimatedBuilder(
                  animation: _radialController,
                  builder: (context, child) {
                    return SizedBox(
                      width: 110,
                      height: 110,
                      child: CustomPaint(
                        painter: StorageRadialPainter(
                          apps: _appsSize,
                          images: _imagesSize,
                          videos: _videosSize,
                          audio: _audioSize,
                          docs: _docsSize,
                          system: _systemSize,
                          total: _totalStorageSize,
                          animationVal: _radialController.value,
                          isDark: isDark,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Storage',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FileUtils.formatBytes(_totalStorageSize, 2),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981), // Green free space
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${FileUtils.formatBytes(freeSize, 2)} free',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFEF4444), // Red used space
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${FileUtils.formatBytes(_totalUsedSize, 2)} used (${usedPercent.toStringAsFixed(1)}%)',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Categories Breakdown Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Breakdown',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Category items
          _buildCategoryCard(
            context: context,
            title: 'Applications',
            size: _appsSize,
            color: const Color(0xFFEC4899), // Pink
            icon: Broken.mobile,
            theme: theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppManagerScreen()),
              );
            },
          ),
          _buildCategoryCard(
            context: context,
            title: 'Images',
            size: _imagesSize,
            color: const Color(0xFF8B5CF6), // Violet
            icon: Broken.image,
            theme: theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MediaCategoryScreen(mediaType: MediaType.images),
                ),
              );
            },
          ),
          _buildCategoryCard(
            context: context,
            title: 'Videos',
            size: _videosSize,
            color: const Color(0xFFEF4444), // Red
            icon: Broken.video,
            theme: theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MediaCategoryScreen(mediaType: MediaType.videos),
                ),
              );
            },
          ),
          _buildCategoryCard(
            context: context,
            title: 'Audio',
            size: _audioSize,
            color: const Color(0xFFF97316), // Orange
            icon: Broken.music,
            theme: theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MediaCategoryScreen(mediaType: MediaType.audios),
                ),
              );
            },
          ),
          _buildCategoryCard(
            context: context,
            title: 'Documents',
            size: _docsSize,
            color: const Color(0xFF3B82F6), // Blue
            icon: Broken.document,
            theme: theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MediaCategoryScreen(mediaType: MediaType.documents),
                ),
              );
            },
          ),
          _buildCategoryCard(
            context: context,
            title: 'System / Other',
            size: _systemSize,
            color: const Color(0xFF64748B), // Slate
            icon: Broken.category_2,
            theme: theme,
            onTap: () {}, // No viewer for system/other
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    required int size,
    required Color color,
    required IconData icon,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final double proportion = _totalStorageSize > 0 ? (size / _totalStorageSize) : 0.0;
    final String percentStr = (proportion * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.06)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                        ),
                        Text(
                          FileUtils.formatBytes(size, 2),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: proportion,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percentStr% of total storage',
                      style: TextStyle(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (title != 'System / Other') ...[
                const SizedBox(width: 12),
                Icon(
                  Broken.arrow_right_3,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StorageRadialPainter extends CustomPainter {
  final int apps;
  final int images;
  final int videos;
  final int audio;
  final int docs;
  final int system;
  final int total;
  final double animationVal;
  final bool isDark;

  StorageRadialPainter({
    required this.apps,
    required this.images,
    required this.videos,
    required this.audio,
    required this.docs,
    required this.system,
    required this.total,
    required this.animationVal,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double center = size.width / 2;
    final double radius = min(size.width, size.height) / 2 - 8;
    final Rect rect = Rect.fromCircle(center: Offset(center, center), radius: radius);

    final Paint trackPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;

    canvas.drawCircle(Offset(center, center), radius, trackPaint);

    if (total == 0) return;

    final double factor = animationVal * 2 * pi;
    double startAngle = -pi / 2;

    void drawSegment(int segmentSize, Color color) {
      if (segmentSize <= 0) return;
      final double sweepAngle = (segmentSize / total) * factor;

      final Paint segmentPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweepAngle, false, segmentPaint);
      startAngle += sweepAngle;
    }

    // Draw in order of categories
    drawSegment(apps, const Color(0xFFEC4899));
    drawSegment(images, const Color(0xFF8B5CF6));
    drawSegment(videos, const Color(0xFFEF4444));
    drawSegment(audio, const Color(0xFFF97316));
    drawSegment(docs, const Color(0xFF3B82F6));
    drawSegment(system, const Color(0xFF64748B));
  }

  @override
  bool shouldRepaint(covariant StorageRadialPainter oldDelegate) {
    return oldDelegate.animationVal != animationVal;
  }
}
