import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../widgets/quick_categories_grid.dart';
import '../../services/preferences_service.dart';

class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen> {
  bool _preferFolders = false;

  @override
  void initState() {
    super.initState();
    _preferFolders = PreferencesService.getPreferFoldersInMedia();
  }

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
              icon: Broken.edit,
              title: 'Show Address Bar',
              subtitle: 'Display an editable Windows-Explorer-style address bar at the top of file list',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showAddressBar,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowAddressBar(),
                ),
              ),
              onTap: () => fileManager.toggleShowAddressBar(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.folder_2,
              title: 'Default Album Preferred View',
              subtitle: 'Open Images/Videos quick categories directly in Folders (Albums) preferred view',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _preferFolders,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _preferFolders = val;
                    });
                    PreferencesService.savePreferFoldersInMedia(val);
                  },
                ),
              ),
              onTap: () {
                final val = !_preferFolders;
                setState(() {
                  _preferFolders = val;
                });
                PreferencesService.savePreferFoldersInMedia(val);
              },
            ),
            _buildSettingTile(
              theme,
              icon: Icons.android,
              title: 'Hide Android Navigation Bar',
              subtitle: 'Hide bottom navigation bar to maximize screen real estate (swiping up displays it)',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideNavigationBar,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideNavigationBar(),
                ),
              ),
              onTap: () => fileManager.toggleHideNavigationBar(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.refresh_2,
              title: 'Reset Default File Viewers',
              subtitle: 'Clear all remembered "Open With" associations for file viewers',
              onTap: () async {
                await PreferencesService.clearAllDefaultOpenActions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All default viewer choices have been reset'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            _buildSettingTile(
              theme,
              icon: Broken.setting_3,
              title: 'Skip "Open With" Dialog',
              subtitle: 'Bypass the application choice dialog and immediately open files with default viewers',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.skipOpenWithDialog,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleSkipOpenWithDialog(),
                ),
              ),
              onTap: () => fileManager.toggleSkipOpenWithDialog(),
            ),
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
            _buildSettingTile(
              theme,
              icon: Broken.document_text_1,
              title: 'Show Folder & File Count Header',
              subtitle: 'Display total folders and files count under storage title bar',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFolderFileCount,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleFolderFileCount(),
                ),
              ),
              onTap: () => fileManager.toggleFolderFileCount(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.menu,
              title: 'Show Bottom Navigation Bar',
              subtitle: 'Enable bottom action bar on Browse screen',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showBottomActionBar,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleBottomActionBar(),
                ),
              ),
              onTap: () => fileManager.toggleBottomActionBar(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.menu,
              title: 'Show Home & Browse Bottom Bar',
              subtitle: 'Toggle bottom navigation bar visibility on the Home screen',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showHomeBrowseNav,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowHomeBrowseNav(),
                ),
              ),
              onTap: () => fileManager.toggleShowHomeBrowseNav(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.image,
              title: 'Show Media Previews',
              subtitle: 'Display actual image and video thumbnails instead of generic file icons',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showMediaPreviews,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleMediaPreviews(),
                ),
              ),
              onTap: () => fileManager.toggleMediaPreviews(),
            ),
            _buildSettingTile(
              theme,
              icon: Broken.category,
              title: 'Enable Multiple Tabs',
              subtitle: 'Allow opening multiple folders in separate tabs for quick navigation',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableMultipleTabs,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleMultipleTabs(),
                ),
              ),
              onTap: () => fileManager.toggleMultipleTabs(),
            ),
            _buildSettingTile(
              theme,
              icon: Icons.splitscreen,
              title: 'Enable Split Screen',
              subtitle: 'Browse two directories side by side and transfer files easily',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableSplitScreen,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleSplitScreen(),
                ),
              ),
              onTap: () => fileManager.toggleSplitScreen(),
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
            _buildSettingTile(
              theme,
              icon: FileUtils.getFolderIcon(fileManager.folderIconOption),
              title: 'Folder Icon Style',
              subtitle: _getFolderIconLabel(fileManager.folderIconOption),
              onTap: () => _showFolderIconPickerDialog(context, fileManager, theme),
            ),
             _buildSettingTile(
               theme,
               icon: Broken.moon,
               title: 'AMOLED Black Mode',
               subtitle: 'Use pitch black background in Dark Mode for AMOLED screens',
               trailing: Transform.scale(
                 scale: 0.85,
                 child: Switch(
                   value: fileManager.amoledMode,
                   activeColor: theme.colorScheme.primary,
                   onChanged: (_) => fileManager.toggleAmoledMode(),
                 ),
               ),
               onTap: () => fileManager.toggleAmoledMode(),
             ),
             _buildSettingTile(
               theme,
               icon: Broken.text,
               title: 'App Typography / Font Family',
               subtitle: _getFontFamilyLabel(fileManager.fontFamilyOption),
               onTap: () => _showFontFamilyPickerDialog(context, fileManager, theme),
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
      case 'pink': return 'Cyberpunk Pink';
      case 'sapphire': return 'Sapphire Blue';
      case 'forest': return 'Forest Green';
      case 'peach': return 'Sunset Peach';
      case 'blue':
      default:
        return 'Original Default (Signature Blue)';
    }
  }

  String _getFolderIconLabel(String option) {
    switch (option) {
      case 'solid': return 'Classic Solid (Material)';
      case 'rounded': return 'Modern Rounded (Material)';
      case 'special': return 'Starred Special (Material)';
      case 'snippet': return 'Snippet Document (Material)';
      case 'outlined': return 'Minimal Outlined (Material)';
      case 'broken':
      default:
        return 'NFile Broken Outline (Default)';
    }
  }

  String _getFontFamilyLabel(String option) {
    switch (option) {
      case 'nothing': return 'Dot-Matrix & Sans';
      case 'outfit': return 'Outfit Modern Sans';
      case 'jetbrains': return 'JetBrains Tech Mono';
      case 'montserrat': return 'Montserrat Urban Sans';
      case 'default':
      default:
        return 'Signature Default (Lexend Deca)';
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
          {'key': 'pink', 'name': 'Cyberpunk Pink', 'color': const Color(0xFFFF2E93)},
          {'key': 'sapphire', 'name': 'Sapphire Blue', 'color': const Color(0xFF0F52BA)},
          {'key': 'forest', 'name': 'Forest Green', 'color': const Color(0xFF228B22)},
          {'key': 'peach', 'name': 'Sunset Peach', 'color': const Color(0xFFFF7F50)},
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

  void _showFolderIconPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final current = fileManager.folderIconOption;
        final options = [
          {'key': 'broken', 'name': 'NFile Broken Outline (Default)', 'icon': Broken.folder},
          {'key': 'rounded', 'name': 'Modern Rounded (Material)', 'icon': Icons.folder_rounded},
          {'key': 'solid', 'name': 'Classic Solid (Material)', 'icon': Icons.folder},
          {'key': 'special', 'name': 'Starred Special (Material)', 'icon': Icons.folder_special_rounded},
          {'key': 'snippet', 'name': 'Snippet Document (Material)', 'icon': Icons.snippet_folder_rounded},
          {'key': 'outlined', 'name': 'Minimal Outlined (Material)', 'icon': Icons.folder_outlined},
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
                      child: Text('Choose Folder Icon Style', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                        final icon = opt['icon'] as IconData;
                        final isSelected = current == key;

                        return ListTile(
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary, size: 20),
                          ),
                          title: Text(name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          trailing: isSelected ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                          onTap: () {
                            fileManager.setFolderIconOption(key);
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

  void _showFontFamilyPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final current = fileManager.fontFamilyOption;
        final options = [
          {'key': 'default', 'name': 'Signature Default (Lexend Deca)', 'desc': 'Original NFile clean geometric look'},
          {'key': 'nothing', 'name': 'Nothing Dot-Matrix & Sans', 'desc': 'High-tech retro dot matrix headings + clean body'},
          {'key': 'outfit', 'name': 'Outfit Modern Sans', 'desc': 'Super sleek, minimal, and premium geometric aesthetic'},
          {'key': 'jetbrains', 'name': 'JetBrains Tech Mono', 'desc': 'Clean and futuristic developer monospaced look'},
          {'key': 'montserrat', 'name': 'Montserrat Urban Sans', 'desc': 'Bold, modern, and striking typographic scale'},
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
                    Text(
                      'App Typography',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontFamily: 'LexendDeca'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select a beautiful typeface to customize NFile\'s overall visual theme',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13, fontFamily: 'LexendDeca'),
                    ),
                    const SizedBox(height: 16),
                    ...options.map((opt) {
                      final isSelected = current == opt['key'];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text(
                          opt['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                            fontFamily: 'LexendDeca',
                          ),
                        ),
                        subtitle: Text(
                          opt['desc']!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontFamily: 'LexendDeca',
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.radio_button_checked_rounded, color: theme.colorScheme.primary)
                            : Icon(Icons.radio_button_off_rounded, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                        onTap: () {
                          fileManager.setFontFamilyOption(opt['key']!);
                          Navigator.pop(ctx);
                        },
                      );
                    }),
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.6))),
        trailing: trailing != null ? IgnorePointer(child: trailing) : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
