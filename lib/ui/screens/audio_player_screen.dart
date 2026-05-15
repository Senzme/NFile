import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String audioPath;
  final String title;

  const AudioPlayerScreen({super.key, required this.audioPath, required this.title});

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late final Player player;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    player = Player();
    player.stream.playing.listen((playing) {
      if (mounted) setState(() => isPlaying = playing);
    });
    player.stream.position.listen((p) {
      if (mounted) setState(() => position = p);
    });
    player.stream.duration.listen((d) {
      if (mounted) setState(() => duration = d);
    });
    player.open(Media(widget.audioPath), play: true);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.music_note, size: 80, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 40),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 40),
            Slider(
              value: position.inSeconds.toDouble().clamp(0, duration.inSeconds.toDouble()),
              max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1,
              onChanged: (val) {
                player.seek(Duration(seconds: val.toInt()));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position)),
                  Text(_formatDuration(duration)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, size: 40),
                  onPressed: () {
                    player.seek(position - const Duration(seconds: 10));
                  },
                ),
                FloatingActionButton(
                  onPressed: () {
                    player.playOrPause();
                  },
                  child: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10, size: 40),
                  onPressed: () {
                    player.seek(position + const Duration(seconds: 10));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
