import 'dart:ui';
import 'package:flutter/material.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';

class FileOperationProgressDialog extends StatelessWidget {
  final FileManagerProvider provider;

  const FileOperationProgressDialog({
    super.key,
    required this.provider,
  });

  static Future<void> show(BuildContext context, FileManagerProvider provider) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => PopScope(
        canPop: false, // Prevent dismissing with back button
        child: FileOperationProgressDialog(provider: provider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Center(
        child: ValueListenableBuilder<FileOperationProgress?>(
          valueListenable: provider.progressNotifier,
          builder: (context, progress, child) {
            if (progress == null) {
              // If progress is null, the operation is done or not started yet.
              // We automatically pop the dialog in a post-frame callback.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
              return const SizedBox.shrink();
            }

            final percent = progress.percentage.clamp(0.0, 1.0);
            final speedText = '${progress.speedMBs.toStringAsFixed(1)} MB/s';
            final etaText = progress.eta.inSeconds > 0
                ? '${progress.eta.inMinutes.toString().padLeft(2, '0')}:${(progress.eta.inSeconds % 60).toString().padLeft(2, '0')} remaining'
                : 'calculating...';
            final processedSize = FileUtils.formatBytes(progress.bytesProcessed, 2);
            final totalSize = FileUtils.formatBytes(progress.totalBytes, 2);

            return Card(
              elevation: 24,
              shadowColor: Colors.black.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.12)),
              ),
              color: theme.colorScheme.surface.withOpacity(0.85),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  child: Container(
                    width: size.width * 0.85,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dialog Title & Icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Broken.document_copy,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.isCut ? 'Moving Files...' : 'Copying Files...',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Processing item ${progress.currentFileIndex} of ${progress.totalFiles}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Current File Name with sleek container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Broken.document,
                                size: 18,
                                color: theme.colorScheme.primary.withOpacity(0.8),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  progress.currentFileName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sleek Linear Progress Bar with animated gradient
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Overall Progress',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                                  ),
                                ),
                                Text(
                                  '${(percent * 100).toStringAsFixed(0)}%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  Container(
                                    height: 10,
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    height: 10,
                                    width: (size.width * 0.72) * percent,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.primary.withRed(100).withBlue(220),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Stats Grid (Speed, ETA, Size)
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatTile(
                                theme,
                                label: 'Transfer Speed',
                                value: speedText,
                                icon: Broken.chart_3,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatTile(
                                theme,
                                label: 'Est. Time',
                                value: etaText,
                                icon: Broken.clock,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStatTile(
                          theme,
                          label: 'Data Processed',
                          value: '$processedSize of $totalSize',
                          icon: Broken.folder_open,
                          isRow: true,
                        ),
                        const SizedBox(height: 28),

                        // Premium outline Cancel Button
                        OutlinedButton.icon(
                          onPressed: () {
                            provider.cancelOperation();
                          },
                          icon: const Icon(Broken.close_square, size: 18),
                          label: const Text('Cancel Operation', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatTile(
    ThemeData theme, {
    required String label,
    required String value,
    required IconData icon,
    bool isRow = false,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withOpacity(0.9),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.04)),
      ),
      child: isRow
          ? Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(width: 10),
                Expanded(child: content),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary.withOpacity(0.7)),
                const SizedBox(width: 8),
                const SizedBox(height: 6),
                content,
              ],
            ),
    );
  }
}
