import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/quick_categories_grid.dart';

class MoreSettingsScreen extends StatelessWidget {
  const MoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Settings'),
        leading: IconButton(
          icon: const Icon(Broken.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          children: [
            _buildSectionHeader(theme, 'Browser Experience'),
            _buildSettingTile(
              theme,
              icon: Broken.folder_favorite,
              title: 'Default to Browse Screen',
              subtitle: 'Directly launch into the Browse storage explorer on app start',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.defaultToBrowseScreen,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleDefaultToBrowseScreen(),
                ),
              ),
              onTap: () => fileManager.toggleDefaultToBrowseScreen(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.add_square,
              title: "Show Floating '+' Button",
              subtitle: 'Enable quick creation (+) button at bottom of Browse screen',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFloatingAddButton,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleFloatingAddButton(),
                ),
              ),
              onTap: () => fileManager.toggleFloatingAddButton(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.folder_open,
              title: 'Show Hidden Files',
              subtitle: 'Display system files and folders starting with a dot (.)',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showHiddenFiles,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHiddenFiles(),
                ),
              ),
              onTap: () => fileManager.toggleHiddenFiles(),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Appearance & Themes'),
            _buildSettingTile(
              theme,
              icon: Broken.colorfilter,
              title: 'Accent Color / Dynamic Theme',
              subtitle: _getAccentColorLabel(fileManager.accentColorOption),
              onTap: () => _showThemePickerDialog(context, fileManager, theme),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(theme, 'Home Screen'),
            _buildSettingTile(
              theme,
              icon: Broken.setting_2,
              title: 'Customize Shortcuts',
              subtitle: 'Reorder and toggle visibility of quick category items',
              onTap: () => QuickCategoriesGrid.showCustomizeDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  String _getAccentColorLabel(String option) {
    switch (option) {
      case 'dynamic': return 'Material You (Dynamic Wallpaper Colors)';
      case 'orange': return 'Vibrant Orange';
      case 'purple': return 'Royal Purple';
      case 'green': return 'Emerald Green';
      case 'red': return 'Crimson Red';
      case 'gold': return 'Amber Gold';
      case 'blue':
      default:
        return 'Original Default (Signature Blue)';
    }
  }

  void _showThemePickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final current = fileManager.accentColorOption;
        final options = [
          {'key': 'blue', 'name': 'Original Default (Signature Blue)', 'color': const Color(0xFF369FE7)},
          {'key': 'dynamic', 'name': 'Material You (Dynamic Wallpaper Colors)', 'color': Colors.teal},
          {'key': 'orange', 'name': 'Vibrant Orange', 'color': const Color(0xFFFF6D00)},
          {'key': 'purple', 'name': 'Royal Purple', 'color': const Color(0xFF8E24AA)},
          {'key': 'green', 'name': 'Emerald Green', 'color': const Color(0xFF00C853)},
          {'key': 'red', 'name': 'Crimson Red', 'color': const Color(0xFFD50000)},
          {'key': 'gold', 'name': 'Amber Gold', 'color': const Color(0xFFFFD600)},
        ];

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Choose Accent Theme', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options[i];
                        final key = opt['key'] as String;
                        final name = opt['name'] as String;
                        final color = opt['color'] as Color;
                        final isSelected = current == key;

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: key == 'dynamic' ? theme.colorScheme.primary : color,
                              shape: BoxShape.circle,
                            ),
                            child: key == 'dynamic' 
                                ? const Icon(Broken.colorfilter, color: Colors.white, size: 20)
                                : isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                          title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          trailing: isSelected ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                          onTap: () {
                            fileManager.setAccentColorOption(key);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: theme.colorScheme.primary.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        titleAlignment: ListTileTitleAlignment.center,
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            title, 
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.2),
          ),
        ),
        subtitle: Text(
          subtitle, 
          style: TextStyle(fontSize: 12.5, height: 1.3, color: theme.colorScheme.onSurface.withOpacity(0.65)),
        ),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
