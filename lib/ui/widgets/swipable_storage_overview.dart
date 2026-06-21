import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/utils.dart';
import '../screens/storage_analyzer/storage_analyzer_screen.dart';

class SwipableStorageOverview extends StatefulWidget {
  final Function(String) onBrowseVolume;

  const SwipableStorageOverview({super.key, required this.onBrowseVolume});

  @override
  State<SwipableStorageOverview> createState() => _SwipableStorageOverviewState();
}

class _SwipableStorageOverviewState extends State<SwipableStorageOverview> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonCard(BuildContext context, {required bool isMultiVolume}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderCol = isDark ? Colors.white.withOpacity(0.05) : theme.colorScheme.primary.withOpacity(0.08);
    final double cardHeight = isMultiVolume ? 160.0 : 144.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: isMultiVolume ? 8.0 : 4.0),
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderCol, width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.15) : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  ShimmerPlaceholder(width: 50, height: 50, borderRadius: 16),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerPlaceholder(width: 140, height: 16, borderRadius: 4),
                        SizedBox(height: 8),
                        ShimmerPlaceholder(width: 100, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMultiVolume ? 16 : 12),
              const ShimmerPlaceholder(width: double.infinity, height: 8, borderRadius: 8),
              SizedBox(height: isMultiVolume ? 10 : 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShimmerPlaceholder(width: 90, height: 14, borderRadius: 4),
                  ShimmerPlaceholder(width: 80, height: 14, borderRadius: 4),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    final volumes = provider.storageVolumes;

    // Show shimmering skeleton loading card while spaces are being calculated
    if (volumes.isEmpty || provider.totalStorageBytes == 0) {
      return _buildSkeletonCard(context, isMultiVolume: volumes.length > 1);
    }

    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final double pageViewHeight = volumes.length > 1 ? 176.0 : 152.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: pageViewHeight,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: volumes.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final vol = volumes[index];

              int totalBytes;
              int usedBytes;

              if (vol.isInternal) {
                // Use marketing-rounded capacity (e.g. 128 GB) and adjusted used bytes
                totalBytes = provider.totalStorageBytes > 0 
                    ? provider.totalStorageBytes 
                    : 128 * 1024 * 1024 * 1024;
                
                usedBytes = provider.usedStorageBytes > 0 
                    ? provider.usedStorageBytes 
                    : 84 * 1024 * 1024 * 1024;
              } else {
                // Use raw capacity for external storage (SD Card / USB)
                totalBytes = vol.totalBytes > 0 
                    ? vol.totalBytes 
                    : 32 * 1024 * 1024 * 1024;
                
                usedBytes = vol.usedBytes > 0 
                    ? vol.usedBytes 
                    : 0;
              }

              final int freeBytes = totalBytes - usedBytes;
              final double usedPercentage = totalBytes > 0 ? (usedBytes / totalBytes) : 0.0;

              // Format with 2 decimals to display precise storage e.g. 6.22 GB free / 128.00 GB total
              final String totalStorageStr = FileUtils.formatBytes(totalBytes, 2);
              final String freeStorageStr = FileUtils.formatBytes(freeBytes, 2);

              // Gradients & Colors tailored by storage type
              List<Color> gradientColors;
              IconData iconData;
              Color accentColor;

              if (vol.isInternal) {
                gradientColors = isDark
                    ? [
                        Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.15), const Color(0xFF181818)),
                        Color.alphaBlend(theme.colorScheme.primary.withOpacity(0.05), const Color(0xFF0C0C0C)),
                      ]
                    : [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.82)];
                iconData = Broken.folder_2;
                accentColor = isDark ? theme.colorScheme.primary : Colors.white;
              } else if (vol.name.toLowerCase().contains('sd')) {
                gradientColors = isDark
                    ? const [Color(0xFF312E81), Color(0xFF1E1B4B)]
                    : const [Color(0xFF4F46E5), Color(0xFF4338CA)];
                iconData = Icons.sd_storage_rounded;
                accentColor = isDark ? const Color(0xFF818CF8) : Colors.white;
              } else {
                gradientColors = isDark
                    ? const [Color(0xFF115E59), Color(0xFF0F4C46)]
                    : const [Color(0xFF0D9488), Color(0xFF0F766E)];
                iconData = Icons.usb_rounded;
                accentColor = isDark ? const Color(0xFF2DD4BF) : Colors.white;
              }

              final iconBgColor = isDark ? accentColor.withOpacity(0.15) : Colors.white.withOpacity(0.25);
              final iconBorderColor = isDark ? accentColor.withOpacity(0.3) : Colors.white.withOpacity(0.4);
              final shadowColor = isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.06);
              final progressBgColor = isDark ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.3);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: volumes.length > 1 ? 8.0 : 4.0),
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
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () => widget.onBrowseVolume(vol.path),
                      onLongPress: () {
                        if (vol.isInternal) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StorageAnalyzerScreen(
                                initialVolumePath: vol.path,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(24),
                      splashColor: Colors.white.withOpacity(0.15),
                      highlightColor: Colors.white.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                  child: Icon(iconData, color: accentColor, size: 26),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vol.name,
                                        style: const TextStyle(
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
                                        vol.path,
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
                                // const SizedBox(width: 8),
                                // Container(
                                //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                //   decoration: BoxDecoration(
                                //     color: Colors.white.withOpacity(0.15),
                                //     borderRadius: BorderRadius.circular(14),
                                //     border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                                //   ),
                                //   child: const Row(
                                //     mainAxisSize: MainAxisSize.min,
                                //     children: [
                                //       Text(
                                //         'Browse',
                                //         style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
                                //       ),
                                //       SizedBox(width: 4),
                                //       Icon(Broken.arrow_right_3, color: Colors.white, size: 14),
                                //     ],
                                //   ),
                                // ),
                              ],
                            ),
                            SizedBox(height: volumes.length > 1 ? 16.0 : 12.0),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: usedPercentage,
                                backgroundColor: progressBgColor,
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                minHeight: 8,
                              ),
                            ),
                            SizedBox(height: volumes.length > 1 ? 10.0 : 8.0),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$freeStorageStr free',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
                                ),
                                Text(
                                  '$totalStorageStr total',
                                  style: TextStyle(color: Colors.white.withOpacity(0.82), fontWeight: FontWeight.w500, fontSize: 12.5),
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
            },
          ),
        ),
        if (volumes.length > 1) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              volumes.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentPage == index ? 18 : 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? (isDark ? theme.colorScheme.primary : theme.colorScheme.primary)
                      : (isDark ? Colors.white30 : Colors.black12),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ShimmerPlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerPlaceholder({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.35 + (_controller.value * 0.35),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}
