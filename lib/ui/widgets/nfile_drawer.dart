import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/file_manager_provider.dart';
import '../screens/global_search_screen.dart';
import '../screens/more_settings_screen.dart';

class NFileDrawer extends StatelessWidget {
  final VoidCallback toggleTheme;
  final Function(int)? onNavigateTab;

  const NFileDrawer({super.key, required this.toggleTheme, this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileManager = context.watch<FileManagerProvider>();

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header Banner
            _buildDrawerHeader(context, theme, isDark),
            const SizedBox(height: 8),

            // Scrollable Menu Items
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(context, 'Navigation'),
                    _buildDrawerTile(
                      context,
                      icon: Broken.home,
                      title: 'Home',
                      onTap: () {
                        Navigator.pop(context); // Close drawer
                        onNavigateTab?.call(0);
                      },
                    ),
                    for (final vol in fileManager.storageVolumes)
                      _buildDrawerTile(
                        context,
                        icon: vol.isInternal ? Broken.folder_open : Icons.sd_storage_rounded,
                        title: vol.name,
                        isSelected: fileManager.rootPath == vol.path,
                        onTap: () {
                          Navigator.pop(context);
                          fileManager.setRootPath(vol.path);
                          fileManager.loadDirectory(vol.path);
                          onNavigateTab?.call(1);
                        },
                      ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.cpu,
                      title: 'System Root',
                      isSelected: fileManager.rootPath == '/',
                      onTap: () {
                        Navigator.pop(context);
                        fileManager.setRootPath('/');
                        fileManager.loadDirectory('/');
                        onNavigateTab?.call(1);
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.search_normal,
                      title: 'Global Search',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalSearchScreen()));
                      },
                    ),

                    _buildDivider(context),
                    _buildSectionTitle(context, 'Customization & Settings'),
                    _buildDrawerTile(
                      context,
                      icon: isDark ? Broken.sun_1 : Broken.moon,
                      title: isDark ? 'Light Mode' : 'Dark Mode',
                      trailing: Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: isDark,
                          activeColor: theme.colorScheme.primary,
                          onChanged: (_) => toggleTheme(),
                        ),
                      ),
                      onTap: toggleTheme,
                    ),

                    _buildDrawerTile(
                      context,
                      icon: Broken.setting_2,
                      title: 'More Settings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MoreSettingsScreen()));
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Broken.info_circle,
                      title: 'About NFile',
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog(context, theme);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Footer Version Info
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'NFile v1.0.22',
                style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.4), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [theme.colorScheme.primary.withOpacity(0.85), theme.colorScheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Broken.folder, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NFile',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Premium Media Suite',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 12.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2.0),
      child: Material(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: theme.colorScheme.primary.withOpacity(0.15),
          highlightColor: theme.colorScheme.primary.withOpacity(0.08),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: trailing != null ? 4.0 : 12.0),
            child: Row(
              children: [
                Icon(icon, size: 22, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.8)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.9)),
                  ),
                ),
                // ignore: use_null_aware_elements
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), height: 1),
    );
  }

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Broken.folder, color: theme.colorScheme.primary, size: 36),
                ),
                const SizedBox(height: 16),
                Text('NFile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Version 1.0.22', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Text(
                  'A premium, fluid, and open-source file manager and offline media hub built with Flutter. Designed for extreme performance and elegance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.8), fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
