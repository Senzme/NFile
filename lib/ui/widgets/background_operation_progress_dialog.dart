import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/background_archive_service.dart';
import '../../core/icon_fonts/broken_icons.dart';

class BackgroundOperationProgressDialog extends StatelessWidget {
  final BackgroundArchiveService service;

  const BackgroundOperationProgressDialog({
    super.key,
    required this.service,
  });

  static Future<void> show(BuildContext context, BackgroundArchiveService service) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => PopScope(
        canPop: false, // Prevent dismissing via standard back button
        child: BackgroundOperationProgressDialog(service: service),
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
        child: ValueListenableBuilder<BackgroundOperation?>(
          valueListenable: service.activeOperation,
          builder: (context, operation, child) {
            if (operation == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              });
              return const SizedBox.shrink();
            }

            final percent = operation.progress.clamp(0.0, 1.0);
            final progressPercentText = '${(percent * 100).toStringAsFixed(0)}%';

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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                operation.isCompression ? Broken.archive_add : Broken.box,
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
                                    operation.title,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    operation.archiveName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

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
                                  operation.currentFile.isEmpty ? 'Processing...' : operation.currentFile,
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
                                  progressPercentText,
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
                        const SizedBox(height: 28),

                        // Two distinct styled buttons side by side
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  service.cancelOperation();
                                },
                                icon: const Icon(Broken.close_square, size: 18),
                                label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  service.runInBackground();
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                                icon: const Icon(Broken.send, size: 18),
                                label: const Text('Background', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
}
