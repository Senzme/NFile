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

    final allCategoriesMap = <String, Map<String, dynamic>>{
      'Images': {
        'label': 'Images',
        'icon': Broken.image,
        'color': Colors.purpleAccent,
        'count': '${mediaProvider.images.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.images))),
      },
      'Videos': {
        'label': 'Videos',
        'icon': Broken.video,
        'color': Colors.redAccent,
        'count': '${mediaProvider.videos.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.videos))),
      },
      'Audio': {
        'label': 'Audio',
        'icon': Broken.music,
        'color': Colors.orangeAccent,
        'count': '${mediaProvider.audios.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.audios))),
      },
      'Documents': {
        'label': 'Documents',
        'icon': Broken.document,
        'color': Colors.blueAccent,
        'count': '${mediaProvider.documents.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.documents))),
      },
      'Archives': {
        'label': 'Archives',
        'icon': Broken.archive,
        'color': Colors.tealAccent,
        'count': '${mediaProvider.archives.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.archives))),
      },
      'Downloads': {
        'label': 'Downloads',
        'icon': Broken.document_download,
        'color': Colors.greenAccent,
        'count': '${mediaProvider.downloads.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.downloads))),
      },
      'APKs': {
        'label': 'APKs',
        'icon': Broken.box,
        'color': Colors.amber,
        'count': '${mediaProvider.apks.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.apks))),
      },
      'Screenshots': {
        'label': 'Screenshots',
        'icon': Broken.mobile,
        'color': Colors.pinkAccent,
        'count': '${mediaProvider.screenshots.length}',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.screenshots))),
      },
    };

    final activeList = mediaProvider.categoryOrder
        .where((label) => mediaProvider.activeCategories.contains(label) && allCategoriesMap.containsKey(label))
        .map((label) => allCategoriesMap[label]!)
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
                onTap: () => _showCustomizeDialog(context, allCategoriesMap, theme),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: GridView.builder(
                key: ValueKey(activeList.length),
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
                    key: ValueKey(label),
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
            ),
        ],
      ),
    );
  }

  void _showCustomizeDialog(BuildContext context, Map<String, Map<String, dynamic>> categoriesMap, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return _CustomizeCategoriesSheet(categoriesMap: categoriesMap);
      },
    );
  }
}

class _CustomizeCategoriesSheet extends StatelessWidget {
  final Map<String, Map<String, dynamic>> categoriesMap;

  const _CustomizeCategoriesSheet({required this.categoriesMap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<MediaProvider>(
          builder: (context, provider, child) {
            final activeCats = provider.activeCategories;
            final order = provider.categoryOrder;

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
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Drag items by the handle (=) to reorder icons on the Home Screen.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5), fontSize: 12),
                    ),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollController: scrollController,
                    physics: const BouncingScrollPhysics(),
                    onReorder: (oldIndex, newIndex) => provider.reorderCategory(oldIndex, newIndex),
                    itemCount: order.length,
                    itemBuilder: (context, index) {
                      final label = order[index];
                      final cat = categoriesMap[label];
                      if (cat == null) return const SizedBox.shrink(key: ValueKey('empty'));

                      final icon = cat['icon'] as IconData;
                      final color = cat['color'] as Color;
                      final isEnabled = activeCats.contains(label);

                      return ListTile(
                        key: ValueKey(label),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: isEnabled,
                              activeColor: theme.colorScheme.primary,
                              onChanged: (val) => provider.toggleCategory(label),
                            ),
                            const SizedBox(width: 12),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle, color: Colors.grey, size: 24),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
