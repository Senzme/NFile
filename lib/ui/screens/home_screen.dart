import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/premium_storage_overview.dart';
import '../widgets/quick_categories_grid.dart';
import '../widgets/recent_files_section.dart';
import 'directory_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const HomeScreen({super.key, required this.toggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaProvider>().loadMedia();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          const DirectoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
                    icon: Icon(theme.brightness == Brightness.dark ? Broken.sun_1 : Broken.moon),
                    onPressed: widget.toggleTheme,
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
            const RecentFilesSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
