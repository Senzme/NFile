import 'package:flutter/material.dart';
import 'package:nfile/core/icon_fonts/broken_icons.dart';

class VideoControlsOverlay extends StatelessWidget {
  final String title;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double sliderValue;
  final double playbackSpeed;
  final bool isFullScreen;
  final bool isLocked;
  final bool isMuted;
  final int repeatMode; // 0=none, 1=one, 2=all
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double> onChangeStart;
  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onFastForward;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToggleFullScreen;
  final ValueChanged<double> onSelectSpeed;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleRepeat;
  final VoidCallback onCopyUrl;
  final VoidCallback onInteract;

  const VideoControlsOverlay({
    super.key,
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.sliderValue,
    required this.playbackSpeed,
    required this.isFullScreen,
    required this.isLocked,
    required this.isMuted,
    required this.repeatMode,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onChangeStart,
    required this.onPlayPause,
    required this.onRewind,
    required this.onFastForward,
    this.onPrevious,
    this.onNext,
    required this.onToggleFullScreen,
    required this.onSelectSpeed,
    required this.onToggleLock,
    required this.onToggleMute,
    required this.onToggleRepeat,
    required this.onCopyUrl,
    required this.onInteract,
  });

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds.toDouble();
    final safeMax = maxMs > 0 ? maxMs : 1.0;
    final safeVal = sliderValue.clamp(0.0, safeMax);
    final itemsColor = Colors.white.withOpacity(0.9);

    if (isLocked) {
      return Positioned(
        top: 32,
        left: 24,
        child: SafeArea(
          child: GestureDetector(
            onTap: onToggleLock,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.deepPurpleAccent.withOpacity(0.4), blurRadius: 16),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Broken.lock, color: Colors.deepPurpleAccent.shade100, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Slide / Tap to Unlock',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Darkened Background Mask for better visibility of controls
        Positioned.fill(
          child: IgnorePointer(
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
        ),

        // TOP ROW HEADER
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Broken.arrow_down_2, color: itemsColor, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(color: itemsColor, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.deepPurpleAccent.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.deepPurpleAccent.shade200, width: 0.8),
                              ),
                              child: const Text(
                                'HW Dec',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AVC / AAC • 1080p',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Speed Selector Dropdown Menu
                  PopupMenuButton<double>(
                    tooltip: 'Playback Speed',
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Broken.play_cricle, color: itemsColor, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${playbackSpeed}x',
                            style: TextStyle(color: itemsColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    color: const Color(0xFF1E1E2E),
                    onSelected: onSelectSpeed,
                    itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
                        .map((v) => PopupMenuItem(
                              value: v,
                              child: Text(
                                '${v}x',
                                style: TextStyle(
                                  color: playbackSpeed == v ? Colors.deepPurpleAccent.shade100 : Colors.white,
                                  fontWeight: playbackSpeed == v ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  // Lock Toggle Button
                  IconButton(
                    icon: Icon(Broken.unlock, color: itemsColor, size: 24),
                    tooltip: 'Lock Controls',
                    onPressed: onToggleLock,
                  ),
                ],
              ),
            ),
          ),
        ),

        // CENTER PLAYBACK CONTROLS
        Center(
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(),
                // Previous Button
                Opacity(
                  opacity: onPrevious != null ? 1.0 : 0.4,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
                    child: IconButton(
                      iconSize: 32,
                      padding: const EdgeInsets.all(14),
                      icon: Icon(Broken.previous, color: itemsColor),
                      onPressed: () {
                        onInteract();
                        onPrevious?.call();
                      },
                    ),
                  ),
                ),
                // Play / Pause Premium Circle
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.deepPurpleAccent.withOpacity(isPlaying ? 0.5 : 0.2), blurRadius: 28, spreadRadius: 4),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                  ),
                  child: IconButton(
                    iconSize: 52,
                    padding: const EdgeInsets.all(20),
                    icon: Icon(isPlaying ? Broken.pause : Broken.play, color: itemsColor),
                    onPressed: () {
                      onInteract();
                      onPlayPause();
                    },
                  ),
                ),
                // Next Button
                Opacity(
                  opacity: onNext != null ? 1.0 : 0.4,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
                    child: IconButton(
                      iconSize: 32,
                      padding: const EdgeInsets.all(14),
                      icon: Icon(Broken.next, color: itemsColor),
                      onPressed: () {
                        onInteract();
                        onNext?.call();
                      },
                    ),
                  ),
                ),
                const SizedBox(),
              ],
            ),
          ),
        ),

        // BOTTOM ROW CONTROLS
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Width Seek Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                        activeTrackColor: Colors.deepPurpleAccent.shade200,
                        inactiveTrackColor: Colors.white.withOpacity(0.25),
                        thumbColor: Colors.deepPurpleAccent.shade200,
                        overlayColor: Colors.deepPurpleAccent.withOpacity(0.3),
                      ),
                      child: Slider(
                        value: safeVal,
                        max: safeMax,
                        onChangeStart: (_) {
                          onInteract();
                          onChangeStart(safeVal);
                        },
                        onChanged: onChanged,
                        onChangeEnd: (_) {
                          onInteract();
                          onChangeEnd(safeVal);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Bottom Bar Utilities & Timers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Current / Total Time Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                        ),
                        child: Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: TextStyle(color: itemsColor, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Action Icons Row
                      Row(
                        children: [
                          // Repeat Button
                          IconButton(
                            icon: Icon(
                              repeatMode == 0
                                  ? Icons.repeat_rounded
                                  : repeatMode == 1
                                      ? Icons.repeat_one_rounded
                                      : Icons.repeat_rounded,
                              color: repeatMode != 0 ? Colors.deepPurpleAccent.shade100 : itemsColor.withOpacity(0.7),
                              size: 22,
                            ),
                            tooltip: 'Repeat Mode',
                            onPressed: () {
                              onInteract();
                              onToggleRepeat();
                            },
                          ),
                          const SizedBox(width: 8),
                          // Mute Button
                          IconButton(
                            icon: Icon(isMuted ? Broken.volume_slash : Broken.volume_high, color: itemsColor, size: 22),
                            tooltip: isMuted ? 'Unmute' : 'Mute',
                            onPressed: () {
                              onInteract();
                              onToggleMute();
                            },
                          ),
                          const SizedBox(width: 8),
                          // Copy Link
                          IconButton(
                            icon: Icon(Icons.copy_rounded, color: itemsColor, size: 22),
                            tooltip: 'Copy URL',
                            onPressed: () {
                              onInteract();
                              onCopyUrl();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Media path copied to clipboard.'),
                                backgroundColor: Colors.deepPurpleAccent,
                              ));
                            },
                          ),
                          const SizedBox(width: 8),
                          // Full Screen
                          IconButton(
                            icon: Icon(isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: itemsColor, size: 28),
                            tooltip: isFullScreen ? 'Exit Full Screen' : 'Full Screen',
                            onPressed: () {
                              onInteract();
                              onToggleFullScreen();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
