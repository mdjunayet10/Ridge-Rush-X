import 'dart:math' as math;

import 'package:flutter/material.dart';

class CartoonBackground extends StatelessWidget {
  const CartoonBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _GoldenDayBackgroundPainter(),
      child: child,
    );
  }
}

class _GoldenDayBackgroundPainter extends CustomPainter {
  const _GoldenDayBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFB15F),
          Color(0xFFF1C27B),
          Color(0xFFC67D4D),
          Color(0xFF6E4635),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    _drawSun(canvas, Offset(size.width - 94, 96));
    _drawClouds(canvas, size);
    _drawMountainLayer(
      canvas,
      size,
      baseY: size.height * 0.52,
      amplitude: 132,
      color: const Color(0xFF8C6248),
      rim: const Color(0x55FFE2A1),
      phase: 0.9,
    );
    _drawMountainLayer(
      canvas,
      size,
      baseY: size.height * 0.66,
      amplitude: 104,
      color: const Color(0xFF6C4938),
      rim: const Color(0x44FFD39B),
      phase: 2.4,
    );
    _drawMountainLayer(
      canvas,
      size,
      baseY: size.height * 0.78,
      amplitude: 68,
      color: const Color(0xFF4B352D),
      rim: const Color(0x33E0B46C),
      phase: 4.0,
    );
    _drawMist(canvas, size, size.height * 0.70);

    final groundTop = size.height * 0.83;
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, size.width, size.height - groundTop),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5F3824), Color(0xFF281A14)],
        ).createShader(Rect.fromLTWH(0, groundTop, size.width, size.height)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop - 2, size.width, 4),
      Paint()..color = const Color(0xFFE0B46C),
    );
    _drawForegroundRocks(canvas, size, groundTop);
  }

  void _drawSun(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center,
      62,
      Paint()
        ..color = const Color(0x66FFF4C7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(center, 34, Paint()..color = const Color(0xFFFFE2A1));
  }

  void _drawClouds(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x55FFF8E8);
    for (var i = 0; i < 7; i += 1) {
      final x = (i * 151.0 + math.sin(i * 1.7) * 42) % math.max(1, size.width);
      final y = size.height * (0.16 + (i % 3) * 0.075);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 132, height: 28),
        paint,
      );
    }
  }

  void _drawMist(Canvas canvas, Size size, double y) {
    for (var i = 0; i < 4; i += 1) {
      final top = y + i * 18;
      canvas.drawRect(
        Rect.fromLTWH(0, top, size.width, 28),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFE2A1), Color(0x20FFE2A1), Color(0x00FFE2A1)],
          ).createShader(Rect.fromLTWH(0, top, size.width, 28)),
      );
    }
  }

  void _drawForegroundRocks(Canvas canvas, Size size, double groundTop) {
    final paint = Paint()..color = const Color(0xFF241712);
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width + 80; x += 80) {
      final peak = groundTop + 18 + math.sin(x * 0.021) * 18;
      path
        ..lineTo(x + 22, peak)
        ..lineTo(x + 56, groundTop + 44 + math.sin(x * 0.013) * 12);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawMountainLayer(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double amplitude,
    required Color color,
    required Color rim,
    required double phase,
  }) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, baseY);

    final safeWidth = math.max(1.0, size.width);
    for (var x = 0.0; x <= size.width + 70; x += 70) {
      final t = x / safeWidth;
      final y =
          baseY -
          math.sin(t * math.pi * 2.0 + phase).abs() * amplitude -
          math.sin(t * math.pi * 5.0 + phase * 0.7).abs() * amplitude * 0.24;
      path.lineTo(x, y);
    }

    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
