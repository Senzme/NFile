import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:on_audio_query/on_audio_query.dart';

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
  double sliderValue = 0;

  late int _currentIndex;
  List<SongModel> get _allSongs => widget.allSongs ?? [];
  SongModel? get _currentSong =>
      _allSongs.isEmpty ? null : _allSongs[_currentIndex];

  String get _currentTitle =>
      _currentSong?.title ?? widget.title;
  String get _currentArtist =>
      _currentSong?.artist ?? widget.artist;
  int get _currentId => _currentSong?.id ?? 0;
  String get _currentPath =>
      _currentSong?.data ?? widget.audioPath;

  // Animations
  late AnimationController _discController;
  late AnimationController _waveController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Repeat / Shuffle
  bool _shuffle = false;
  int _repeatMode = 0; // 0=none, 1=one, 2=all

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    player = Player();
    _initListeners();
    _openTrack();
  }

  void _initListeners() {
    player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => isPlaying = playing);
      if (playing) {
        _discController.repeat();
      } else {
        _discController.stop();
      }
    });
    player.stream.position.listen((p) {
      if (!mounted || isSeeking) return;
      setState(() {
        position = p;
        sliderValue = p.inMilliseconds.toDouble();
      });
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
    _resetFade();
  }

  void _resetFade() {
    _fadeController.forward(from: 0);
  }

  void _playNext() {
    if (_allSongs.isEmpty) return;
    if (_shuffle) {
      int next;
      do {
        next = Random().nextInt(_allSongs.length);
      } while (next == _currentIndex && _allSongs.length > 1);
      _currentIndex = next;
    } else {
      _currentIndex = (_currentIndex + 1) % _allSongs.length;
    }
    setState(() {
      position = Duration.zero;
      duration = Duration.zero;
      sliderValue = 0;
    });
    _openTrack();
  }

  void _playPrevious() {
    if (_allSongs.isEmpty) return;
    if (position.inSeconds > 3) {
      player.seek(Duration.zero);
      return;
    }
    _currentIndex =
        (_currentIndex - 1 + _allSongs.length) % _allSongs.length;
    setState(() {
      position = Duration.zero;
      duration = Duration.zero;
      sliderValue = 0;
    });
    _openTrack();
  }

  @override
  void dispose() {
    _discController.dispose();
    _waveController.dispose();
    _fadeController.dispose();
    player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background blurred artwork glow
          _buildBackground(theme, isDark, accent),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, theme),
                const SizedBox(height: 16),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        // Rotating vinyl disc artwork
                        _buildArtwork(accent),
                        const SizedBox(height: 32),
                        // Track info
                        _buildTrackInfo(theme),
                        const SizedBox(height: 24),
                        // Wave visualizer
                        _buildWaveVisualizer(accent),
                        const SizedBox(height: 20),
                        // Seek bar
                        _buildSeekBar(theme, accent),
                        const SizedBox(height: 8),
                        // Controls
                        _buildControls(theme, accent),
                        const SizedBox(height: 20),
                        // Extra buttons
                        _buildExtraButtons(theme, accent),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ThemeData theme, bool isDark, Color accent) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  accent.withOpacity(0.15),
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor,
                ]
              : [
                  accent.withOpacity(0.08),
                  theme.scaffoldBackgroundColor,
                  theme.scaffoldBackgroundColor,
                ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 30),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor:
                  theme.colorScheme.onSurface.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Expanded(
            child: Text(
              'Now Playing',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 22),
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor:
                  theme.colorScheme.onSurface.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtwork(Color accent) {
    return RotationTransition(
      turns: _discController,
      child: Container(
        width: 230,
        height: 230,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.4),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Vinyl outer ring
            Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black87,
                gradient: SweepGradient(
                  colors: [
                    Colors.grey.shade900,
                    Colors.grey.shade800,
                    Colors.grey.shade900,
                    Colors.grey.shade700,
                    Colors.grey.shade900,
                  ],
                ),
              ),
            ),
            // Vinyl grooves
            for (double r = 90; r <= 108; r += 6)
              Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                    width: 1,
                  ),
                ),
              ),
            // Center artwork
            ClipOval(
              child: Container(
                width: 130,
                height: 130,
                color: accent.withOpacity(0.2),
                child: _allSongs.isNotEmpty && _currentId != 0
                    ? QueryArtworkWidget(
                        id: _currentId,
                        type: ArtworkType.AUDIO,
                        artworkBorder: BorderRadius.zero,
                        artworkFit: BoxFit.cover,
                        artworkWidth: 130,
                        artworkHeight: 130,
                        nullArtworkWidget: _defaultArtworkIcon(accent),
                      )
                    : _defaultArtworkIcon(accent),
              ),
            ),
            // Center hole
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultArtworkIcon(Color accent) {
    return Center(
      child: Icon(Icons.music_note, size: 48, color: accent),
    );
  }

  Widget _buildTrackInfo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            _currentTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'LexendDeca',
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentArtist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveVisualizer(Color accent) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(28, (i) {
              final phase = (i / 28) * 2 * pi;
              final raw = sin(_waveController.value * 2 * pi + phase);
              final h = isPlaying
                  ? (raw.abs() * 28 + 4).clamp(4.0, 32.0)
                  : 4.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: isPlaying
                      ? accent.withOpacity(0.6 + raw.abs() * 0.4)
                      : accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSeekBar(ThemeData theme, Color accent) {
    final maxMs = duration.inMilliseconds.toDouble();
    final safeMax = maxMs > 0 ? maxMs : 1.0;
    final safeVal = sliderValue.clamp(0.0, safeMax);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: accent,
              inactiveTrackColor: accent.withOpacity(0.2),
              thumbColor: accent,
              overlayColor: accent.withOpacity(0.15),
            ),
            child: Slider(
              value: safeVal,
              max: safeMax,
              onChangeStart: (_) => isSeeking = true,
              onChanged: (v) => setState(() => sliderValue = v),
              onChangeEnd: (v) {
                isSeeking = false;
                player.seek(Duration(milliseconds: v.toInt()));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(position),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )),
                Text(_fmt(duration),
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme, Color accent) {
    final hasMultiple = _allSongs.length > 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          size: 36,
          onTap: hasMultiple ? _playPrevious : null,
          color: theme.colorScheme.onSurface,
        ),
        // Rewind 10s
        _ControlButton(
          icon: Icons.replay_10_rounded,
          size: 28,
          onTap: () =>
              player.seek(position - const Duration(seconds: 10)),
          color: theme.colorScheme.onSurface,
        ),
        // Play / Pause (big)
        GestureDetector(
          onTap: () => player.playOrPause(),
          child: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  accent.withOpacity(0.75),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        // Forward 10s
        _ControlButton(
          icon: Icons.forward_10_rounded,
          size: 28,
          onTap: () =>
              player.seek(position + const Duration(seconds: 10)),
          color: theme.colorScheme.onSurface,
        ),
        // Next
        _ControlButton(
          icon: Icons.skip_next_rounded,
          size: 36,
          onTap: hasMultiple ? _playNext : null,
          color: theme.colorScheme.onSurface,
        ),
      ],
    );
  }

  Widget _buildExtraButtons(ThemeData theme, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Shuffle
          IconButton(
            icon: Icon(
              Icons.shuffle_rounded,
              color: _shuffle
                  ? accent
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onPressed: () => setState(() => _shuffle = !_shuffle),
          ),
          // Track count badge
          if (_allSongs.isNotEmpty)
            Text(
              '${_currentIndex + 1} / ${_allSongs.length}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          // Repeat
          IconButton(
            icon: Icon(
              _repeatMode == 0
                  ? Icons.repeat_rounded
                  : _repeatMode == 1
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
              color: _repeatMode != 0
                  ? accent
                  : theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            onPressed: () =>
                setState(() => _repeatMode = (_repeatMode + 1) % 3),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      color: onTap != null ? color : color.withOpacity(0.3),
      onPressed: onTap,
    );
  }
}
