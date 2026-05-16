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

  void _handleSeekGesture(Offset localPosition, double width) {
    if (width <= 0 || widget.duration.inMilliseconds == 0) return;
    double percentage = (localPosition.dx / width).clamp(0.0, 1.0);
    final targetMs = widget.duration.inMilliseconds * percentage;
    widget.onSeek(Duration(milliseconds: targetMs.toInt()));
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
    final percentage = (widget.position.inMilliseconds / safeDur).clamp(0.0, 1.0);

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
                onPanDown: (_) => widget.onSeekStart?.call(),
                onTapDown: (details) => _handleSeekGesture(details.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (details) => _handleSeekGesture(details.localPosition, constraints.maxWidth),
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
