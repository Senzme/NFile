import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/premium_storage_overview.dart';
import '../widgets/quick_categories_grid.dart';
import '../widgets/recent_files_section.dart';
import '../widgets/nfile_drawer.dart';
import 'directory_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  DateTime? _lastBrowseTapTime;

  @override
  void initState() {
    super.initState();
    _currentIndex = context.read<FileManagerProvider>().defaultToBrowseScreen ? 1 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaProvider>().loadMedia();
    });
  }

  void _showExitConfirmationDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Exit Confirmation',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final theme = Theme.of(context);
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: PopScope(
              canPop: false,
              onPopInvoked: (didPop) {
                if (didPop) return;
                SystemNavigator.pop();
              },
              child: AlertDialog(
                backgroundColor: theme.colorScheme.surface,
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Broken.logout,
                        color: theme.colorScheme.error,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exit Application',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: const Text(
                  'Are you sure you want to exit? Press back again or tap Exit to close the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4),
                ),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
                actions: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text('Exit', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileManagerProvider>();
    final canPopHomeScreen = _currentIndex == 1 && !provider.isSelectionMode && provider.canGoBack;

    return PopScope(
      canPop: canPopHomeScreen,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex == 1) {
          if (!provider.canGoBack) {
            setState(() => _currentIndex = 0);
          }
        } else {
          _showExitConfirmationDialog(context);
        }
      },
      child: Scaffold(
        drawer: NFileDrawer(
          toggleTheme: widget.toggleTheme,
          onNavigateTab: (index) => setState(() => _currentIndex = index),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(),
            DirectoryScreen(
              toggleTheme: widget.toggleTheme,
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            ),
          ],
        ),
        bottomNavigationBar: provider.showHomeBrowseNav
            ? NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  if (index == 1) {
                    final now = DateTime.now();
                    if (_currentIndex == 1 && _lastBrowseTapTime != null && now.difference(_lastBrowseTapTime!) < const Duration(milliseconds: 800)) {
                      provider.loadDirectory(provider.rootPath);
                    }
                    _lastBrowseTapTime = now;
                  }
                  setState(() => _currentIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Broken.home),
                    selectedIcon: Icon(Broken.home_1),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Broken.folder),
                    selectedIcon: Icon(Broken.folder_open),
                    label: 'Browse',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildHomeTab() {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Files',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.toggleTheme,
                    icon: Icon(
                      theme.brightness == Brightness.dark ? Broken.sun_1 : Broken.moon,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            PremiumStorageOverview(
              onBrowseStorage: () {
                final provider = context.read<FileManagerProvider>();
                provider.loadDirectory(provider.rootPath);
                setState(() => _currentIndex = 1);
              },
            ),
            const SizedBox(height: 8),
            QuickCategoriesGrid(
              onNavigateTab: (index) => setState(() => _currentIndex = index),
            ),
            const SizedBox(height: 8),
            if (context.select<FileManagerProvider, bool>((p) => p.showRecentFiles))
              const RecentFilesSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
