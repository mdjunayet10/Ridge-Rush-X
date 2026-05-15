import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/vehicle_definitions.dart';

class VehicleArt {
  const VehicleArt._();

  static void drawVehicle(
    Canvas canvas, {
    required VehicleDefinition vehicle,
    required Offset rearWheel,
    required Offset frontWheel,
    required double wheelRadius,
    required double wheelSpin,
    bool drawSuspension = true,
  }) {
    if (drawSuspension) {
      _drawSuspension(canvas, vehicle, rearWheel, frontWheel);
    }
    _drawWheel(canvas, vehicle, rearWheel, wheelRadius, wheelSpin);
    _drawWheel(canvas, vehicle, frontWheel, wheelRadius, wheelSpin + 0.7);

    if (vehicle.silhouette == VehicleSilhouette.atv) {
      _drawWheel(
        canvas,
        vehicle,
        rearWheel.translate(-24, -1),
        wheelRadius * 0.72,
        wheelSpin,
      );
      _drawWheel(
        canvas,
        vehicle,
        frontWheel.translate(24, -1),
        wheelRadius * 0.72,
        wheelSpin + 0.4,
      );
    }

    _drawBody(canvas, vehicle);
  }

  static List<Color> bodyColors(VehicleSilhouette silhouette) =>
      switch (silhouette) {
        VehicleSilhouette.buggy => const [
          Color(0xFFFF826F),
          Color(0xFFE83F2F),
          Color(0xFF932019),
        ],
        VehicleSilhouette.jeep => const [
          Color(0xFF77D990),
          Color(0xFF2E8B57),
          Color(0xFF175D39),
        ],
        VehicleSilhouette.motorbike => const [
          Color(0xFF66D5C9),
          Color(0xFF2EA7A0),
          Color(0xFF176A67),
        ],
        VehicleSilhouette.atv => const [
          Color(0xFFAED76A),
          Color(0xFF7FAF38),
          Color(0xFF4E7424),
        ],
        VehicleSilhouette.monsterTruck => const [
          Color(0xFFE59B64),
          Color(0xFFB35A32),
          Color(0xFF693321),
        ],
        VehicleSilhouette.cargoTruck => const [
          Color(0xFFFFBA73),
          Color(0xFFD17A2E),
          Color(0xFF8F451B),
        ],
        VehicleSilhouette.desertRacer => const [
          Color(0xFFFFE36A),
          Color(0xFFFFC928),
          Color(0xFFD58213),
        ],
        VehicleSilhouette.rover => const [
          Color(0xFFA8D3DB),
          Color(0xFF6FA8B8),
          Color(0xFF365F6F),
        ],
      };

  static void _drawBody(Canvas canvas, VehicleDefinition vehicle) {
    final outline = Paint()..color = const Color(0xFF05070C);
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: bodyColors(vehicle.silhouette),
      ).createShader(const Rect.fromLTWH(-130, -92, 260, 124));
    final glass = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE0FDFF), Color(0xFF3E8EA0)],
      ).createShader(const Rect.fromLTWH(-40, -75, 110, 60));
    final dark = Paint()..color = const Color(0xFF111111);
    final line = Paint()
      ..color = const Color(0xFF05070C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    switch (vehicle.silhouette) {
      case VehicleSilhouette.buggy:
        _drawStarterBuggy(canvas, outline, body, dark, line, highlight);
      case VehicleSilhouette.jeep:
        _drawTrailJeep(canvas, outline, body, glass, dark, line, highlight);
      case VehicleSilhouette.motorbike:
        _drawMotorbike(canvas, outline, body, dark, line, highlight);
      case VehicleSilhouette.atv:
        _drawAtv(canvas, outline, body, dark, line, highlight);
      case VehicleSilhouette.monsterTruck:
        _drawMonsterTruck(canvas, outline, body, glass, line, highlight);
      case VehicleSilhouette.cargoTruck:
        _drawCargoTruck(canvas, outline, body, glass, line, highlight);
      case VehicleSilhouette.desertRacer:
        _drawDesertRacer(canvas, outline, body, glass, line, highlight);
      case VehicleSilhouette.rover:
        _drawMoonRover(canvas, outline, body, glass, line, highlight);
    }

    _drawDriver(canvas, vehicle);
    _drawLightsAndBumpers(canvas, vehicle, line);
  }

  static void _drawStarterBuggy(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint dark,
    Paint line,
    Paint highlight,
  ) {
    // Simple open buggy silhouette: short wheelbase, low body, clear front,
    // visible cockpit, and separate frame pieces around the big wheels.
    final lowerTub = Path()
      ..moveTo(-84, 10)
      ..lineTo(-71, -12)
      ..quadraticBezierTo(-49, -30, -18, -31)
      ..lineTo(18, -30)
      ..quadraticBezierTo(52, -24, 78, -5)
      ..lineTo(88, 8)
      ..lineTo(59, 17)
      ..lineTo(-69, 17)
      ..close();
    _fillPath(canvas, lowerTub, outline, body);

    final nose = Path()
      ..moveTo(14, -24)
      ..quadraticBezierTo(48, -24, 76, -9)
      ..lineTo(61, 7)
      ..lineTo(6, 2)
      ..close();
    _fillPath(canvas, nose, outline, body);

    final rearDeck = Path()
      ..moveTo(-78, 8)
      ..lineTo(-67, -18)
      ..lineTo(-36, -27)
      ..lineTo(-30, 6)
      ..close();
    _fillPath(canvas, rearDeck, outline, body);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-63, 6, 118, 16),
        const Radius.circular(7),
      ),
      dark,
    );

    final cockpitCutout = Path()
      ..moveTo(-39, -27)
      ..quadraticBezierTo(-21, -45, 8, -43)
      ..quadraticBezierTo(28, -39, 39, -25);
    canvas.drawPath(cockpitCutout, line);

    _drawRollBar(
      canvas,
      const Offset(-48, -22),
      const Offset(-27, -70),
      const Offset(25, -29),
    );

    canvas.drawLine(const Offset(-66, -4), const Offset(-34, -10), highlight);
    canvas.drawLine(const Offset(18, -19), const Offset(63, -8), highlight);

    final tinyBumper = Paint()
      ..color = const Color(0xFF05070C)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(77, 6), const Offset(96, 0), tinyBumper);
    canvas.drawLine(const Offset(-80, 8), const Offset(-96, 4), tinyBumper);
  }

  static void _drawTrailJeep(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint glass,
    Paint dark,
    Paint line,
    Paint highlight,
  ) {
    final shell = Path()
      ..moveTo(-96, 12)
      ..lineTo(-96, -34)
      ..lineTo(-66, -47)
      ..lineTo(-48, -66)
      ..lineTo(30, -66)
      ..lineTo(55, -36)
      ..lineTo(92, -32)
      ..lineTo(94, 12)
      ..close();
    _fillPath(canvas, shell, outline, body);
    _window(canvas, const Rect.fromLTWH(-38, -58, 28, 28), outline, glass);
    _window(canvas, const Rect.fromLTWH(-2, -58, 28, 28), outline, glass);
    canvas.drawCircle(const Offset(-104, -18), 18, outline);
    canvas.drawCircle(const Offset(-104, -18), 13, dark);
    canvas.drawLine(const Offset(-82, -8), const Offset(70, -8), highlight);
    canvas.drawLine(const Offset(52, -32), const Offset(52, 11), line);
  }

  static void _drawMotorbike(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint dark,
    Paint line,
    Paint highlight,
  ) {
    canvas.drawLine(const Offset(-51, 13), const Offset(0, -31), line);
    canvas.drawLine(const Offset(0, -31), const Offset(58, 10), line);
    canvas.drawLine(const Offset(-51, 13), const Offset(58, 10), line);
    canvas.drawLine(const Offset(43, -24), const Offset(76, -43), line);
    canvas.drawLine(const Offset(-46, -31), const Offset(-14, -31), line);
    final tank = Path()
      ..moveTo(-28, -37)
      ..quadraticBezierTo(11, -55, 46, -34)
      ..lineTo(30, -16)
      ..lineTo(-34, -17)
      ..close();
    _fillPath(canvas, tank, outline, body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-48, -42, 34, 11),
        const Radius.circular(5),
      ),
      dark,
    );
    canvas.drawLine(const Offset(-25, -28), const Offset(24, -29), highlight);
  }

  static void _drawAtv(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint dark,
    Paint line,
    Paint highlight,
  ) {
    final shell = Path()
      ..moveTo(-78, 8)
      ..lineTo(-68, -18)
      ..lineTo(-26, -35)
      ..quadraticBezierTo(22, -42, 64, -20)
      ..lineTo(82, 7)
      ..lineTo(52, 15)
      ..lineTo(-56, 15)
      ..close();
    _fillPath(canvas, shell, outline, body);
    canvas.drawLine(const Offset(-88, -5), const Offset(-60, -15), line);
    canvas.drawLine(const Offset(55, -16), const Offset(90, -6), line);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-30, -44, 46, 13),
        const Radius.circular(6),
      ),
      dark,
    );
    canvas.drawLine(const Offset(-55, 0), const Offset(62, 0), highlight);
  }

  static void _drawMonsterTruck(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint glass,
    Paint line,
    Paint highlight,
  ) {
    final bodyPath = Path()
      ..moveTo(-86, -4)
      ..lineTo(-78, -44)
      ..lineTo(-33, -60)
      ..lineTo(40, -58)
      ..lineTo(86, -34)
      ..lineTo(86, -1)
      ..lineTo(54, 8)
      ..lineTo(-62, 8)
      ..close();
    _fillPath(canvas, bodyPath, outline, body);
    _window(canvas, const Rect.fromLTWH(-24, -51, 46, 23), outline, glass);
    canvas.drawLine(const Offset(-64, -19), const Offset(68, -17), highlight);
    canvas.drawLine(const Offset(-54, 12), const Offset(58, 12), line);
  }

  static void _drawCargoTruck(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint glass,
    Paint line,
    Paint highlight,
  ) {
    final bed = Path()
      ..moveTo(-118, 11)
      ..lineTo(-115, -36)
      ..lineTo(2, -36)
      ..lineTo(8, 11)
      ..close();
    final cab = Path()
      ..moveTo(8, 12)
      ..lineTo(8, -58)
      ..lineTo(62, -58)
      ..lineTo(94, -28)
      ..lineTo(94, 12)
      ..close();
    _fillPath(canvas, bed, outline, body);
    _fillPath(canvas, cab, outline, body);
    _window(canvas, const Rect.fromLTWH(31, -48, 31, 22), outline, glass);
    canvas.drawLine(const Offset(-101, -24), const Offset(-8, -24), line);
    canvas.drawLine(const Offset(-98, -5), const Offset(72, -5), highlight);
  }

  static void _drawDesertRacer(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint glass,
    Paint line,
    Paint highlight,
  ) {
    final shell = Path()
      ..moveTo(-110, 8)
      ..lineTo(-78, -17)
      ..lineTo(-20, -33)
      ..lineTo(55, -31)
      ..lineTo(111, -7)
      ..lineTo(88, 12)
      ..lineTo(-91, 13)
      ..close();
    _fillPath(canvas, shell, outline, body);
    final cage = Path()
      ..moveTo(-28, -31)
      ..quadraticBezierTo(6, -65, 52, -31)
      ..moveTo(-2, -47)
      ..lineTo(25, -31);
    canvas.drawPath(cage, line);
    final wind = Path()
      ..moveTo(-8, -44)
      ..lineTo(34, -40)
      ..lineTo(48, -29)
      ..lineTo(-24, -29)
      ..close();
    _fillPath(canvas, wind, outline, glass);
    canvas.drawLine(const Offset(-72, -9), const Offset(91, -7), highlight);
  }

  static void _drawMoonRover(
    Canvas canvas,
    Paint outline,
    Paint body,
    Paint glass,
    Paint line,
    Paint highlight,
  ) {
    canvas.drawLine(const Offset(-108, 15), const Offset(-44, -24), line);
    canvas.drawLine(const Offset(108, 15), const Offset(45, -23), line);
    final shell = Path()
      ..moveTo(-76, 10)
      ..lineTo(-68, -28)
      ..lineTo(-20, -45)
      ..lineTo(51, -36)
      ..lineTo(82, -12)
      ..lineTo(70, 11)
      ..close();
    _fillPath(canvas, shell, outline, body);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -51), width: 68, height: 48),
      outline,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -51), width: 54, height: 35),
      glass,
    );
    canvas.drawLine(const Offset(-56, -2), const Offset(62, -1), highlight);
    canvas.drawLine(const Offset(-40, -44), const Offset(-57, -67), line);
  }

  static void _drawDriver(Canvas canvas, VehicleDefinition vehicle) {
    final rider =
        vehicle.silhouette == VehicleSilhouette.motorbike ||
        vehicle.silhouette == VehicleSilhouette.atv;
    final head = switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => const Offset(5, -69),
      VehicleSilhouette.atv => const Offset(-1, -65),
      VehicleSilhouette.jeep => const Offset(-20, -76),
      VehicleSilhouette.monsterTruck => const Offset(-3, -70),
      VehicleSilhouette.cargoTruck => const Offset(47, -62),
      VehicleSilhouette.desertRacer => const Offset(9, -61),
      VehicleSilhouette.rover => const Offset(-5, -68),
      VehicleSilhouette.buggy => const Offset(-17, -60),
    };
    final torso = switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => const Offset(-12, -38),
      VehicleSilhouette.atv => const Offset(-11, -37),
      VehicleSilhouette.jeep => const Offset(-19, -43),
      VehicleSilhouette.cargoTruck => const Offset(43, -34),
      VehicleSilhouette.desertRacer => const Offset(2, -34),
      VehicleSilhouette.rover => const Offset(-7, -38),
      VehicleSilhouette.buggy => const Offset(-19, -30),
      VehicleSilhouette.monsterTruck => const Offset(-3, -36),
    };
    final hand = switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => const Offset(52, -35),
      VehicleSilhouette.atv => const Offset(39, -31),
      VehicleSilhouette.cargoTruck => const Offset(62, -27),
      VehicleSilhouette.desertRacer => const Offset(39, -27),
      VehicleSilhouette.jeep => const Offset(22, -36),
      VehicleSilhouette.buggy => const Offset(23, -28),
      _ => const Offset(30, -30),
    };
    final limb = Paint()
      ..color = const Color(0xFF05070C)
      ..strokeWidth = rider ? 5.2 : 4.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(torso.translate(1, -7), hand, limb);
    canvas.drawLine(torso.translate(-5, -2), hand.translate(-9, 3), limb);
    if (rider) {
      canvas.drawLine(torso.translate(-2, 10), const Offset(-28, -2), limb);
      canvas.drawLine(torso.translate(4, 10), const Offset(22, -1), limb);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: torso,
        width: rider ? 29 : 26,
        height: rider ? 36 : 34,
      ),
      Paint()..color = const Color(0xFF263044),
    );
    canvas.drawCircle(head, 15.5, Paint()..color = const Color(0xFF05070C));
    canvas.drawCircle(
      head.translate(0, -1),
      12.8,
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.drawCircle(
      head.translate(6.5, 1.5),
      4.8,
      Paint()..color = const Color(0xFFE7FDFF),
    );
    canvas.drawCircle(
      head.translate(-3, 5),
      3.2,
      Paint()..color = const Color(0xFFFFC08A),
    );
  }

  static void _drawLightsAndBumpers(
    Canvas canvas,
    VehicleDefinition vehicle,
    Paint line,
  ) {
    if (vehicle.silhouette != VehicleSilhouette.motorbike) {
      canvas.drawCircle(
        const Offset(84, -15),
        5.5,
        Paint()..color = const Color(0xFFFFF0B5),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-84, -16, 9, 12),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFC94735),
      );
    }
    final front = switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => (
        const Offset(72, -43),
        const Offset(89, -48),
      ),
      VehicleSilhouette.buggy => (const Offset(72, 0), const Offset(94, -6)),
      VehicleSilhouette.jeep => (const Offset(88, 1), const Offset(105, -2)),
      VehicleSilhouette.cargoTruck => (
        const Offset(90, 1),
        const Offset(111, -1),
      ),
      VehicleSilhouette.rover => (const Offset(76, 3), const Offset(96, 1)),
      _ => (const Offset(72, 0), const Offset(95, -4)),
    };
    final rear = switch (vehicle.silhouette) {
      VehicleSilhouette.cargoTruck => (
        const Offset(-116, 1),
        const Offset(-98, 2),
      ),
      VehicleSilhouette.jeep => (const Offset(-99, 0), const Offset(-80, 0)),
      VehicleSilhouette.motorbike => (
        const Offset(-55, 0),
        const Offset(-39, 0),
      ),
      _ => (const Offset(-88, 2), const Offset(-67, 3)),
    };
    canvas.drawLine(front.$1, front.$2, line);
    canvas.drawLine(rear.$1, rear.$2, line);
  }

  static void _drawSuspension(
    Canvas canvas,
    VehicleDefinition vehicle,
    Offset rearWheel,
    Offset frontWheel,
  ) {
    final line = Paint()
      ..color = const Color(0xFF05070C)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final spring = Paint()
      ..color = const Color(0xFFE0B46C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rearAnchor = switch (vehicle.silhouette) {
      VehicleSilhouette.cargoTruck => const Offset(-52, -8),
      VehicleSilhouette.rover => const Offset(-42, -24),
      VehicleSilhouette.motorbike => const Offset(-24, -8),
      _ => const Offset(-36, -9),
    };
    final frontAnchor = switch (vehicle.silhouette) {
      VehicleSilhouette.cargoTruck => const Offset(48, -7),
      VehicleSilhouette.rover => const Offset(44, -23),
      VehicleSilhouette.motorbike => const Offset(32, -8),
      _ => const Offset(38, -9),
    };
    _arm(canvas, rearAnchor, rearWheel.translate(0, -3), line, spring);
    _arm(canvas, frontAnchor, frontWheel.translate(0, -3), line, spring);
  }

  static void _arm(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint line,
    Paint spring,
  ) {
    canvas.drawLine(a, b, line);
    canvas.drawLine(a.translate(0, 11), b.translate(4, 2), line);
    final path = Path()
      ..moveTo(_lerp(a.dx, b.dx, 0.35), _lerp(a.dy, b.dy, 0.35));
    for (var i = 1; i <= 5; i += 1) {
      final t = 0.35 + i * 0.08;
      path.lineTo(
        _lerp(a.dx, b.dx, t) + (i.isEven ? -4 : 4),
        _lerp(a.dy, b.dy, t),
      );
    }
    canvas.drawPath(path, spring);
  }

  static void _drawWheel(
    Canvas canvas,
    VehicleDefinition vehicle,
    Offset center,
    double radius,
    double spin,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    final tire = Paint()..color = const Color(0xFF030712);
    for (var i = 0; i < 12; i += 1) {
      canvas.save();
      canvas.rotate(i * math.pi / 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, -radius - 4),
            width: radius * 0.38,
            height: 7,
          ),
          const Radius.circular(2),
        ),
        tire,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, radius + 3, tire);
    canvas.drawCircle(
      Offset.zero,
      radius - 4,
      Paint()..color = const Color(0xFF222222),
    );
    canvas.drawCircle(
      Offset.zero,
      radius - 11,
      Paint()..color = vehicle.accent,
    );
    canvas.drawCircle(
      Offset.zero,
      radius - 17,
      Paint()..color = const Color(0xFF1B3651),
    );
    final spoke = Paint()
      ..color = const Color(0xFF07111F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i += 1) {
      final a = i * math.pi / 3;
      canvas.drawLine(
        Offset(math.cos(a) * 4, math.sin(a) * 4),
        Offset(
          math.cos(a) * math.max(10, radius - 13),
          math.sin(a) * math.max(10, radius - 13),
        ),
        spoke,
      );
    }
    canvas.drawCircle(Offset.zero, 6, Paint()..color = const Color(0xFFE7FDFF));
    canvas.restore();
  }

  static void _fillPath(Canvas canvas, Path path, Paint outline, Paint fill) {
    canvas.drawPath(path, outline);
    canvas.drawPath(path, fill);
  }

  static void _window(Canvas canvas, Rect rect, Paint outline, Paint glass) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect.inflate(4), outline);
    canvas.drawRRect(rrect, glass);
  }

  static void _drawRollBar(
    Canvas canvas,
    Offset start,
    Offset peak,
    Offset end,
  ) {
    final bar = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(peak.dx, peak.dy, end.dx, end.dy);
    canvas.drawPath(
      bar,
      Paint()
        ..color = const Color(0xFF05070C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      bar,
      Paint()
        ..color = const Color(0xFF3B4658)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
