import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ParticleKind { dust, landing, sparkle, crash, speedStreak, shockwave }

class GameParticle {
  GameParticle({
    required this.kind,
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
    required this.life,
    this.gravity = 0,
  }) : maxLife = life;

  GameParticle.empty()
    : kind = ParticleKind.dust,
      maxLife = 0,
      color = const Color(0x00000000),
      radius = 0,
      gravity = 0,
      position = Offset.zero,
      velocity = Offset.zero,
      life = 0;

  ParticleKind kind;
  double maxLife;
  Color color;
  double radius;
  double gravity;

  Offset position;
  Offset velocity;
  double life;

  bool get isDead => life <= 0;

  void reset({
    required ParticleKind kind,
    required Offset position,
    required Offset velocity,
    required Color color,
    required double radius,
    required double life,
    double gravity = 0,
  }) {
    this.kind = kind;
    this.position = position;
    this.velocity = velocity;
    this.color = color;
    this.radius = radius;
    this.life = life;
    maxLife = life;
    this.gravity = gravity;
  }

  void update(double dt) {
    life -= dt;
    velocity = velocity.translate(0, gravity * dt);
    position = position.translate(velocity.dx * dt, velocity.dy * dt);
  }

  void render(Canvas canvas) {
    final t = (life / maxLife).clamp(0, 1).toDouble();
    final alpha = color.a * t;
    final paint = Paint()..color = color.withValues(alpha: alpha);

    switch (kind) {
      case ParticleKind.sparkle:
        final sparklePaint = Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeWidth = 2.4 * t
          ..strokeCap = StrokeCap.round;
        final length = radius * (0.8 + (1 - t) * 0.9);
        canvas.drawLine(
          position.translate(-length, 0),
          position.translate(length, 0),
          sparklePaint,
        );
        canvas.drawLine(
          position.translate(0, -length),
          position.translate(0, length),
          sparklePaint,
        );
      case ParticleKind.dust:
        final glow = Paint()..color = color.withValues(alpha: alpha * 0.16);
        canvas.drawCircle(position, radius * 1.7, glow);
        canvas.drawCircle(position, radius * (1.08 - t * 0.2), paint);
      case ParticleKind.landing:
        final puff = Paint()
          ..color = color.withValues(alpha: alpha * 0.48)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(position, radius * (1.5 + (1 - t) * 0.8), puff);
        canvas.drawCircle(position, radius * (1.0 + (1 - t) * 0.4), paint);
      case ParticleKind.crash:
        final shard = Path()
          ..moveTo(position.dx + math.cos(life * 13) * radius, position.dy)
          ..lineTo(position.dx - radius * 0.65, position.dy - radius * 0.44)
          ..lineTo(position.dx - radius * 0.22, position.dy + radius * 0.72)
          ..close();
        canvas.drawPath(shard, paint);
      case ParticleKind.speedStreak:
        final streak = Paint()
          ..color = color.withValues(alpha: alpha * 0.72)
          ..strokeWidth = radius
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          position,
          position.translate(-46 - radius * 8, 0),
          streak,
        );
      case ParticleKind.shockwave:
        final ring = Paint()
          ..color = color.withValues(alpha: alpha * 0.74)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, radius * 0.22 * t);
        canvas.drawOval(
          Rect.fromCenter(
            center: position,
            width: radius * (2.2 - t) * 5,
            height: radius * (2.2 - t) * 1.15,
          ),
          ring,
        );
    }
  }
}
