import 'dart:math';
import 'package:flutter/material.dart';

class AudioWaveformWidget extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final Color accentColor;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onSeekStart;

  const AudioWaveformWidget({
    super.key,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.accentColor,
    required this.onSeek,
    this.onSeekStart,
  });

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final int _barCount = 56;
  late List<double> _normalizedHeights;
  double? _dragPercentage;
  double? _pendingPositionPercentage;
  DateTime? _pendingSetTime;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isPlaying) {
      _animController.repeat();
    }
    _generateStaticWaveform();
  }

  @override
  void didUpdateWidget(AudioWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animController.stop();
    }
  }

  void _generateStaticWaveform() {
    final rand = Random(42); // deterministic random for beautiful fixed peaks
    _normalizedHeights = List.generate(_barCount, (i) {
      // smooth envelope across the width
      double x = (i / (_barCount - 1)) * 2 - 1;
      double envelope = exp(-x * x * 2.5);
      return (envelope * 0.6 + rand.nextDouble() * 0.4).clamp(0.08, 1.0);
    });
  }

  void _updateDragPercentage(Offset localPosition, double width) {
    if (width <= 0) return;
    setState(() {
      _dragPercentage = (localPosition.dx / width).clamp(0.0, 1.0);
      _pendingPositionPercentage = null;
    });
  }

  void _finalizeSeek(double safeDur) {
    if (_dragPercentage != null) {
      final targetMs = safeDur * _dragPercentage!;
      widget.onSeek(Duration(milliseconds: targetMs.toInt()));
      setState(() {
        _pendingPositionPercentage = _dragPercentage;
        _pendingSetTime = DateTime.now();
        _dragPercentage = null;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeDur = widget.duration.inMilliseconds > 0
        ? widget.duration.inMilliseconds.toDouble()
        : 1.0;

    if (_pendingPositionPercentage != null) {
      final targetMs = safeDur * _pendingPositionPercentage!;
      final diff = (widget.position.inMilliseconds - targetMs).abs();
      final elapsed = _pendingSetTime != null
          ? DateTime.now().difference(_pendingSetTime!).inMilliseconds
          : 1000;

      if (diff < 1200 || elapsed > 800) {
        _pendingPositionPercentage = null;
        _pendingSetTime = null;
      }
    }

    final percentage = _dragPercentage ??
        _pendingPositionPercentage ??
        (widget.position.inMilliseconds / safeDur).clamp(0.0, 1.0);

    final decorationBehind = BoxDecoration(
      color: theme.colorScheme.onSurface.withOpacity(0.15),
      borderRadius: BorderRadius.circular(5),
    );

    final decorationFront = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(5),
      boxShadow: [
        BoxShadow(
          color: widget.accentColor.withOpacity(0.5),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    );

    final activeColors = [
      Color.alphaBlend(widget.accentColor.withAlpha(220), theme.colorScheme.onSurface),
      Color.alphaBlend(widget.accentColor.withAlpha(180), theme.colorScheme.onSurface),
      Colors.transparent,
      Colors.transparent,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = (constraints.maxWidth / _barCount) * 0.55;
        const maxBarHeight = 54.0;
        const minBarHeight = 4.0;

        return AnimatedBuilder(
          animation: _animController,
          builder: (context, _) {
            // subtle dynamic breathing when playing
            final breath = widget.isPlaying ? sin(_animController.value * 2 * pi) * 0.08 : 0.0;

            final behindBars = Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                double h = (_normalizedHeights[i] + (i % 2 == 0 ? breath : -breath))
                        .clamp(0.0, 1.0) *
                    maxBarHeight;
                h = h.clamp(minBarHeight, maxBarHeight);
                return SizedBox(
                  width: barWidth,
                  height: h,
                  child: DecoratedBox(decoration: decorationBehind),
                );
              }),
            );

            final frontBars = Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_barCount, (i) {
                double h = (_normalizedHeights[i] + (i % 2 == 0 ? breath : -breath))
                        .clamp(0.0, 1.0) *
                    maxBarHeight;
                h = h.clamp(minBarHeight, maxBarHeight);
                return SizedBox(
                  width: barWidth,
                  height: h,
                  child: DecoratedBox(decoration: decorationFront),
                );
              }),
            );

            final shaderMaskedFront = ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) {
                return LinearGradient(
                  stops: [0.0, percentage, percentage + 0.005, 1.0],
                  colors: activeColors,
                ).createShader(bounds);
              },
              child: frontBars,
            );

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) {
                  widget.onSeekStart?.call();
                  _updateDragPercentage(details.localPosition, constraints.maxWidth);
                },
                onPanUpdate: (details) {
                  _updateDragPercentage(details.localPosition, constraints.maxWidth);
                },
                onPanEnd: (_) {
                  _finalizeSeek(safeDur);
                },
                onTapDown: (details) {
                  widget.onSeekStart?.call();
                  _updateDragPercentage(details.localPosition, constraints.maxWidth);
                },
                onTapUp: (_) {
                  _finalizeSeek(safeDur);
                },
                onTapCancel: () {
                  setState(() {
                    _dragPercentage = null;
                  });
                },
                child: SizedBox(
                  height: maxBarHeight + 16,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        behindBars,
                        shaderMaskedFront,
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
