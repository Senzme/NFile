import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/media_provider.dart';
import '../screens/media_category_screen.dart';

class QuickCategoriesGrid extends StatelessWidget {
  final Function(int) onNavigateTab;

  const QuickCategoriesGrid({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaProvider = context.watch<MediaProvider>();

    final allCategories = [
      {
        'label': 'Images',
        'icon': Broken.image,
        'color': Colors.purpleAccent,
        'count': '${mediaProvider.images.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.images))),
      },
      {
        'label': 'Videos',
        'icon': Broken.video,
        'color': Colors.redAccent,
        'count': '${mediaProvider.videos.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.videos))),
      },
      {
        'label': 'Audio',
        'icon': Broken.music,
        'color': Colors.orangeAccent,
        'count': '${mediaProvider.audios.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.audios))),
      },
      {
        'label': 'Documents',
        'icon': Broken.document,
        'color': Colors.blueAccent,
        'count': '${mediaProvider.documents.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.documents))),
      },
      {
        'label': 'Archives',
        'icon': Broken.archive,
        'color': Colors.tealAccent,
        'count': '${mediaProvider.archives.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.archives))),
      },
      {
        'label': 'Downloads',
        'icon': Broken.document_download,
        'color': Colors.greenAccent,
        'count': '${mediaProvider.downloads.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.downloads))),
      },
      {
        'label': 'APKs',
        'icon': Broken.box,
        'color': Colors.amber,
        'count': '${mediaProvider.apks.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.apks))),
      },
      {
        'label': 'Screenshots',
        'icon': Broken.mobile,
        'color': Colors.pinkAccent,
        'count': '${mediaProvider.screenshots.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.screenshots))),
      },
    ];

    final activeList = allCategories
        .where((c) => mediaProvider.activeCategories.contains(c['label'] as String))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Categories',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              InkWell(
                onTap: () => _showCustomizeDialog(context, mediaProvider, allCategories, theme),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Broken.setting_2, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Customize',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (activeList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No shortcuts pinned. Tap Customize to add.',
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 20,
                childAspectRatio: 0.82,
              ),
              itemCount: activeList.length,
              itemBuilder: (context, index) {
                final cat = activeList[index];
                final label = cat['label'] as String;
                final icon = cat['icon'] as IconData;
                final color = cat['color'] as Color;
                final count = cat['count'] as String;
                final action = cat['action'] as VoidCallback;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: color.withOpacity(0.15),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: action,
                        customBorder: const CircleBorder(),
                        splashColor: color.withOpacity(0.25),
                        highlightColor: color.withOpacity(0.15),
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          child: Icon(icon, color: color, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      count,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _showCustomizeDialog(
      BuildContext context, MediaProvider provider, List<Map<String, dynamic>> allCategories, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) {
        return ChangeNotifierProvider<MediaProvider>.value(
          value: provider,
          child: _CustomizeCategoriesSheet(allCategories: allCategories),
        );
      },
    );
  }
}

class _CustomizeCategoriesSheet extends StatelessWidget {
  final List<Map<String, dynamic>> allCategories;

  const _CustomizeCategoriesSheet({required this.allCategories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Customize Shortcuts', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: Consumer<MediaProvider>(
                builder: (context, mediaProv, child) {
                  final activeCats = mediaProv.activeCategories;
                  return ListView.builder(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: allCategories.length,
                    itemBuilder: (context, index) {
                      final cat = allCategories[index];
                      final label = cat['label'] as String;
                      final icon = cat['icon'] as IconData;
                      final color = cat['color'] as Color;
                      final isEnabled = activeCats.contains(label);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEnabled ? color.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isEnabled ? color.withOpacity(0.18) : Colors.grey.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: isEnabled ? color : Colors.grey, size: 22),
                          ),
                          title: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isEnabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                            child: Text(label),
                          ),
                          trailing: Switch(
                            value: isEnabled,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (val) {
                              mediaProv.toggleCategory(label);
                            },
                          ),
                          onTap: () {
                            mediaProv.toggleCategory(label);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
