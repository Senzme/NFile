import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/icon_fonts/broken_icons.dart';
import '../../providers/file_manager_provider.dart';
import '../../providers/media_provider.dart';
import '../screens/media_category_screen.dart';

class QuickCategoriesGrid extends StatelessWidget {
  final Function(int) onNavigateTab;

  const QuickCategoriesGrid({super.key, required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaProvider = context.watch<MediaProvider>();

    final categories = [
      {
        'label': 'Images',
        'icon': Broken.image,
        'color': Colors.purpleAccent,
        'count': '${mediaProvider.images.length} items',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.images))),
      },
      {
        'label': 'Videos',
        'icon': Broken.video,
        'color': Colors.redAccent,
        'count': '${mediaProvider.videos.length} items',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.videos))),
      },
      {
        'label': 'Audio',
        'icon': Broken.music,
        'color': Colors.orangeAccent,
        'count': '${mediaProvider.audios.length} items',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.audios))),
      },
      {
        'label': 'Documents',
        'icon': Broken.document,
        'color': Colors.blueAccent,
        'count': '${mediaProvider.documents.length} items',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.documents))),
      },
      {
        'label': 'Archives',
        'icon': Broken.archive,
        'color': Colors.tealAccent,
        'count': '${mediaProvider.archives.length} items',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.archives))),
      },
      {
        'label': 'Downloads',
        'icon': Broken.document_download,
        'color': Colors.greenAccent,
        'count': '${mediaProvider.downloads.length} items',
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MediaCategoryScreen(mediaType: MediaType.downloads))),
      },
    ];

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
              Text(
                'All Supported',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final label = cat['label'] as String;
              final icon = cat['icon'] as IconData;
              final color = cat['color'] as Color;
              final count = cat['count'] as String;
              final action = cat['action'] as VoidCallback;

              return Card(
                elevation: 0,
                color: color.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
                ),
                child: InkWell(
                  onTap: action,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                count,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
