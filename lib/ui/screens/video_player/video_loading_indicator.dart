import 'package:flutter/material.dart';

class VideoLoadingIndicator extends StatefulWidget {
  const VideoLoadingIndicator({super.key});

  @override
  State<VideoLoadingIndicator> createState() => _VideoLoadingIndicatorState();
}

class _VideoLoadingIndicatorState extends State<VideoLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _ThreeArchedCirclePainter(_controller.value),
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
    final radius = size.width / 2 - 6;
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
        Rect.fromCircle(center: center, radius: radius - i * 6),
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
