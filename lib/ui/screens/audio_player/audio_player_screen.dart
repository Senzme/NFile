import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/icon_fonts/broken_icons.dart';
import '../../../services/audio_background_handler.dart';
import 'audio_artwork_widget.dart';
import 'audio_waveform_widget.dart';
import 'audio_controls_widget.dart';
import 'audio_queue_sheet.dart';
import 'audio_particles_widget.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String audioPath;
  final String title;
  final String artist;
  final List<SongModel>? allSongs;
  final int initialIndex;

  const AudioPlayerScreen({
    super.key,
    required this.audioPath,
    required this.title,
    this.artist = 'Unknown Artist',
    this.allSongs,
    this.initialIndex = 0,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with TickerProviderStateMixin {
  late final Player player;

  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isSeeking = false;

  late int _currentIndex;
  List<SongModel> get _allSongs => widget.allSongs ?? [];
  SongModel? get _currentSong =>
      _allSongs.isEmpty ? null : _allSongs[_currentIndex];

  String get _currentTitle => _currentSong?.title ?? widget.title;
  String get _currentArtist => _currentSong?.artist ?? widget.artist;
  int get _currentId => _currentSong?.id ?? 0;
  String get _currentPath => _currentSong?.data ?? widget.audioPath;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Modes & Audio FX
  bool _isFavorite = false;
  int _repeatMode = 0; // 0=none, 1=one, 2=all
  double _playbackSpeed = 1.0;
  double _pitch = 1.0;

  // Shuffle
  bool _isShuffled = false;
  late List<int> _shuffleQueue; // shuffled indices of _allSongs
  int _shufflePos = 0; // current position in _shuffleQueue

  // Background playback
  bool _isBackgroundMode = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // MUST enable pitch in PlayerConfiguration for runtime pitch control
    player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 16 * 1024 * 1024,
        pitch: true,
      ),
    );
    _shuffleQueue = List.generate(_allSongs.length, (i) => i);
    _initListeners();
    _openTrack();
  }

  void _initListeners() {
    player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => isPlaying = playing);
    });
    player.stream.position.listen((p) {
      if (!mounted || isSeeking) return;
      setState(() => position = p);
    });
    player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() => duration = d);
    });
    player.stream.completed.listen((completed) {
      if (!completed || !mounted) return;
      _onTrackComplete();
    });
  }

  void _onTrackComplete() {
    if (_repeatMode == 1) {
      player.seek(Duration.zero);
      player.play();
    } else if (_repeatMode == 2 || _allSongs.isNotEmpty) {
      _playNext();
    }
  }

  void _openTrack() {
    player.open(Media(_currentPath), play: true);
    player.setRate(_playbackSpeed);
    player.setPitch(_pitch);
    _resetFade();
  }

  void _resetFade() {
    _fadeController.forward(from: 0);
  }

  void _selectTrack(int index) {
    if (index == _currentIndex) return;
    _currentIndex = index;
    setState(() {
      position = Duration.zero;
      duration = Duration.zero;
    });
    _openTrack();
  }

  void _playNext() {
    if (_allSongs.isEmpty) return;
    if (_isShuffled) {
      _shufflePos = (_shufflePos + 1) % _shuffleQueue.length;
      _currentIndex = _shuffleQueue[_shufflePos];
    } else {
      _currentIndex = (_currentIndex + 1) % _allSongs.length;
    }
    setState(() {
      position = Duration.zero;
      duration = Duration.zero;
    });
    _openTrack();
    if (_isBackgroundMode) _updateBackgroundItem();
  }

  void _playPrevious() {
    if (_allSongs.isEmpty) return;
    if (position.inSeconds > 3) {
      player.seek(Duration.zero);
      return;
    }
    if (_isShuffled) {
      _shufflePos = (_shufflePos - 1 + _shuffleQueue.length) % _shuffleQueue.length;
      _currentIndex = _shuffleQueue[_shufflePos];
    } else {
      _currentIndex = (_currentIndex - 1 + _allSongs.length) % _allSongs.length;
    }
    setState(() {
      position = Duration.zero;
      duration = Duration.zero;
    });
    _openTrack();
    if (_isBackgroundMode) _updateBackgroundItem();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    if (_isBackgroundMode) {
      // Let audio keep playing in background — don't dispose player
    } else {
      player.dispose();
    }
    super.dispose();
  }

  // ─── Shuffle helpers ────────────────────────────────────────────────────

  void _buildShuffleQueue() {
    _shuffleQueue = List.generate(_allSongs.length, (i) => i);
    _shuffleQueue.shuffle();
    // Move current song to front so it plays now, rest is shuffled
    _shuffleQueue.remove(_currentIndex);
    _shuffleQueue.insert(0, _currentIndex);
    _shufflePos = 0;
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffled = !_isShuffled;
      if (_isShuffled) {
        _buildShuffleQueue();
      }
    });
  }

  void _showQueueSheet(Color accentColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => AudioQueueSheet(
          songs: _allSongs,
          currentIndex: _currentIndex,
          onSelectSong: _selectTrack,
          accentColor: accentColor,
        ),
      ),
    );
  }

  void _showLyricsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Broken.document, color: Colors.deepPurpleAccent),
            const SizedBox(width: 10),
            Text('Synchronized Lyrics', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "♪ Instrumental / Synchronized Audio ♪\n\n(Enjoying pristine lossless sound playback)",
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showSleepTimerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Broken.timer, color: Colors.deepPurpleAccent),
            const SizedBox(width: 10),
            Text('Sleep Timer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [15, 30, 45, 60].map((mins) => ListTile(
            title: Text('$mins Minutes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Sleep timer set for $mins minutes.', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                backgroundColor: Colors.deepPurpleAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showEqualizerDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.deepPurpleAccent),
                const SizedBox(width: 10),
                Text('Sound & Speed FX', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Playback Speed', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    Text('${_playbackSpeed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Slider(
                  value: _playbackSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: (v) {
                    setModalState(() => _playbackSpeed = v);
                    setState(() {});
                    player.setRate(v);
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pitch Adjustment', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    Text('${_pitch.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: (v) {
                    setModalState(() => _pitch = v);
                    setState(() {});
                    player.setPitch(v);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.white70, size: 18),
                  label: const Text('Reset to Default', style: TextStyle(color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    setModalState(() {
                      _playbackSpeed = 1.0;
                      _pitch = 1.0;
                    });
                    setState(() {});
                    player.setRate(1.0);
                    player.setPitch(1.0);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done', style: TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Background mode ─────────────────────────────────────────────────────

  /// Build MediaItem for the current song for the notification.
  MediaItem _buildMediaItem(int index) {
    final song = _allSongs.isNotEmpty ? _allSongs[index] : null;
    return MediaItem(
      id: song?.data ?? widget.audioPath,
      title: song?.title ?? widget.title,
      artist: song?.artist ?? widget.artist,
      album: song?.album ?? '',
    );
  }

  void _updateBackgroundItem() {
    getAudioHandler().updateCurrentItem(_buildMediaItem(_currentIndex));
  }

  Future<void> _toggleBackgroundMode() async {
    if (_isBackgroundMode) {
      // Turn off — detach handler, user is in foreground
      getAudioHandler().detach();
      setState(() => _isBackgroundMode = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Background playback stopped'),
            backgroundColor: Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Attach the handler with the current player and queue
    final queue = _allSongs.isNotEmpty
        ? List.generate(_allSongs.length, (i) => _buildMediaItem(i))
        : [_buildMediaItem(0)];

    final handler = getAudioHandler();
    handler.attach(
      player: player,
      queue: queue,
      currentIndex: _currentIndex,
    );
    // Skip callback so notification controls update the screen's index
    handler.setSkipCallback((int idx) {
      if (!mounted) return;
      setState(() {
        _currentIndex = idx;
        position = Duration.zero;
        duration = Duration.zero;
      });
      _openTrack();
      _updateBackgroundItem();
    });

    setState(() => _isBackgroundMode = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Playing in background — check notification'),
          backgroundColor: Colors.deepPurpleAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Shuffle toggle ────────────────────────────────────────────────
              ListTile(
                leading: Icon(
                  Icons.shuffle_rounded,
                  color: _isShuffled ? Colors.deepPurpleAccent : Colors.white,
                ),
                title: Text(
                  _isShuffled ? 'Shuffle: On' : 'Shuffle: Off',
                  style: TextStyle(
                    color: _isShuffled ? Colors.deepPurpleAccent : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Switch(
                  value: _isShuffled,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: (_) {
                    _toggleShuffle();
                    setSheet(() {});
                  },
                ),
                onTap: () {
                  _toggleShuffle();
                  setSheet(() {});
                },
              ),
              // ── Play in Background ────────────────────────────────────────────
              ListTile(
                leading: Icon(
                  Icons.headphones_rounded,
                  color: _isBackgroundMode ? Colors.greenAccent : Colors.white,
                ),
                title: Text(
                  _isBackgroundMode ? 'Background: On' : 'Play in Background',
                  style: TextStyle(
                    color: _isBackgroundMode ? Colors.greenAccent : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isBackgroundMode
                      ? 'Tap to stop background playback'
                      : 'Shows notification with controls',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleBackgroundMode();
                },
              ),
              const Divider(color: Colors.white12, height: 1),
              ListTile(
                leading: Icon(Broken.document, color: Colors.white),
                title: const Text('View Synchronized Lyrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLyricsDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded, color: Colors.white),
                title: const Text('Sound FX & Equalizer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEqualizerDialog();
                },
              ),
              ListTile(
                leading: Icon(Broken.timer, color: Colors.white),
                title: const Text('Set Sleep Timer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSleepTimerDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: Colors.white),
                title: const Text('Audio File Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(_currentPath, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Soft Glow
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [
                        accent.withOpacity(0.2),
                        theme.scaffoldBackgroundColor,
                        theme.scaffoldBackgroundColor,
                      ]
                    : [
                        accent.withOpacity(0.12),
                        theme.scaffoldBackgroundColor,
                        theme.scaffoldBackgroundColor,
                      ],
              ),
            ),
          ),
          // Floating Particles
          AudioParticlesWidget(isPlaying: isPlaying, accentColor: accent),
          // Main Layout Matching Screenshot 2
          SafeArea(
            child: Column(
              children: [
                // Premium Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Broken.arrow_down_2, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _allSongs.isNotEmpty
                                  ? '${_currentIndex + 1} / ${_allSongs.length}'
                                  : '1 / 1',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: accent,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentSong?.album ?? 'Single Track',
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: theme.colorScheme.onSurface.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.onSurface.withOpacity(0.08),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.more_horiz_rounded, size: 22),
                          onPressed: _showMoreMenu,
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Animated Body
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Large Premium Rounded Rectangular Artwork matching Screenshot 2
                        AudioArtworkWidget(
                          audioId: _currentId,
                          audioPath: _currentPath,
                          accentColor: accent,
                          isPlaying: isPlaying,
                          onDoubleTap: _showLyricsDialog,
                          onLongPress: _showEqualizerDialog,
                        ),
                        // Title row with Favorite Heart icon on right matching Screenshot 2
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _currentArtist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  color: _isFavorite ? Colors.redAccent : theme.colorScheme.onSurface.withOpacity(0.6),
                                  size: 28,
                                ),
                                onPressed: () => setState(() => _isFavorite = !_isFavorite),
                              ),
                            ],
                          ),
                        ),
                        // Interactive Glowing Waveform Seek Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AudioWaveformWidget(
                            position: position,
                            duration: duration,
                            isPlaying: isPlaying,
                            accentColor: accent,
                            onSeekStart: () => isSeeking = true,
                            onSeek: (d) {
                              isSeeking = false;
                              player.seek(d);
                            },
                          ),
                        ),
                        // Compact Playback Controls & Bottom Utilities
                        AudioControlsWidget(
                          isPlaying: isPlaying,
                          position: position,
                          duration: duration,
                          onPlayPause: () => player.playOrPause(),
                          onPrevious: _allSongs.length > 1 ? _playPrevious : null,
                          onNext: _allSongs.length > 1 ? _playNext : null,
                          onShowLyrics: _showLyricsDialog,
                          onShowSleepTimer: _showSleepTimerDialog,
                          onShowEqualizer: _showEqualizerDialog,
                          onShowQueue: () => _showQueueSheet(accent),
                          repeatMode: _repeatMode,
                          onToggleRepeat: () => setState(() => _repeatMode = (_repeatMode + 1) % 3),
                          accentColor: accent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
