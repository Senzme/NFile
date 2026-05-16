import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../widgets/storage_overview.dart';
import 'directory_screen.dart';
import 'media_category_screen.dart';

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
          const StorageOverviewCard(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Quick Categories',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCategoryItem(context, Broken.image, 'Images', Colors.purpleAccent, ''),
                _buildCategoryItem(context, Broken.video, 'Videos', Colors.redAccent, ''),
                _buildCategoryItem(context, Broken.music, 'Audio', Colors.orangeAccent, ''),
                _buildCategoryItem(context, Broken.document, 'Docs', Colors.blueAccent, ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, IconData icon, String label, Color color, String path) {
    return GestureDetector(
      onTap: () {
        if (label == 'Images') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.images)));
        } else if (label == 'Videos') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.videos)));
        } else if (label == 'Audio') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.audios)));
        } else if (label == 'Docs') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.documents)));
        } else {
          context.read<FileManagerProvider>().loadDirectory(path);
          setState(() => _currentIndex = 1);
        }
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
