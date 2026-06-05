import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';

class TabOptionsSheet extends StatelessWidget {
  final FileManagerProvider provider;
  final int tabIndex;

  const TabOptionsSheet({
    super.key,
    required this.provider,
    required this.tabIndex,
  });

  static Future<void> show(BuildContext context, FileManagerProvider provider, int tabIndex) {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TabOptionsSheet(
        provider: provider,
        tabIndex: tabIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tabs = provider.tabs;
    if (tabIndex < 0 || tabIndex >= tabs.length) {
      return const SizedBox.shrink();
    }

    final tab = tabs[tabIndex];
    final isRoot = tab.currentPath == provider.rootPath;
    final displayTitle = isRoot ? 'Home' : p.basename(tab.currentPath);
    final displayPath = tab.currentPath.isEmpty ? '/' : tab.currentPath;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      tab.isPinned
                          ? Icons.push_pin_rounded
                          : isRoot 
                              ? Broken.home_1 
                              : Broken.folder,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle.isEmpty ? '/' : displayTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          displayPath,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Broken.close_circle, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            _buildMenuItem(
              context: context,
              icon: tab.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              iconColor: tab.isPinned ? Colors.orange : null,
              label: tab.isPinned ? 'Unpin Tab' : 'Pin Tab',
              onTap: () {
                Navigator.pop(context);
                provider.togglePinTab(tabIndex);
              },
            ),
            _buildMenuItem(
              context: context,
              icon: Broken.copy,
              label: 'Duplicate Tab',
              onTap: () {
                Navigator.pop(context);
                provider.duplicateTab(tabIndex);
              },
            ),
            if (tabs.length > 1) ...[
              const Divider(height: 1),
              _buildMenuItem(
                context: context,
                icon: Broken.trash,
                label: 'Close Tab',
                color: Colors.redAccent,
                onTap: () {
                  Navigator.pop(context);
                  provider.closeTab(tabIndex);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final displayColor = color ?? theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? displayColor.withOpacity(0.8), size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: displayColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
