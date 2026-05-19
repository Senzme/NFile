import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/media_provider.dart';
import '../../providers/file_manager_provider.dart';
import '../screens/media_category_screen.dart';
import '../screens/internal_file_picker_screen.dart';

class QuickCategoriesGrid extends StatelessWidget {
  final Function(int) onNavigateTab;

  const QuickCategoriesGrid({super.key, required this.onNavigateTab});

  static Map<String, Map<String, dynamic>> getAllCategoriesMap(BuildContext context, bool isDark, Function(int) onNavigateTab) {
    final mediaProvider = Provider.of<MediaProvider>(context, listen: false);
    final map = <String, Map<String, dynamic>>{
      'Images': {
        'label': 'Images',
        'icon': Broken.image,
        'color': isDark ? Colors.purpleAccent : Colors.purple,
        'count': '${mediaProvider.getCategoryItemCount("Images")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.images))),
      },
      'Videos': {
        'label': 'Videos',
        'icon': Broken.video,
        'color': isDark ? Colors.redAccent : const Color(0xFFD32F2F),
        'count': '${mediaProvider.getCategoryItemCount("Videos")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.videos))),
      },
      'Audio': {
        'label': 'Audio',
        'icon': Broken.music,
        'color': isDark ? Colors.orangeAccent : const Color(0xFFE65100),
        'count': '${mediaProvider.getCategoryItemCount("Audio")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.audios))),
      },
      'Documents': {
        'label': 'Documents',
        'icon': Broken.document,
        'color': isDark ? Colors.blueAccent : const Color(0xFF1976D2),
        'count': '${mediaProvider.getCategoryItemCount("Documents")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.documents))),
      },
      'Archives': {
        'label': 'Archives',
        'icon': Broken.archive,
        'color': isDark ? Colors.tealAccent : const Color(0xFF00796B),
        'count': '${mediaProvider.getCategoryItemCount("Archives")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.archives))),
      },
      'Downloads': {
        'label': 'Downloads',
        'icon': Broken.document_download,
        'color': isDark ? Colors.greenAccent : const Color(0xFF2E7D32),
        'count': '${mediaProvider.getCategoryItemCount("Downloads")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.downloads))),
      },
      'APKs': {
        'label': 'APKs',
        'icon': Broken.box,
        'color': isDark ? Colors.amber : const Color(0xFFF57C00),
        'count': '${mediaProvider.getCategoryItemCount("APKs")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.apks))),
      },
      'Screenshots': {
        'label': 'Screenshots',
        'icon': Broken.mobile,
        'color': isDark ? Colors.pinkAccent : const Color(0xFFC2185B),
        'count': '${mediaProvider.getCategoryItemCount("Screenshots")}',
        'isCustom': false,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.screenshots))),
      },
    };

    for (final cs in mediaProvider.customShortcuts) {
      map[cs.id] = {
        'label': cs.label,
        'icon': cs.isDirectory ? Broken.folder : Broken.document,
        'color': isDark ? Colors.cyanAccent : Colors.cyan,
        'count': cs.isDirectory ? 'Folder' : 'File',
        'isCustom': true,
        'path': cs.path,
        'action': () {
          if (cs.isDirectory) {
            final fileManager = context.read<FileManagerProvider>();
            fileManager.loadDirectory(cs.path);
            onNavigateTab(1);
          } else {
            final fileManager = context.read<FileManagerProvider>();
            fileManager.openFile(context, cs.path);
          }
        },
      };
    }

    return map;
  }

  static void showCustomizeDialog(BuildContext context, [Function(int)? onNavigateTab]) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return _CustomizeCategoriesSheet(onNavigateTab: onNavigateTab ?? (index) {
          Navigator.popUntil(context, (route) => route.isFirst);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaProvider = context.watch<MediaProvider>();

    final allCategoriesMap = getAllCategoriesMap(context, isDark, onNavigateTab);

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
                onTap: () => showCustomizeDialog(context, onNavigateTab),
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
}

class _CustomizeCategoriesSheet extends StatelessWidget {
  final Function(int) onNavigateTab;

  const _CustomizeCategoriesSheet({required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<MediaProvider>(
          builder: (context, provider, child) {
            final activeCats = provider.activeCategories;
            final order = provider.categoryOrder;
            final categoriesMap = QuickCategoriesGrid.getAllCategoriesMap(context, isDark, onNavigateTab);

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
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Drag items by the handle (=) to reorder icons on the Home Screen.',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: OutlinedButton.icon(
                    icon: const Icon(Broken.add, size: 20),
                    label: const Text('Add Folder / File Shortcut', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      foregroundColor: theme.colorScheme.primary,
                      side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final fileManager = context.read<FileManagerProvider>();
                      final paths = await InternalFilePickerScreen.show(context, rootPath: fileManager.rootPath);
                      if (paths != null && paths.isNotEmpty) {
                        for (final p in paths) {
                          provider.addCustomShortcut(p);
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
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
                      final isCustom = cat['isCustom'] == true;

                      return ListTile(
                        key: ValueKey(label),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        title: Text(cat['label'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        subtitle: isCustom ? Text(cat['path'] as String, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)), maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCustom) ...[
                              IconButton(
                                icon: const Icon(Broken.trash, color: Colors.redAccent, size: 20),
                                tooltip: 'Delete Shortcut',
                                onPressed: () => provider.removeCustomShortcut(label),
                              ),
                              const SizedBox(width: 4),
                            ],
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
