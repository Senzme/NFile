import 'package:flutter/material.dart';

class VerticalSliderWidget extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final IconData icon;
  final String label;

  const VerticalSliderWidget({
    super.key,
    required this.value,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 48.0,
        height: 180.0,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16.0,
              spreadRadius: 4.0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          children: [
            Text(
              '${(value * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 6.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                  ),
                  FractionallySizedBox(
                    heightFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      width: 6.0,
                      decoration: BoxDecoration(
                        color: Colors.deepPurpleAccent.shade200,
                        borderRadius: BorderRadius.circular(3.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurpleAccent.shade200,
                            blurRadius: 8.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10.0),
            Icon(
              icon,
              color: Colors.white,
              size: 20.0,
            ),
          ],
        ),
      ),
    );
  }
}
