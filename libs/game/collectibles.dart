import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CollectibleType { coin, gem, fuel }

class Collectible {
  Collectible({required this.id, required this.type, required this.position});

  int id;
  CollectibleType type;
  Offset position;

  bool collected = false;

  void reset({
    required int id,
    required CollectibleType type,
    required Offset position,
  }) {
    this.id = id;
    this.type = type;
    this.position = position;
    collected = false;
  }

  // Visual pickup radius. The game adds wheel/body radii and swept motion
  // checks around this value in HillRiderGame so fast touches still count.
  double get collectRadius => switch (type) {
    CollectibleType.coin => 38,
    CollectibleType.gem => 40,
    CollectibleType.fuel => 46,
  };

  void render(Canvas canvas, double time) {
    if (collected) {
      return;
    }

    switch (type) {
      case CollectibleType.coin:
        _drawCoin(canvas, time);
      case CollectibleType.gem:
        _drawGem(canvas, time);
      case CollectibleType.fuel:
        _drawFuelCell(canvas, time);
    }
  }

  void _drawCoin(Canvas canvas, double time) {
    final bob = math.sin(time * 4.2 + id) * 4;
    final pulse = 0.5 + math.sin(time * 5 + id) * 0.5;
    final center = position.translate(0, bob);
    final glow = Paint()
      ..color = Color.lerp(
        const Color(0x33FFD166),
        const Color(0x66FFF1A8),
        pulse,
      )!;
    final outer = Paint()..color = const Color(0xFFFFB703);
    final inner = Paint()..color = const Color(0xFFFFD166);
    final rim = Paint()
      ..color = const Color(0xFFFFF3B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final shine = Paint()..color = const Color(0xD9FFF8C9);

    canvas.drawCircle(center, 22, glow);
    canvas.drawCircle(center, 14, outer);
    canvas.drawCircle(center, 8.5, inner);
    canvas.drawCircle(center, 12.2, rim);
    canvas.drawCircle(center.translate(-4.6, -4.8), 3.2, shine);
  }

  void _drawGem(Canvas canvas, double time) {
    final bob = math.sin(time * 3.8 + id) * 5;
    final pulse = 0.55 + math.sin(time * 5.6 + id) * 0.45;
    final center = position.translate(0, bob);
    final glow = Paint()
      ..color = Color.lerp(
        const Color(0x4446C7CF),
        const Color(0x887FD9DF),
        pulse,
      )!;
    final outline = Paint()..color = const Color(0xFF07111F);
    final body = Paint()..color = const Color(0xFF57C7C1);
    final shine = Paint()..color = const Color(0xFFE7FDFF);

    canvas.drawCircle(center, 24, glow);
    final gem = Path()
      ..moveTo(center.dx, center.dy - 22)
      ..lineTo(center.dx + 19, center.dy - 5)
      ..lineTo(center.dx + 10, center.dy + 19)
      ..lineTo(center.dx - 10, center.dy + 19)
      ..lineTo(center.dx - 19, center.dy - 5)
      ..close();
    final inner = Path()
      ..moveTo(center.dx, center.dy - 16)
      ..lineTo(center.dx + 12, center.dy - 4)
      ..lineTo(center.dx + 6, center.dy + 12)
      ..lineTo(center.dx - 6, center.dy + 12)
      ..lineTo(center.dx - 12, center.dy - 4)
      ..close();
    canvas.drawPath(gem, outline);
    canvas.drawPath(inner, body);
    canvas.drawLine(
      center.translate(-6, -5),
      center.translate(5, -11),
      Paint()
        ..color = shine.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawFuelCell(Canvas canvas, double time) {
    final bob = math.sin(time * 3.2 + id) * 3;
    final pulse = 0.55 + math.sin(time * 5.2 + id) * 0.45;
    final center = position.translate(0, bob);
    final glow = Paint()
      ..color = Color.lerp(
        const Color(0x6657C7A3),
        const Color(0xAA9DE7AE),
        pulse,
      )!;
    final shadow = Paint()..color = const Color(0x66000000);
    final outline = Paint()..color = const Color(0xFF07111F);
    final shell = Paint()..color = const Color(0xFF12283B);
    final glass = Paint()..color = const Color(0xFF69D58A);
    final core = Paint()..color = const Color(0xFFE7FDFF);

    canvas.drawCircle(center, 31, glow);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 26), width: 42, height: 11),
      shadow,
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.sin(time * 2 + id) * 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -24, 36, 48),
        const Radius.circular(10),
      ),
      outline,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-14, -20, 28, 40),
        const Radius.circular(8),
      ),
      shell,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -15, 16, 30),
        const Radius.circular(8),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -10, 6, 20),
        const Radius.circular(3),
      ),
      core,
    );
    canvas.drawLine(
      const Offset(-12, -2),
      const Offset(12, -2),
      Paint()
        ..color = const Color(0x668CCF75)
        ..strokeWidth = 2,
    );
    canvas.restore();
  }
}
