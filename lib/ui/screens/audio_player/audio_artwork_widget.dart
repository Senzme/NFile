import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

class AudioArtworkCache {
  static final Map<int, Uint8List?> _cache = {};
  static final Map<int, Future<Uint8List?>> _pending = {};

  static Future<Uint8List?> getArtwork(int audioId) async {
    if (_cache.containsKey(audioId)) return _cache[audioId];
    if (_pending.containsKey(audioId)) return _pending[audioId];

    final audioQuery = OnAudioQuery();
    final future = audioQuery.queryArtwork(
      audioId,
      ArtworkType.AUDIO,
      size: 600,
      quality: 100,
    );
    _pending[audioId] = future;
    try {
      final data = await future;
      _cache[audioId] = data;
      _pending.remove(audioId);
      return data;
    } catch (_) {
      _pending.remove(audioId);
      return null;
    }
  }
}

class AudioArtworkWidget extends StatefulWidget {
  final int audioId;
  final Color accentColor;
  final bool isPlaying;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const AudioArtworkWidget({
    super.key,
    required this.audioId,
    required this.accentColor,
    required this.isPlaying,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<AudioArtworkWidget> createState() => _AudioArtworkWidgetState();
}

class _AudioArtworkWidgetState extends State<AudioArtworkWidget>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  late AnimationController _revertController;
  late Animation<double> _revertAnimX;
  late Animation<double> _revertAnimY;

  Uint8List? _artworkBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _revertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant AudioArtworkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioId != widget.audioId) {
      _loadArtwork();
    }
  }

  Future<void> _loadArtwork() async {
    if (widget.audioId == 0) {
      if (mounted) {
        setState(() {
          _artworkBytes = null;
          _isLoading = false;
        });
      }
      return;
    }

    final cached = AudioArtworkCache._cache[widget.audioId];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _artworkBytes = cached;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    final data = await AudioArtworkCache.getArtwork(widget.audioId);
    if (mounted) {
      setState(() {
        _artworkBytes = data;
        _isLoading = false;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_revertController.isAnimating) _revertController.stop();
    setState(() {
      _tiltX += details.delta.dy * -0.005;
      _tiltY += details.delta.dx * 0.005;
      _tiltX = _tiltX.clamp(-0.2, 0.2);
      _tiltY = _tiltY.clamp(-0.2, 0.2);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _revertAnimX = Tween<double>(begin: _tiltX, end: 0.0).animate(
      CurvedAnimation(parent: _revertController, curve: Curves.easeOutBack),
    );
    _revertAnimY = Tween<double>(begin: _tiltY, end: 0.0).animate(
      CurvedAnimation(parent: _revertController, curve: Curves.easeOutBack),
    );
    _revertController.addListener(_revertListener);
    _revertController.forward(from: 0);
  }

  void _revertListener() {
    if (!mounted) return;
    setState(() {
      _tiltX = _revertAnimX.value;
      _tiltY = _revertAnimY.value;
    });
  }

  @override
  void dispose() {
    _revertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.85;
    final maxSize = size.clamp(260.0, 360.0);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: widget.isPlaying ? 1.02 : 0.98,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        child: Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_tiltX)
            ..rotateY(_tiltY),
          alignment: Alignment.center,
          child: Container(
            width: maxSize,
            height: maxSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(widget.isPlaying ? 0.35 : 0.15),
                  blurRadius: 40,
                  spreadRadius: 8,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                color: widget.accentColor.withOpacity(0.12),
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: widget.accentColor,
                          strokeWidth: 2,
                        ),
                      )
                    : _artworkBytes != null
                        ? Image.memory(
                            _artworkBytes!,
                            fit: BoxFit.cover,
                            width: maxSize,
                            height: maxSize,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) => _defaultArtworkIcon(maxSize),
                          )
                        : _defaultArtworkIcon(maxSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultArtworkIcon(double size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_rounded, size: size * 0.3, color: widget.accentColor.withOpacity(0.8)),
          const SizedBox(height: 12),
          Text(
            'Lossless Audio',
            style: TextStyle(
               color: widget.accentColor.withOpacity(0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
