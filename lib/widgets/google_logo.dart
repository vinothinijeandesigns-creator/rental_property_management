import 'package:flutter/material.dart';

/// Official multi-colored Google 'G' vector logo
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24.0;

    // 1. Blue path
    final bluePath = Path()
      ..moveTo(23.75 * s, 12.27 * s)
      ..cubicTo(23.75 * s, 11.57 * s, 23.69 * s, 10.87 * s, 23.56 * s, 10.2 * s)
      ..lineTo(12.0 * s, 10.2 * s)
      ..lineTo(12.0 * s, 14.71 * s)
      ..lineTo(18.6 * s, 14.71 * s)
      ..cubicTo(18.31 * s, 16.23 * s, 17.46 * s, 17.53 * s, 16.2 * s, 18.39 * s)
      ..lineTo(16.2 * s, 21.44 * s)
      ..lineTo(20.08 * s, 21.44 * s)
      ..cubicTo(22.35 * s, 19.35 * s, 23.75 * s, 16.27 * s, 23.75 * s, 12.27 * s)
      ..close();
    canvas.drawPath(bluePath, Paint()..color = const Color(0xFF4285F4));

    // 2. Green path
    final greenPath = Path()
      ..moveTo(12.0 * s, 24.0 * s)
      ..cubicTo(15.24 * s, 24.0 * s, 17.95 * s, 22.92 * s, 19.93 * s, 21.09 * s)
      ..lineTo(16.05 * s, 18.04 * s)
      ..cubicTo(14.97 * s, 18.76 * s, 13.6 * s, 19.2 * s, 12.0 * s, 19.2 * s)
      ..cubicTo(8.88 * s, 19.2 * s, 6.23 * s, 17.1 * s, 5.28 * s, 14.27 * s)
      ..lineTo(1.24 * s, 14.27 * s)
      ..lineTo(1.24 * s, 17.42 * s)
      ..cubicTo(3.26 * s, 21.41 * s, 7.34 * s, 24.0 * s, 12.0 * s, 24.0 * s)
      ..close();
    canvas.drawPath(greenPath, Paint()..color = const Color(0xFF34A853));

    // 3. Yellow path
    final yellowPath = Path()
      ..moveTo(5.28 * s, 14.27 * s)
      ..cubicTo(5.03 * s, 13.55 * s, 4.9 * s, 12.78 * s, 4.9 * s, 12.0 * s)
      ..cubicTo(4.9 * s, 11.22 * s, 5.03 * s, 10.45 * s, 5.28 * s, 9.73 * s)
      ..lineTo(5.28 * s, 6.58 * s)
      ..lineTo(1.24 * s, 6.58 * s)
      ..cubicTo(0.45 * s, 8.16 * s, 0.0 * s, 9.98 * s, 0.0 * s, 12.0 * s)
      ..cubicTo(0.0 * s, 14.02 * s, 0.45 * s, 15.84 * s, 1.24 * s, 17.42 * s)
      ..lineTo(5.28 * s, 14.27 * s)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFFBBC05));

    // 4. Red path
    final redPath = Path()
      ..moveTo(12.0 * s, 4.75 * s)
      ..cubicTo(13.77 * s, 4.75 * s, 15.35 * s, 5.36 * s, 16.6 * s, 6.55 * s)
      ..lineTo(20.02 * s, 3.13 * s)
      ..cubicTo(17.95 * s, 1.19 * s, 15.24 * s, 0.0 * s, 12.0 * s, 0.0 * s)
      ..cubicTo(7.34 * s, 0.0 * s, 3.26 * s, 2.59 * s, 1.24 * s, 6.58 * s)
      ..lineTo(5.28 * s, 9.73 * s)
      ..cubicTo(6.23 * s, 6.9 * s, 8.88 * s, 4.75 * s, 12.0 * s, 4.75 * s)
      ..close();
    canvas.drawPath(redPath, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
