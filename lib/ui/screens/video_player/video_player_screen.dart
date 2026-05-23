import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:nfile/core/icon_fonts/broken_icons.dart';
import 'video_loading_indicator.dart';
import 'video_seek_indicator.dart';
import 'video_controls_overlay.dart';
import 'vertical_slider_widget.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final List<String>? playlist;
  final List<AssetEntity>? assetPlaylist;
  final int? initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    this.playlist,
    this.assetPlaylist,
    this.initialIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with TickerProviderStateMixin {
  late final Player player;
  late final VideoController controller;

  late int _currentIndex;
  bool _isResolvingAsset = false;

  bool _controlsVisible = true;
  bool _isPlaying = false;
  bool _isSeeking = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _sliderValue = 0;
  bool _isFullScreen = false;
  bool _isLocked = false;
  double _playbackSpeed = 1.0;
  bool _isBuffering = false;

  // Swipes for Volume & Brightness
  double _volume = 0.8; // 0.0 to 1.0
  double _brightness = 1.0; // 0.0 to 1.0
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  Timer? _sliderTimer;

  Timer? _hideTimer;
  late AnimationController _controlsAnimController;
  late Animation<double> _controlsOpacity;

  // Double-tap seek accumulation & animation
  bool _showSeekLeft = false;
  bool _showSeekRight = false;
  Timer? _seekIndicatorTimer;
  int _seekSeconds = 0;
  bool _lastSeekWasForward = true;

  // Long press 2.0x speed
  bool _isLongPressSpeed = false;
  double _previousSpeed = 1.0;

  // Utilities
  bool _isMuted = false;
  int _repeatMode = 0; // 0=none, 1=one, 2=all

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;

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

    player = Player(
      configuration: const PlayerConfiguration(
        ready: null,
        logLevel: MPVLogLevel.warn,
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    controller = VideoController(
      player,
      configuration: const VideoControllerConfiguration(
        hwdec: 'auto-safe',
      ),
    );

    _initListeners();
    player.open(Media(widget.videoPath));
    player.setVolume(_volume * 100.0);
    _startHideTimer();
  }

  void _initListeners() {
    player.stream.playing.listen((v) {
      if (!mounted) return;
      setState(() => _isPlaying = v);
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

    player.stream.completed.listen((v) {
      if (!v || !mounted) return;
      if (_repeatMode == 1 || _repeatMode == 2) {
        player.seek(Duration.zero);
        player.play();
      }
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isSeeking) {
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
    if (_isLocked) return;
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControls();
    }
  }

  Future<void> _playAtIndex(int index) async {
    if (widget.playlist == null && widget.assetPlaylist == null) return;
    final playlistLength = widget.playlist?.length ?? widget.assetPlaylist?.length ?? 0;
    if (index < 0 || index >= playlistLength) return;

    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
      _duration = Duration.zero;
      _sliderValue = 0;
      _isBuffering = true;
    });

    if (widget.playlist != null) {
      player.open(Media(widget.playlist![index]));
    } else if (widget.assetPlaylist != null) {
      setState(() => _isResolvingAsset = true);
      try {
        final asset = widget.assetPlaylist![index];
        final file = await asset.file;
        if (file != null && mounted) {
          player.open(Media(file.path));
        }
      } catch (e) {
        debugPrint('Error resolving video asset: $e');
      } finally {
        if (mounted) setState(() => _isResolvingAsset = false);
      }
    }
    _startHideTimer();
  }

  void _onNext() {
    final playlistLength = widget.playlist?.length ?? widget.assetPlaylist?.length ?? 0;
    if (_currentIndex + 1 < playlistLength) {
      _playAtIndex(_currentIndex + 1);
    }
  }

  void _onPrevious() {
    if (_currentIndex - 1 >= 0) {
      _playAtIndex(_currentIndex - 1);
    }
  }

  void _onDoubleTapLeft() {
    if (_isLocked) return;
    if (_lastSeekWasForward || _seekSeconds == 0) {
      _seekSeconds = 10;
    } else {
      _seekSeconds += 10;
    }
    _lastSeekWasForward = false;
    player.seek(_position - const Duration(seconds: 10));

    setState(() {
      _showSeekLeft = true;
      _showSeekRight = false;
    });

    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _showSeekLeft = false;
          _seekSeconds = 0;
        });
      }
    });
  }

  void _onDoubleTapRight() {
    if (_isLocked) return;
    if (!_lastSeekWasForward || _seekSeconds == 0) {
      _seekSeconds = 10;
    } else {
      _seekSeconds += 10;
    }
    _lastSeekWasForward = true;
    player.seek(_position + const Duration(seconds: 10));

    setState(() {
      _showSeekRight = true;
      _showSeekLeft = false;
    });

    _seekIndicatorTimer?.cancel();
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _showSeekRight = false;
          _seekSeconds = 0;
        });
      }
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, bool isLeft) {
    if (_isLocked) return;
    final delta = -details.primaryDelta! / 250.0;
    setState(() {
      if (isLeft) {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        if (!_isMuted) player.setVolume(_volume * 100.0);
        _showVolumeSlider = true;
        _showBrightnessSlider = false;
      } else {
        _brightness = (_brightness + delta).clamp(0.1, 1.0);
        _showBrightnessSlider = true;
        _showVolumeSlider = false;
      }
    });

    _sliderTimer?.cancel();
    _sliderTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showVolumeSlider = false;
          _showBrightnessSlider = false;
        });
      }
    });
  }

  void _startLongPress() {
    if (_isLocked) return;
    _previousSpeed = _playbackSpeed;
    player.setRate(2.0);
    setState(() => _isLongPressSpeed = true);
  }

  void _endLongPress() {
    if (!_isLongPressSpeed) return;
    player.setRate(_previousSpeed);
    setState(() => _isLongPressSpeed = false);
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _showControls();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _sliderTimer?.cancel();
    _controlsAnimController.dispose();
    player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  String get _fileName {
    String currentPath = widget.videoPath;
    if (widget.playlist != null) {
      currentPath = widget.playlist![_currentIndex];
    } else if (widget.assetPlaylist != null) {
      currentPath = widget.assetPlaylist![_currentIndex].title ?? 'Video';
    }
    final name = currentPath.split('/').last.split('\\').last;
    return name.length > 40 ? '${name.substring(0, 37)}...' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main Video Surface
          Video(
            controller: controller,
            controls: NoVideoControls,
            fit: BoxFit.contain,
          ),

          // Brightness Dimming Overlay
          IgnorePointer(
            child: Container(
              color: Colors.black.withOpacity(1.0 - _brightness),
            ),
          ),

          // Animated Buffering / Asset Resolution Indicator
          if (_isBuffering || _isResolvingAsset)
            const Center(
              child: VideoLoadingIndicator(),
            ),

          // Gesture Zones (Left/Right Drag, Double Tap & Long Press)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _onDoubleTapLeft,
                  onTap: _toggleControls,
                  onLongPressStart: (_) => _startLongPress(),
                  onLongPressEnd: (_) => _endLongPress(),
                  onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, true),
                  child: const SizedBox.expand(),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _onDoubleTapRight,
                  onTap: _toggleControls,
                  onLongPressStart: (_) => _startLongPress(),
                  onLongPressEnd: (_) => _endLongPress(),
                  onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, false),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),

          // Double Tap Seek Ripple Waves
          if (_showSeekLeft)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.45,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerRight,
                      radius: 1.0,
                      colors: [Colors.white.withOpacity(0.2), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          if (_showSeekRight)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.45,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.centerLeft,
                      radius: 1.0,
                      colors: [Colors.white.withOpacity(0.2), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),

          // Animated Seek Badge Overlays
          if (_showSeekLeft)
            Positioned(
              left: 64,
              top: 0,
              bottom: 0,
              child: Center(
                child: VideoSeekIndicator(
                  forward: false,
                  seconds: _seekSeconds,
                ),
              ),
            ),
          if (_showSeekRight)
            Positioned(
              right: 64,
              top: 0,
              bottom: 0,
              child: Center(
                child: VideoSeekIndicator(
                  forward: true,
                  seconds: _seekSeconds,
                ),
              ),
            ),

          // Long Press Speed Badge
          if (_isLongPressSpeed)
            Positioned(
              top: 54,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Broken.forward, color: Colors.deepPurpleAccent.shade100, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Speed 2.0x',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Vertical Volume & Brightness Pill Sliders
          if (_showVolumeSlider)
            Positioned(
              left: 36,
              top: 0,
              bottom: 0,
              child: Center(
                child: VerticalSliderWidget(
                  value: _isMuted ? 0.0 : _volume,
                  icon: _isMuted || _volume == 0
                      ? Broken.volume_slash
                      : _volume > 0.5
                          ? Broken.volume_high
                          : Broken.volume_low,
                  label: 'Volume',
                ),
              ),
            ),
          if (_showBrightnessSlider)
            Positioned(
              right: 36,
              top: 0,
              bottom: 0,
              child: Center(
                child: VerticalSliderWidget(
                  value: _brightness,
                  icon: Broken.sun_1,
                  label: 'Brightness',
                ),
              ),
            ),

          // Modular Controls Overlay
          FadeTransition(
            opacity: _controlsOpacity,
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoControlsOverlay(
                    title: _fileName,
                    isPlaying: _isPlaying,
                    position: _position,
                    duration: _duration,
                    sliderValue: _sliderValue,
                    playbackSpeed: _playbackSpeed,
                    isFullScreen: _isFullScreen,
                    isLocked: _isLocked,
                    isMuted: _isMuted,
                    repeatMode: _repeatMode,
                    onChanged: (v) => setState(() => _sliderValue = v),
                    onChangeStart: (_) {
                      _isSeeking = true;
                      _hideTimer?.cancel();
                    },
                    onChangeEnd: (v) {
                      _isSeeking = false;
                      player.seek(Duration(milliseconds: v.toInt()));
                      _startHideTimer();
                    },
                    onPlayPause: () => player.playOrPause(),
                    onRewind: () {
                      player.seek(_position - const Duration(seconds: 10));
                      _showControls();
                    },
                    onFastForward: () {
                      player.seek(_position + const Duration(seconds: 10));
                      _showControls();
                    },
                    onPrevious: (widget.playlist != null || widget.assetPlaylist != null) && _currentIndex > 0 ? _onPrevious : null,
                    onNext: (widget.playlist != null || widget.assetPlaylist != null) && _currentIndex + 1 < (widget.playlist?.length ?? widget.assetPlaylist?.length ?? 0) ? _onNext : null,
                    onToggleFullScreen: _toggleFullScreen,
                    onSelectSpeed: (v) {
                      setState(() => _playbackSpeed = v);
                      player.setRate(v);
                      _showControls();
                    },
                    onToggleLock: () {
                      setState(() => _isLocked = !_isLocked);
                      _showControls();
                    },
                    onToggleMute: () {
                      setState(() {
                        _isMuted = !_isMuted;
                        player.setVolume(_isMuted ? 0.0 : _volume * 100.0);
                      });
                      _showControls();
                    },
                    onToggleRepeat: () {
                      setState(() => _repeatMode = (_repeatMode + 1) % 3);
                      _showControls();
                    },
                    onCopyUrl: () => _showControls(),
                    onInteract: _showControls,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
