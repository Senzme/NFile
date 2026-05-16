import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const VideoPlayerScreen({super.key, required this.videoPath});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  late final Player player;
  late final VideoController controller;

  bool _controlsVisible = true;
  bool _isPlaying = false;
  bool _isSeeking = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _sliderValue = 0;
  bool _isFullScreen = false;
  double _playbackSpeed = 1.0;
  bool _isBuffering = false;

  Timer? _hideTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsOpacity;
  late AnimationController _playPauseController;

  // Double-tap seek
  bool _showSeekLeft = false;
  bool _showSeekRight = false;
  Timer? _seekIndicatorTimer;
  int _seekSeconds = 0;

  @override
  void initState() {
    super.initState();

    // Set full screen immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
    ]);

    _controlsAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controlsOpacity = CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeInOut,
    );
    _controlsAnimController.value = 1.0;

    _playPauseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    player = Player(
      configuration: const PlayerConfiguration(
        ready: null,
        logLevel: MPVLogLevel.warn,
        bufferSize: 32 * 1024 * 1024, // 32MB buffer for fast start
      ),
    );
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto-safe', // Hardware decoding
      ),
    );

    _initListeners();

    // Open with hardware acceleration
    player.open(Media(widget.videoPath));
    _startHideTimer();
  }

  void _initListeners() {
    player.stream.playing.listen((v) {
      if (!mounted) return;
      setState(() => _isPlaying = v);
      if (v) {
        _playPauseController.reverse();
      } else {
        _playPauseController.forward();
      }
    });

    player.stream.position.listen((p) {
      if (!mounted || _isSeeking) return;
      setState(() {
        _position = p;
        _sliderValue = p.inMilliseconds.toDouble();
      });
    });

    player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });

    player.stream.buffering.listen((v) {
      if (!mounted) return;
      setState(() => _isBuffering = v);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        _hideControls();
      }
    });
  }

  void _hideControls() {
    if (!mounted) return;
    _controlsAnimController.reverse();
    setState(() => _controlsVisible = false);
  }

  void _showControls() {
    if (!mounted) return;
    _controlsAnimController.forward();
    setState(() => _controlsVisible = true);
    _startHideTimer();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  void _onDoubleTapLeft() {
    player.seek(_position - const Duration(seconds: 10));
    setState(() {
      _showSeekLeft = true;
      _seekSeconds = 10;
    });
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekLeft = false);
    });
  }

  void _onDoubleTapRight() {
    player.seek(_position + const Duration(seconds: 10));
    setState(() {
      _showSeekRight = true;
      _seekSeconds = 10;
    });
    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekRight = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _controlsAnimController.dispose();
    _playPauseController.dispose();
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _fileName {
    final name = widget.videoPath.split('/').last;
    return name.length > 40 ? '${name.substring(0, 37)}...' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video
            Video(
              controller: controller,
              controls: NoVideoControls,
              fit: BoxFit.contain,
            ),

            // Buffering indicator
            if (_isBuffering)
              const Center(
                child: _NamidaLoader(),
              ),

            // Double-tap zones
            Row(
              children: [
                // Left seek zone
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _onDoubleTapLeft,
                    onTap: _toggleControls,
                    child: const SizedBox.expand(),
                  ),
                ),
                // Right seek zone
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _onDoubleTapRight,
                    onTap: _toggleControls,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),

            // Seek indicator overlays
            if (_showSeekLeft)
              Positioned(
                left: 40,
                top: 0,
                bottom: 0,
                child: Center(child: _SeekIndicator(forward: false, seconds: _seekSeconds)),
              ),
            if (_showSeekRight)
              Positioned(
                right: 40,
                top: 0,
                bottom: 0,
                child: Center(child: _SeekIndicator(forward: true, seconds: _seekSeconds)),
              ),

            // Controls overlay
            FadeTransition(
              opacity: _controlsOpacity,
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Top gradient
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xCC000000),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bottom gradient
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 140,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xDD000000),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Top bar
                    SafeArea(child: _buildTopBar()),
                    // Bottom controls
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(child: _buildBottomControls()),
                    ),
                    // Center play/pause
                    Center(child: _buildCenterPlayPause()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Speed button
          PopupMenuButton<double>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            color: const Color(0xFF1E1E2E),
            onSelected: (v) {
              setState(() => _playbackSpeed = v);
              player.setRate(v);
              _showControls();
            },
            itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                .map((v) => PopupMenuItem(
                      value: v,
                      child: Text(
                        '${v}x',
                        style: TextStyle(
                          color: _playbackSpeed == v
                              ? Colors.purple.shade200
                              : Colors.white,
                          fontWeight: _playbackSpeed == v
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final maxMs = _duration.inMilliseconds.toDouble();
    final safeMax = maxMs > 0 ? maxMs : 1.0;
    final safeVal = _sliderValue.clamp(0.0, safeMax);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seekbar
          Row(
            children: [
              Text(
                _fmt(_position),
                style: const TextStyle(
                    color: Colors.white, fontSize: 11),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: Colors.deepPurpleAccent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.deepPurpleAccent,
                    overlayColor: Colors.deepPurpleAccent.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: safeVal,
                    max: safeMax,
                    onChangeStart: (_) {
                      _isSeeking = true;
                      _hideTimer?.cancel();
                    },
                    onChanged: (v) => setState(() => _sliderValue = v),
                    onChangeEnd: (v) {
                      _isSeeking = false;
                      player.seek(Duration(milliseconds: v.toInt()));
                      _startHideTimer();
                    },
                  ),
                ),
              ),
              Text(
                _fmt(_duration),
                style: const TextStyle(
                    color: Colors.white, fontSize: 11),
              ),
            ],
          ),
          // Buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Prev 10s
              IconButton(
                icon: const Icon(Icons.replay_10_rounded,
                    color: Colors.white, size: 26),
                onPressed: () {
                  player.seek(_position - const Duration(seconds: 10));
                  _showControls();
                },
              ),
              // Play/Pause
              GestureDetector(
                onTap: () {
                  player.playOrPause();
                  _showControls();
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white38, width: 1),
                  ),
                  child: Icon(
                    _isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              // Next 10s
              IconButton(
                icon: const Icon(Icons.forward_10_rounded,
                    color: Colors.white, size: 26),
                onPressed: () {
                  player.seek(_position + const Duration(seconds: 10));
                  _showControls();
                },
              ),
              // Aspect Ratio toggle (placeholder)
              IconButton(
                icon: const Icon(Icons.aspect_ratio,
                    color: Colors.white70, size: 22),
                onPressed: () => _showControls(),
              ),
              // Fullscreen toggle
              IconButton(
                icon: Icon(
                  _isFullScreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen,
                  color: Colors.white,
                  size: 26,
                ),
                onPressed: () {
                  setState(() => _isFullScreen = !_isFullScreen);
                  if (_isFullScreen) {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.immersiveSticky);
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.landscapeRight,
                      DeviceOrientation.landscapeLeft,
                    ]);
                  } else {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.edgeToEdge);
                    SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                    ]);
                  }
                  _showControls();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCenterPlayPause() {
    return AnimatedOpacity(
      opacity: _controlsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: () {
          player.playOrPause();
          _showControls();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.45),
            border:
                Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

// ─── Namida-style Loading Animation ──────────────────────────────────────────
class _NamidaLoader extends StatefulWidget {
  const _NamidaLoader();

  @override
  State<_NamidaLoader> createState() => _NamidaLoaderState();
}

class _NamidaLoaderState extends State<_NamidaLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return SizedBox(
          width: 60,
          height: 60,
          child: CustomPaint(
            painter: _ThreeArchedCirclePainter(_ctrl.value),
          ),
        );
      },
    );
  }
}

class _ThreeArchedCirclePainter extends CustomPainter {
  final double progress;
  _ThreeArchedCirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final baseAngle = progress * 6.28318; // 2π

    final colors = [
      Colors.deepPurpleAccent,
      Colors.purpleAccent,
      Colors.cyanAccent,
    ];

    for (int i = 0; i < 3; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final startAngle = baseAngle + i * 2.09440; // 2π/3
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - i * 5),
        startAngle,
        1.5708, // π/2
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ThreeArchedCirclePainter old) =>
      old.progress != progress;
}

// ─── Seek Indicator ───────────────────────────────────────────────────────────
class _SeekIndicator extends StatelessWidget {
  final bool forward;
  final int seconds;

  const _SeekIndicator({required this.forward, required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            '${seconds}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
