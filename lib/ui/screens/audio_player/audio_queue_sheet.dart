import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AudioQueueSheet extends StatelessWidget {
  final List<SongModel> songs;
  final int currentIndex;
  final ValueChanged<int> onSelectSong;
  final Color accentColor;

  const AudioQueueSheet({
    super.key,
    required this.songs,
    required this.currentIndex,
    required this.onSelectSong,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Playing Queue (${songs.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                final isPlaying = index == currentIndex;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isPlaying
                          ? accentColor.withOpacity(0.2)
                          : theme.colorScheme.onSurface.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: QueryArtworkWidget(
                        id: song.id,
                        type: ArtworkType.AUDIO,
                        artworkWidth: 48,
                        artworkHeight: 48,
                        nullArtworkWidget: Icon(
                          isPlaying
                              ? Icons.multitrack_audio_rounded
                              : Icons.music_note_rounded,
                          color: isPlaying ? accentColor : theme.iconTheme.color,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight:
                          isPlaying ? FontWeight.bold : FontWeight.w500,
                      color: isPlaying
                          ? accentColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    song.artist ?? 'Unknown Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                  trailing: isPlaying
                      ? Icon(Icons.equalizer_rounded, color: accentColor)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    onSelectSong(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
