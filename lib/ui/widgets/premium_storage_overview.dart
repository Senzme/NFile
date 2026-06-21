import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';

class PremiumStorageOverview extends StatelessWidget {
  final VoidCallback onBrowseStorage;

  const PremiumStorageOverview({super.key, required this.onBrowseStorage});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();

    final double totalBytes = provider.totalStorageBytes > 0 
        ? provider.totalStorageBytes.toDouble() 
        : 128 * 1024 * 1024 * 1024.0;
    
    final double usedBytes = provider.usedStorageBytes > 0 
        ? provider.usedStorageBytes.toDouble() 
        : 84.2 * 1024 * 1024 * 1024.0;
        
    final double usedPercentage = provider.totalStorageBytes > 0 
        ? provider.storageUsedPercentage 
        : 0.65;

    final String totalStorageStr = FileUtils.formatBytes(totalBytes.toInt(), 1);
    final String usedStorageStr = FileUtils.formatBytes(usedBytes.toInt(), 1);

    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final gradientColors = isDark
        ? [
            Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.15), const Color(0xFF181818)),
            Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.05), const Color(0xFF0C0C0C)),
          ] // Primary Theme Gradient in Dark Mode
        : [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.82)]; // Primary Theme Gradient in Light Mode

    final accentColor = isDark ? theme.colorScheme.primary : Colors.white;
    final iconBgColor = isDark ? theme.colorScheme.primary.withOpacity(0.15) : Colors.white.withOpacity(0.25);
    final iconBorderColor = isDark ? theme.colorScheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.4);
    final shadowColor = isDark ? const Color(0xFF0F172A).withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.35);
    final progressBgColor = isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onBrowseStorage,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withOpacity(0.15),
            highlightColor: Colors.white.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: iconBorderColor, width: 1),
                        ),
                        child: Icon(Broken.folder_2, color: accentColor, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Internal Storage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Browse device files',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Browse',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
                            ),
                            SizedBox(width: 4),
                            Icon(Broken.arrow_right_3, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: usedPercentage,
                      backgroundColor: progressBgColor,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$usedStorageStr used',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      Text(
                        '$totalStorageStr total',
                        style: TextStyle(color: Colors.white.withOpacity(0.72), fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
