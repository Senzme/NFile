import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../core/utils.dart';
import '../widgets/quick_categories_grid.dart';
import '../../services/preferences_service.dart';
import '../../services/recycle_bin_service.dart';
import 'package:path/path.dart' as p;
import 'internal_file_picker_screen.dart';

class MoreSettingsScreen extends StatefulWidget {
  const MoreSettingsScreen({super.key});

  @override
  State<MoreSettingsScreen> createState() => _MoreSettingsScreenState();
}

class _MoreSettingsScreenState extends State<MoreSettingsScreen> {
  bool _preferFolders = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _preferFolders = PreferencesService.getPreferFoldersInMedia();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _shouldShow(String title, String subtitle) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery.toLowerCase();
    return title.toLowerCase().contains(query) || subtitle.toLowerCase().contains(query);
  }

  bool _shouldShowHeader(List<bool> visibilities) {
    if (_searchQuery.isEmpty) return true;
    return visibilities.contains(true);
  }

  Widget _buildCategoryCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget targetScreen,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: theme.colorScheme.surface.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetScreen),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    // Visibilities for global search filtering
    final showAddressBarVis = _shouldShow('Show Address Bar', 'Display an editable Windows-Explorer-style address bar at the top of file list');
    final preferFoldersVis = _shouldShow('Default Album Preferred View', 'Open Images/Videos quick categories directly in Folders (Albums) preferred view');
    final hideNavBarVis = _shouldShow('Hide Android Navigation Bar', 'Hide bottom navigation bar to maximize screen real estate (swiping up displays it)');
    final resetViewersVis = _shouldShow('Reset Default File Viewers', 'Clear all remembered "Open With" associations for file viewers');
    final skipDialogVis = _shouldShow('Skip "Open With" Dialog', 'Bypass the application choice dialog and immediately open files with default viewers');
    final defaultBrowseVis = _shouldShow('Default to Browse Screen', 'Directly launch into the Browse storage explorer on app start');
    final showFloatingVis = _shouldShow("Show Floating '+' Button", 'Enable quick creation (+) button at bottom of Browse screen');
    final showHiddenVis = _shouldShow('Show Hidden Files', 'Display system files and folders starting with a dot (.)');
    final folderFileCountVis = _shouldShow('Show Folder & File Count Header', 'Display total folders and files count under storage title bar');
    final use24HourVis = _shouldShow('Use 24-Hour Time Format', 'Toggle between 12-hour (AM/PM) and 24-hour time formatting across lists');
    final hideTimeDateVis = _shouldShow('Hide Time & Date from Lists', 'Completely hide modification dates and times under files and folders');
    final folderContentsVis = _shouldShow('Show Folder Content Count', 'Calculate and display total files and folders inside directory listings');
    final folderSizesVis = _shouldShow('Show Folder Size', 'Calculate and display total size of all files inside directories (can affect listing performance)');
    final bottomActionBarVis = _shouldShow('Show Bottom Navigation Bar', 'Enable bottom action bar on Browse screen');
    final hideActionTextVis = _shouldShow('Hide Action Bar Text Labels', 'Show only icons in selection action bar at bottom of Browse & Media screens');
    final showHomeBrowseNavVis = _shouldShow('Show Home & Browse Bottom Bar', 'Toggle bottom navigation bar visibility on the Home screen');
    final highlightFolderVis = _shouldShow('Highlight Exited Folder', 'Briefly flash and scroll to the folder you just exited when going back');
    final mediaPreviewsVis = _shouldShow('Show Media Previews', 'Display actual image and video thumbnails instead of generic file icons');
    final adaptiveNamesVis = _shouldShow('Adaptive Multi-line Filenames', 'Allow filenames to wrap 3 lines instead of truncating');
    final hideActionButtonsVis = _shouldShow('Hide 3-Dot Action Buttons', 'Hide the three-dot option menu button next to folders and files');
    final dragDropVis = _shouldShow('Enable Drag & Drop', 'Long press and drag folders or files to move them into other folders');
    final confirmDragVis = fileManager.enableDragDrop && _shouldShow('Confirm Drag & Drop Actions', 'Show options popup (Copy, Move, Archive) when dropping files');
    final multipleTabsVis = _shouldShow('Enable Multiple Tabs', 'Allow opening multiple folders in separate tabs for quick navigation');
    final splitScreenVis = _shouldShow('Enable Split Screen', 'Browse two directories side by side and transfer files easily');
    final disableLeftBackVis = _shouldShow('Prevent Left Back Gesture for Drawer', 'Excludes the left edge of the screen from Android system back gestures, making it easier to swipe open the drawer. You can still swipe from the right edge to go back.');
    final rememberLastFolderVis = _shouldShow('Remember Last Opened Folder', 'Open the last folder you browsed when launching the app');
    final hideNavLabelsVis = _shouldShow('Hide Bottom Navigation Labels', 'Hide text labels of the bottom bar (Home/Browse) for a cleaner and compact look');

    final generalStartupList = [
      defaultBrowseVis,
      rememberLastFolderVis,
      showHomeBrowseNavVis,
      hideNavLabelsVis,
      hideNavBarVis,
      disableLeftBackVis,
    ];

    final fileExplorerList = [
      showAddressBarVis,
      showFloatingVis,
      showHiddenVis,
      highlightFolderVis,
      multipleTabsVis,
      splitScreenVis,
      dragDropVis,
      confirmDragVis,
    ];

    final listLayoutList = [
      folderFileCountVis,
      folderContentsVis,
      folderSizesVis,
      use24HourVis,
      hideTimeDateVis,
      adaptiveNamesVis,
      hideActionButtonsVis,
    ];

    final mediaActionsList = [
      preferFoldersVis,
      mediaPreviewsVis,
      skipDialogVis,
      resetViewersVis,
    ];

    final selectionActionBarList = [
      bottomActionBarVis,
      hideActionTextVis,
    ];

    final recycleBinVis = _shouldShow('Enable Recycle Bin', 'Move deleted files and folders to a hidden Recycle Bin instead of deleting permanently');
    final autoDeleteDurationVis = RecycleBinService.isEnabled() && _shouldShow('Auto-Delete Trash Duration', _getAutoDeleteDaysLabel(RecycleBinService.getAutoDeleteDays()));
    final recycleBinList = [recycleBinVis, autoDeleteDurationVis];

    final accentColorVis = _shouldShow('Accent Color / Dynamic Theme', _getAccentColorLabel(fileManager.accentColorOption));
    final folderIconVis = _shouldShow('Folder Icon Style', _getFolderIconLabel(fileManager.folderIconOption));
    final menuIconStyleVis = _shouldShow('App Drawer Button Style', _getMenuIconStyleLabel(fileManager.menuIconStyle));
    final amoledVis = _shouldShow('AMOLED Black Mode', 'Use pitch black background in Dark Mode for AMOLED screens');
    final appIconVis = _shouldShow('App Icon', _getAppIconLabel(fileManager.activeAppIcon));
    final typographyVis = _shouldShow('App Typography / Font Family', _getFontFamilyLabel(fileManager.fontFamilyOption));
    final appearanceList = [accentColorVis, folderIconVis, menuIconStyleVis, amoledVis, appIconVis, typographyVis];

    final customizeShortcutsVis = _shouldShow('Customize Shortcuts', 'Reorder and toggle visibility of quick category items');
    final showRecentVis = _shouldShow('Show Recent Files', 'Display the list of recently accessed files on the Home screen');
    final homeScreenList = [customizeShortcutsVis, showRecentVis];

    final hasAnyMatch = generalStartupList.contains(true) ||
        fileExplorerList.contains(true) ||
        listLayoutList.contains(true) ||
        mediaActionsList.contains(true) ||
        selectionActionBarList.contains(true) ||
        recycleBinList.contains(true) ||
        appearanceList.contains(true) ||
        homeScreenList.contains(true);

    return PopScope(
      canPop: !_isSearching,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchQuery = '';
            _searchController.clear();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search settings...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                )
              : const Text('More Settings'),
          leading: IconButton(
            icon: const Icon(Broken.arrow_left),
            onPressed: () {
              if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  setState(() {
                    if (_searchController.text.isEmpty) {
                      _isSearching = false;
                    } else {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  });
                },
              )
            else
              IconButton(
                icon: const Icon(Broken.search_normal),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            children: [
              if (_searchQuery.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0, left: 4.0),
                  child: Text(
                    'Settings Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.setting_2,
                  title: 'General & Behavior',
                  subtitle: 'Default screen, navigation controls, and shortcuts',
                  targetScreen: const GeneralSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.colorfilter,
                  title: 'Appearance & Themes',
                  subtitle: 'Themes, app icons, folder styles, and typography',
                  targetScreen: const AppearanceSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.folder_open,
                  title: 'File Explorer Options',
                  subtitle: 'Address bar, hidden files, tabs, and drag & drop',
                  targetScreen: const ExplorerSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.text,
                  title: 'List & Layout Styling',
                  subtitle: 'Folder sizes, counts, and time/date formats',
                  targetScreen: const LayoutSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.image,
                  title: 'Media Preferences',
                  subtitle: 'Default album view and thumbnail previews',
                  targetScreen: const MediaSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.setting_3,
                  title: 'File Actions & Viewers',
                  subtitle: 'Open actions and default viewers configuration',
                  targetScreen: const ActionsSettingsScreen(),
                ),
                _buildCategoryCard(
                  context,
                  theme,
                  icon: Broken.trash,
                  title: 'Recycle Bin (Trash)',
                  subtitle: 'Recycle bin toggles and auto-delete duration',
                  targetScreen: const TrashSettingsScreen(),
                ),
              ] else ...[
                if (!hasAnyMatch) ...[
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Broken.search_normal,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No settings found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Try searching for another keyword',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  if (_shouldShowHeader(generalStartupList) || _shouldShowHeader(selectionActionBarList) || _shouldShowHeader(homeScreenList)) ...[
                    _buildSectionHeader(theme, 'General & Behavior'),
                    if (defaultBrowseVis)
                      SettingsTile(
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
                    if (rememberLastFolderVis)
                      SettingsTile(
                        icon: Broken.folder_open,
                        title: 'Remember Last Opened Folder',
                        subtitle: 'Open the last folder you browsed when launching the app',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.rememberLastFolder,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleRememberLastFolder(),
                          ),
                        ),
                        onTap: () => fileManager.toggleRememberLastFolder(),
                      ),
                    if (showHomeBrowseNavVis)
                      SettingsTile(
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
                    if (hideNavLabelsVis)
                      SettingsTile(
                        icon: Broken.menu_1,
                        title: 'Hide Bottom Navigation Labels',
                        subtitle: 'Hide text labels of the bottom bar (Home/Browse) for a cleaner and compact look',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideNavLabels,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideNavLabels(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideNavLabels(),
                      ),
                    if (hideNavBarVis)
                      SettingsTile(
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
                    if (disableLeftBackVis)
                      SettingsTile(
                        icon: Icons.gesture,
                        title: 'Prevent Left Back Gesture for Drawer',
                        subtitle: 'Excludes the left edge of the screen from Android system back gestures, making it easier to swipe open the drawer. You can still swipe from the right edge to go back.',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.disableLeftBackGesture,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleDisableLeftBackGesture(),
                          ),
                        ),
                        onTap: () => fileManager.toggleDisableLeftBackGesture(),
                      ),
                    if (bottomActionBarVis)
                      SettingsTile(
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
                    if (hideActionTextVis)
                      SettingsTile(
                        icon: Icons.label_off_rounded,
                        title: 'Hide Action Bar Text Labels',
                        subtitle: 'Show only icons in selection action bar at bottom of Browse & Media screens',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideActionText,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideActionText(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideActionText(),
                      ),
                    if (customizeShortcutsVis)
                      SettingsTile(
                        icon: Broken.setting_2,
                        title: 'Customize Shortcuts',
                        subtitle: 'Reorder and toggle visibility of quick category items',
                        onTap: () => QuickCategoriesGrid.showCustomizeDialog(context),
                      ),
                    if (showRecentVis)
                      SettingsTile(
                        icon: Broken.clock,
                        title: 'Show Recent Files',
                        subtitle: 'Display the list of recently accessed files on the Home screen',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showRecentFiles,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleShowRecentFiles(),
                          ),
                        ),
                        onTap: () => fileManager.toggleShowRecentFiles(),
                      ),
                  ],
                  if (_shouldShowHeader(appearanceList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'Appearance & Themes'),
                    if (accentColorVis)
                      SettingsTile(
                        icon: Broken.colorfilter,
                        title: 'Accent Color / Dynamic Theme',
                        subtitle: _getAccentColorLabel(fileManager.accentColorOption),
                        onTap: () => _showThemePickerDialog(context, fileManager, theme),
                      ),
                    if (folderIconVis)
                      SettingsTile(
                        icon: FileUtils.getFolderIcon(fileManager.folderIconOption),
                        title: 'Folder Icon Style',
                        subtitle: _getFolderIconLabel(fileManager.folderIconOption),
                        onTap: () => _showFolderIconPickerDialog(context, fileManager, theme),
                      ),
                    if (menuIconStyleVis)
                      SettingsTile(
                        icon: Broken.category,
                        title: 'App Drawer Button Style',
                        subtitle: _getMenuIconStyleLabel(fileManager.menuIconStyle),
                        onTap: () => _showMenuIconStylePickerDialog(context, fileManager, theme),
                      ),
                    if (amoledVis)
                      SettingsTile(
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
                    if (appIconVis)
                      SettingsTile(
                        icon: Broken.category,
                        title: 'App Icon',
                        subtitle: _getAppIconLabel(fileManager.activeAppIcon),
                        onTap: () => _showAppIconPickerDialog(context, fileManager, theme),
                      ),
                    if (typographyVis)
                      SettingsTile(
                        icon: Broken.text,
                        title: 'App Typography / Font Family',
                        subtitle: _getFontFamilyLabel(fileManager.fontFamilyOption),
                        onTap: () => _showFontFamilyPickerDialog(context, fileManager, theme),
                      ),
                  ],
                  if (_shouldShowHeader(fileExplorerList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'File Explorer & Navigation'),
                    if (showAddressBarVis)
                      SettingsTile(
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
                    if (showFloatingVis)
                      SettingsTile(
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
                    if (showHiddenVis)
                      SettingsTile(
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
                    if (highlightFolderVis)
                      SettingsTile(
                        icon: Broken.colorfilter,
                        title: 'Highlight Exited Folder',
                        subtitle: 'Briefly flash and scroll to the folder you just exited when going back',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.enableFolderHighlight,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleEnableFolderHighlight(),
                          ),
                        ),
                        onTap: () => fileManager.toggleEnableFolderHighlight(),
                      ),
                    if (multipleTabsVis)
                      SettingsTile(
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
                    if (splitScreenVis)
                      SettingsTile(
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
                    if (dragDropVis)
                      SettingsTile(
                        icon: Broken.folder_connection,
                        title: 'Enable Drag & Drop',
                        subtitle: 'Long press and drag folders or files to move them into other folders',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.enableDragDrop,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleEnableDragDrop(),
                          ),
                        ),
                        onTap: () => fileManager.toggleEnableDragDrop(),
                      ),
                    if (confirmDragVis)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0),
                        child: SettingsTile(
                          icon: Broken.task_square,
                          title: 'Confirm Drag & Drop Actions',
                          subtitle: 'Show options popup (Copy, Move, Archive) when dropping files',
                          trailing: Transform.scale(
                            scale: 0.85,
                            child: Switch(
                              value: fileManager.showDragDropDialog,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (_) => fileManager.toggleShowDragDropDialog(),
                            ),
                          ),
                          onTap: () => fileManager.toggleShowDragDropDialog(),
                        ),
                      ),
                  ],
                  if (_shouldShowHeader(listLayoutList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'List & Layout Styling'),
                    if (folderFileCountVis)
                      SettingsTile(
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
                    if (folderContentsVis)
                      SettingsTile(
                        icon: Broken.folder_open,
                        title: 'Show Folder Content Count',
                        subtitle: 'Calculate and display total files and folders inside directory listings',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showFolderContentsCount,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleFolderContentsCount(),
                          ),
                        ),
                        onTap: () => fileManager.toggleFolderContentsCount(),
                      ),
                    if (folderSizesVis)
                      SettingsTile(
                        icon: Broken.document_text_1,
                        title: 'Show Folder Size',
                        subtitle: 'Calculate and display total size of all files inside directories (can affect listing performance)',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.showFolderSizes,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleShowFolderSizes(),
                          ),
                        ),
                        onTap: () => fileManager.toggleShowFolderSizes(),
                      ),
                    if (use24HourVis)
                      SettingsTile(
                        icon: Icons.access_time_rounded,
                        title: 'Use 24-Hour Time Format',
                        subtitle: 'Toggle between 12-hour (AM/PM) and 24-hour time formatting across lists',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.use24HourFormat,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleUse24HourFormat(),
                          ),
                        ),
                        onTap: () => fileManager.toggleUse24HourFormat(),
                      ),
                    if (hideTimeDateVis)
                      SettingsTile(
                        icon: Icons.visibility_off_rounded,
                        title: 'Hide Time & Date from Lists',
                        subtitle: 'Completely hide modification dates and times under files and folders',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideTimeAndDate,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideTimeAndDate(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideTimeAndDate(),
                      ),
                    if (adaptiveNamesVis)
                      SettingsTile(
                        icon: Broken.text,
                        title: 'Adaptive Multi-line Filenames',
                        subtitle: 'Allow filenames to wrap 3 lines instead of truncating',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.adaptiveMultiLineNames,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleAdaptiveMultiLineNames(),
                          ),
                        ),
                        onTap: () => fileManager.toggleAdaptiveMultiLineNames(),
                      ),
                    if (hideActionButtonsVis)
                      SettingsTile(
                        icon: Icons.more_vert_rounded,
                        title: 'Hide 3-Dot Action Buttons',
                        subtitle: 'Hide the three-dot option menu button next to folders and files',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: fileManager.hideActionMenuButtons,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (_) => fileManager.toggleHideActionMenuButtons(),
                          ),
                        ),
                        onTap: () => fileManager.toggleHideActionMenuButtons(),
                      ),
                  ],
                  if (_shouldShowHeader(mediaActionsList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'Media & Default Actions'),
                    if (preferFoldersVis)
                      SettingsTile(
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
                    if (mediaPreviewsVis)
                      SettingsTile(
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
                    if (skipDialogVis)
                      SettingsTile(
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
                    if (resetViewersVis)
                      SettingsTile(
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
                  ],
                  if (_shouldShowHeader(recycleBinList)) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader(theme, 'Recycle Bin (Trash)'),
                    if (recycleBinVis)
                      SettingsTile(
                        icon: Broken.trash,
                        title: 'Enable Recycle Bin',
                        subtitle: 'Move deleted files and folders to a hidden Recycle Bin instead of deleting permanently',
                        trailing: Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: RecycleBinService.isEnabled(),
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                RecycleBinService.setEnabled(val);
                              });
                            },
                          ),
                        ),
                        onTap: () {
                          final val = !RecycleBinService.isEnabled();
                          setState(() {
                            RecycleBinService.setEnabled(val);
                          });
                        },
                      ),
                    if (autoDeleteDurationVis)
                      SettingsTile(
                        icon: Icons.access_time_rounded,
                        title: 'Auto-Delete Trash Duration',
                        subtitle: _getAutoDeleteDaysLabel(RecycleBinService.getAutoDeleteDays()),
                        onTap: () => _showAutoDeleteDaysPickerDialog(context, theme, () {
                          setState(() {});
                        }),
                      ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
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
}

// ----------------------------------------------------
// Reusable Settings Tile
// ----------------------------------------------------
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

// ----------------------------------------------------
// Sub-Category Settings Screens
// ----------------------------------------------------

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('General & Behavior'),
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
            SettingsTile(
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
            SettingsTile(
              icon: Broken.folder_open,
              title: 'Remember Last Opened Folder',
              subtitle: 'Open the last folder you browsed when launching the app',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.rememberLastFolder,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleRememberLastFolder(),
                ),
              ),
              onTap: () => fileManager.toggleRememberLastFolder(),
            ),
            SettingsTile(
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
            SettingsTile(
              icon: Broken.menu_1,
              title: 'Hide Bottom Navigation Labels',
              subtitle: 'Hide text labels of the bottom bar (Home/Browse) for a cleaner and compact look',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideNavLabels,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideNavLabels(),
                ),
              ),
              onTap: () => fileManager.toggleHideNavLabels(),
            ),
            SettingsTile(
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
            SettingsTile(
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
            SettingsTile(
              icon: Icons.label_off_rounded,
              title: 'Hide Action Bar Text Labels',
              subtitle: 'Show only icons in selection action bar at bottom of Browse & Media screens',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideActionText,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideActionText(),
                ),
              ),
              onTap: () => fileManager.toggleHideActionText(),
            ),
            SettingsTile(
              icon: Broken.setting_2,
              title: 'Customize Shortcuts',
              subtitle: 'Reorder and toggle visibility of quick category items',
              onTap: () => QuickCategoriesGrid.showCustomizeDialog(context),
            ),
            SettingsTile(
              icon: Broken.clock,
              title: 'Show Recent Files',
              subtitle: 'Display the list of recently accessed files on the Home screen',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showRecentFiles,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowRecentFiles(),
                ),
              ),
              onTap: () => fileManager.toggleShowRecentFiles(),
            ),
            SettingsTile(
              icon: Icons.gesture,
              title: 'Prevent Left Back Gesture for Drawer',
              subtitle: 'Excludes the left edge of the screen from Android system back gestures, making it easier to swipe open the drawer. You can still swipe from the right edge to go back.',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.disableLeftBackGesture,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleDisableLeftBackGesture(),
                ),
              ),
              onTap: () => fileManager.toggleDisableLeftBackGesture(),
            ),
          ],
        ),
      ),
    );
  }
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appearance & Themes'),
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
            SettingsTile(
              icon: Broken.colorfilter,
              title: 'Accent Color / Dynamic Theme',
              subtitle: _getAccentColorLabel(fileManager.accentColorOption),
              onTap: () => _showThemePickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: FileUtils.getFolderIcon(fileManager.folderIconOption),
              title: 'Folder Icon Style',
              subtitle: _getFolderIconLabel(fileManager.folderIconOption),
              onTap: () => _showFolderIconPickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: Broken.category,
              title: 'App Drawer Button Style',
              subtitle: _getMenuIconStyleLabel(fileManager.menuIconStyle),
              onTap: () => _showMenuIconStylePickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
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
            SettingsTile(
              icon: Broken.category,
              title: 'App Icon',
              subtitle: _getAppIconLabel(fileManager.activeAppIcon),
              onTap: () => _showAppIconPickerDialog(context, fileManager, theme),
            ),
            SettingsTile(
              icon: Broken.text,
              title: 'App Typography / Font Family',
              subtitle: _getFontFamilyLabel(fileManager.fontFamilyOption),
              onTap: () => _showFontFamilyPickerDialog(context, fileManager, theme),
            ),
          ],
        ),
      ),
    );
  }
}

class ExplorerSettingsScreen extends StatelessWidget {
  const ExplorerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Explorer Options'),
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
            SettingsTile(
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
            SettingsTile(
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
            SettingsTile(
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
            SettingsTile(
              icon: Broken.colorfilter,
              title: 'Highlight Exited Folder',
              subtitle: 'Briefly flash and scroll to the folder you just exited when going back',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableFolderHighlight,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleEnableFolderHighlight(),
                ),
              ),
              onTap: () => fileManager.toggleEnableFolderHighlight(),
            ),
            SettingsTile(
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
            SettingsTile(
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
            SettingsTile(
              icon: Broken.folder_connection,
              title: 'Enable Drag & Drop',
              subtitle: 'Long press and drag folders or files to move them into other folders',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.enableDragDrop,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleEnableDragDrop(),
                ),
              ),
              onTap: () => fileManager.toggleEnableDragDrop(),
            ),
            if (fileManager.enableDragDrop)
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: SettingsTile(
                  icon: Broken.task_square,
                  title: 'Confirm Drag & Drop Actions',
                  subtitle: 'Show options popup (Copy, Move, Archive) when dropping files',
                  trailing: Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: fileManager.showDragDropDialog,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (_) => fileManager.toggleShowDragDropDialog(),
                    ),
                  ),
                  onTap: () => fileManager.toggleShowDragDropDialog(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LayoutSettingsScreen extends StatelessWidget {
  const LayoutSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('List & Layout Styling'),
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
            SettingsTile(
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
            SettingsTile(
              icon: Broken.folder_open,
              title: 'Show Folder Content Count',
              subtitle: 'Calculate and display total files and folders inside directory listings',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFolderContentsCount,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleFolderContentsCount(),
                ),
              ),
              onTap: () => fileManager.toggleFolderContentsCount(),
            ),
            SettingsTile(
              icon: Broken.document_text_1,
              title: 'Show Folder Size',
              subtitle: 'Calculate and display total size of all files inside directories (can affect listing performance)',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.showFolderSizes,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleShowFolderSizes(),
                ),
              ),
              onTap: () => fileManager.toggleShowFolderSizes(),
            ),
            SettingsTile(
              icon: Icons.access_time_rounded,
              title: 'Use 24-Hour Time Format',
              subtitle: 'Toggle between 12-hour (AM/PM) and 24-hour time formatting across lists',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.use24HourFormat,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleUse24HourFormat(),
                ),
              ),
              onTap: () => fileManager.toggleUse24HourFormat(),
            ),
            SettingsTile(
              icon: Icons.visibility_off_rounded,
              title: 'Hide Time & Date from Lists',
              subtitle: 'Completely hide modification dates and times under files and folders',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideTimeAndDate,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideTimeAndDate(),
                ),
              ),
              onTap: () => fileManager.toggleHideTimeAndDate(),
            ),
            SettingsTile(
              icon: Broken.text,
              title: 'Adaptive Multi-line Filenames',
              subtitle: 'Allow filenames to wrap 3 lines instead of truncating',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.adaptiveMultiLineNames,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleAdaptiveMultiLineNames(),
                ),
              ),
              onTap: () => fileManager.toggleAdaptiveMultiLineNames(),
            ),
            SettingsTile(
              icon: Icons.more_vert_rounded,
              title: 'Hide 3-Dot Action Buttons',
              subtitle: 'Hide the three-dot option menu button next to folders and files',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: fileManager.hideActionMenuButtons,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (_) => fileManager.toggleHideActionMenuButtons(),
                ),
              ),
              onTap: () => fileManager.toggleHideActionMenuButtons(),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaSettingsScreen extends StatefulWidget {
  const MediaSettingsScreen({super.key});

  @override
  State<MediaSettingsScreen> createState() => _MediaSettingsScreenState();
}

class _MediaSettingsScreenState extends State<MediaSettingsScreen> {
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
        title: const Text('Media Preferences'),
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
            SettingsTile(
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
            SettingsTile(
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
          ],
        ),
      ),
    );
  }
}

class ActionsSettingsScreen extends StatelessWidget {
  const ActionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileManager = context.watch<FileManagerProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Actions & Viewers'),
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
            SettingsTile(
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
            SettingsTile(
              icon: Broken.refresh_2,
              title: 'Reset Default File Viewers',
              subtitle: 'Clear all remembered "Open With" associations for file viewers',
              onTap: () async {
                await PreferencesService.clearAllDefaultOpenActions();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All default viewer choices have been reset'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class TrashSettingsScreen extends StatefulWidget {
  const TrashSettingsScreen({super.key});

  @override
  State<TrashSettingsScreen> createState() => _TrashSettingsScreenState();
}

class _TrashSettingsScreenState extends State<TrashSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin (Trash)'),
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
            SettingsTile(
              icon: Broken.trash,
              title: 'Enable Recycle Bin',
              subtitle: 'Move deleted files and folders to a hidden Recycle Bin instead of deleting permanently',
              trailing: Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: RecycleBinService.isEnabled(),
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      RecycleBinService.setEnabled(val);
                    });
                  },
                ),
              ),
              onTap: () {
                final val = !RecycleBinService.isEnabled();
                setState(() {
                  RecycleBinService.setEnabled(val);
                });
              },
            ),
            if (RecycleBinService.isEnabled())
              SettingsTile(
                icon: Icons.access_time_rounded,
                title: 'Auto-Delete Trash Duration',
                subtitle: _getAutoDeleteDaysLabel(RecycleBinService.getAutoDeleteDays()),
                onTap: () => _showAutoDeleteDaysPickerDialog(context, theme, () {
                  setState(() {});
                }),
              ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Global Helper Labels & Dialogs for Themes & Settings
// ----------------------------------------------------

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

String _getMenuIconStyleLabel(String option) {
  switch (option) {
    case 'category': return 'Category Grid / Vuesax Grid';
    case 'hamburger':
    default:
      return 'Hamburger / Classic Menu';
  }
}

String _getAppIconLabel(String option) {
  switch (option) {
    case 'logo1': return 'Logo 1';
    case 'logo2': return 'Logo 2';
    case 'logo3': return 'Logo 3';
    case 'logo4': return 'Logo 4';
    case 'default':
    default:
      return 'Default Logo';
  }
}

String _getFontFamilyLabel(String option) {
  switch (option) {
    case 'nothing': return 'Dot-Matrix & Sans';
    case 'outfit': return 'Outfit Modern Sans';
    case 'jetbrains': return 'JetBrains Tech Mono';
    case 'montserrat': return 'Montserrat Urban Sans';
    case 'custom': return 'Custom Imported Font';
    case 'default':
    default:
      return 'Signature Default (Lexend Deca)';
  }
}

String _getAutoDeleteDaysLabel(int days) {
  if (days <= 0) return 'Never (Auto-delete disabled)';
  if (days == 1) return 'After 1 Day';
  return 'After $days Days';
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

void _showMenuIconStylePickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = fileManager.menuIconStyle;
      final options = [
        {'key': 'hamburger', 'name': 'Hamburger / Classic Menu', 'icon': Broken.menu},
        {'key': 'category', 'name': 'Category Grid / Vuesax Grid', 'icon': Broken.category},
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
                    child: Text('Choose Drawer Button Style', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                          fileManager.setMenuIconStyle(key);
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

void _showAppIconPickerDialog(BuildContext context, FileManagerProvider fileManager, ThemeData theme) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'App Icon Picker',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
    transitionBuilder: (context, anim1, anim2, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(
          opacity: anim1,
          child: AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Broken.category, color: theme.colorScheme.primary, size: 26),
                const SizedBox(width: 12),
                const Text('App Launcher Icon', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose a custom logo for the application launcher icon. Note that some launchers may take a few seconds to update.',
                    style: TextStyle(fontSize: 13, height: 1.3, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                        children: [
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'default',
                            title: 'Logo',
                            imagePath: 'assets/ic_launcher.webp',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo1',
                            title: 'Logo 1',
                            imagePath: 'assets/logo/n1.png',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo2',
                            title: 'Logo 2',
                            imagePath: 'assets/logo/n2.png',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo3',
                            title: 'Logo 3',
                            imagePath: 'assets/logo/n3.png',
                          ),
                          _buildIconOptionCard(
                            context,
                            fileManager,
                            theme,
                            id: 'logo4',
                            title: 'Logo 4',
                            imagePath: 'assets/logo/n4.png',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildIconOptionCard(
  BuildContext context,
  FileManagerProvider fileManager,
  ThemeData theme, {
  required String id,
  required String title,
  required String imagePath,
}) {
  final isSelected = fileManager.activeAppIcon == id;

  return Card(
    color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : theme.colorScheme.surfaceVariant.withOpacity(0.15),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.08),
        width: isSelected ? 2.0 : 1.0,
      ),
    ),
    child: InkWell(
      onTap: () {
        fileManager.setActiveAppIcon(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('App icon switched to $title successfully!'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.withOpacity(0.2),
                  child: const Icon(Icons.broken_image, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
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
      final hasCustomFont = fileManager.customFontPath != null;
      final options = [
        {'key': 'default', 'name': 'Signature Default (Lexend Deca)', 'desc': 'Original NFile clean geometric look'},
        {'key': 'nothing', 'name': 'Nothing Dot-Matrix & Sans', 'desc': 'High-tech retro dot matrix headings + clean body'},
        {'key': 'outfit', 'name': 'Outfit Modern Sans', 'desc': 'Super sleek, minimal, and premium geometric aesthetic'},
        {'key': 'jetbrains', 'name': 'JetBrains Tech Mono', 'desc': 'Clean and futuristic developer monospaced look'},
        {'key': 'montserrat', 'name': 'Montserrat Urban Sans', 'desc': 'Bold, modern, and striking typographic scale'},
        if (hasCustomFont)
          {'key': 'custom', 'name': 'Custom Font (${p.basename(fileManager.customFontPath!)})', 'desc': 'Your custom loaded font file'},
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Broken.document_upload, size: 20),
                    label: Text(
                      hasCustomFont ? 'Replace Custom Font File' : 'Import Custom Font File (.ttf/.otf)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'LexendDeca'),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final picked = await InternalFilePickerScreen.show(
                        context,
                        rootPath: fileManager.rootPath,
                      );
                      if (picked != null && picked.isNotEmpty) {
                        final filePat = picked.first;
                        final ext = p.extension(filePat).toLowerCase();
                        if (ext == '.ttf' || ext == '.otf') {
                          final success = await fileManager.setCustomFontPath(filePat);
                          if (success) {
                            fileManager.setFontFamilyOption('custom');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Custom font "${p.basename(filePat)}" applied successfully!')),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to load the selected font file.')),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Invalid File Type'),
                                content: const Text('Please select a valid OpenType (.otf) or TrueType (.ttf) font file.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                  if (hasCustomFont) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Broken.trash, size: 18, color: Colors.redAccent),
                      label: const Text('Remove Custom Font', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'LexendDeca')),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await fileManager.setCustomFontPath(null);
                        if (current == 'custom') {
                          fileManager.setFontFamilyOption('default');
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom font removed.')),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

void _showAutoDeleteDaysPickerDialog(BuildContext context, ThemeData theme, VoidCallback onChanged) {
  showModalBottomSheet(
    context: context,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) {
      final current = RecycleBinService.getAutoDeleteDays();
      final options = [
        {'days': 7, 'label': '7 Days'},
        {'days': 15, 'label': '15 Days'},
        {'days': 30, 'label': '30 Days (Recommended)'},
        {'days': 0, 'label': 'Never (Manually clean bin)'},
      ];

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Auto-Delete Trash Duration',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Items in the Recycle Bin will be permanently deleted after this duration.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((opt) {
                final days = opt['days'] as int;
                final label = opt['label'] as String;
                final isSelected = current == days;

                return Card(
                  color: isSelected ? theme.colorScheme.primary.withOpacity(0.12) : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withOpacity(0.08)),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      RecycleBinService.setAutoDeleteDays(days);
                      onChanged();
                      Navigator.pop(ctx);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isSelected) Icon(Icons.check_circle, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
