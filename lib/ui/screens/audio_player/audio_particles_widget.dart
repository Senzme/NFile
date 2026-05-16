import 'dart:math';
import 'package:flutter/material.dart';

class AudioParticle {
  double x;
  double y;
  double speed;
  double radius;
  double alpha;

  AudioParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.alpha,
  });
}

class AudioParticlesWidget extends StatefulWidget {
  final bool isPlaying;
  final Color accentColor;

  const AudioParticlesWidget({
    super.key,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  State<AudioParticlesWidget> createState() => _AudioParticlesWidgetState();
}

class _AudioParticlesWidgetState extends State<AudioParticlesWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<AudioParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        if (widget.isPlaying) {
          _updateParticles();
        }
      });

    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioParticlesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _controller.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller.stop();
    }
  }

  void _initParticlesIfNeeded(Size size) {
    if (_particles.isNotEmpty || size.width == 0) return;
    for (int i = 0; i < 40; i++) {
      _particles.add(
        AudioParticle(
          x: _random.nextDouble() * size.width,
          y: _random.nextDouble() * size.height,
          speed: 0.5 + _random.nextDouble() * 1.5,
          radius: 1.5 + _random.nextDouble() * 3.5,
          alpha: 0.1 + _random.nextDouble() * 0.4,
        ),
      );
    }
  }

  void _updateParticles() {
    final size = MediaQuery.of(context).size;
    if (size.width == 0) return;
    _initParticlesIfNeeded(size);

    for (var p in _particles) {
      p.y -= p.speed;
      if (p.y < -10) {
        p.y = size.height + 10;
        p.x = _random.nextDouble() * size.width;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _initParticlesIfNeeded(size);

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ParticlesPainter(
          particles: _particles,
          color: widget.accentColor,
        ),
      ),
    );
  }
}

class _ParticlesPainter extends CustomPainter {
  final List<AudioParticle> particles;
  final Color color;

  _ParticlesPainter({required this.particles, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = color.withOpacity(p.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) => true;
}
