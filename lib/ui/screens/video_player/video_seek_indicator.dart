import 'package:flutter/material.dart';

class VideoSeekIndicator extends StatelessWidget {
  final bool forward;
  final int seconds;

  const VideoSeekIndicator({
    super.key,
    required this.forward,
    required this.seconds,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color.fromRGBO(240, 240, 240, 0.95);
    const strokeWidth = 1.8;
    const strokeColor = Color.fromRGBO(10, 10, 10, 0.7);
    const shadowBR = 8.0;

    const outlineShadows = <Shadow>[
      Shadow(offset: Offset(-strokeWidth, -strokeWidth), color: strokeColor, blurRadius: shadowBR),
      Shadow(offset: Offset(strokeWidth, -strokeWidth), color: strokeColor, blurRadius: shadowBR),
      Shadow(offset: Offset(strokeWidth, strokeWidth), color: strokeColor, blurRadius: shadowBR),
      Shadow(offset: Offset(-strokeWidth, strokeWidth), color: strokeColor, blurRadius: shadowBR),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 24,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: color,
            size: 42,
            shadows: outlineShadows,
          ),
          const SizedBox(height: 8),
          Text(
            '${forward ? '+' : '-'}$seconds s',
            style: const TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: outlineShadows,
            ),
          ),
        ],
      ),
    );
  }
}
