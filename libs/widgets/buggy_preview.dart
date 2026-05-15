import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/vehicle_definitions.dart';
import 'vehicle_art.dart';

class BuggyPreview extends StatefulWidget {
  const BuggyPreview({
    this.height = 180,
    this.vehicle = starterBuggy,
    this.animated = true,
    super.key,
  });

  final double height;
  final VehicleDefinition vehicle;
  final bool animated;

  @override
  State<BuggyPreview> createState() => _BuggyPreviewState();
}

class _BuggyPreviewState extends State<BuggyPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BuggyPreviewPainter(
              time: _controller.value,
              vehicle: widget.vehicle,
            ),
          );
        },
      ),
    );
  }
}

class _BuggyPreviewPainter extends CustomPainter {
  const _BuggyPreviewPainter({required this.time, required this.vehicle});

  final double time;
  final VehicleDefinition vehicle;

  @override
  void paint(Canvas canvas, Size size) {
    final bob = math.sin(time * math.pi * 2) * 3.5;
    final center = Offset(size.width * 0.5, size.height * 0.6 + bob);
    final scale = (size.width / 430).clamp(0.7, 1.28).toDouble();

    _drawShowroom(canvas, size);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.rotate(-0.035 + math.sin(time * math.pi * 2) * 0.008);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 58), width: 278, height: 42),
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final roadBase = Paint()
      ..color = const Color(0xFF3B2A22)
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final road = Paint()
      ..color = const Color(0xFFE0B46C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-168, 68), const Offset(170, 48), roadBase);
    canvas.drawLine(const Offset(-168, 68), const Offset(170, 48), road);

    VehicleArt.drawVehicle(
      canvas,
      vehicle: vehicle,
      rearWheel: _rearWheelCenter(),
      frontWheel: _frontWheelCenter(),
      wheelRadius: 33 * vehicle.wheelScale,
      wheelSpin: time * math.pi * 2,
    );

    canvas.restore();
  }

  Offset _rearWheelCenter() => switch (vehicle.silhouette) {
    VehicleSilhouette.jeep => const Offset(-72, 28),
    VehicleSilhouette.motorbike => const Offset(-64, 25),
    VehicleSilhouette.atv => const Offset(-72, 26),
    VehicleSilhouette.monsterTruck => const Offset(-88, 38),
    VehicleSilhouette.cargoTruck => const Offset(-92, 31),
    VehicleSilhouette.desertRacer => const Offset(-88, 25),
    VehicleSilhouette.rover => const Offset(-82, 31),
    VehicleSilhouette.buggy => const Offset(-68, 29),
  };

  Offset _frontWheelCenter() => switch (vehicle.silhouette) {
    VehicleSilhouette.jeep => const Offset(74, 28),
    VehicleSilhouette.motorbike => const Offset(72, 24),
    VehicleSilhouette.atv => const Offset(76, 25),
    VehicleSilhouette.monsterTruck => const Offset(94, 37),
    VehicleSilhouette.cargoTruck => const Offset(94, 31),
    VehicleSilhouette.desertRacer => const Offset(94, 24),
    VehicleSilhouette.rover => const Offset(84, 31),
    VehicleSilhouette.buggy => const Offset(76, 28),
  };

  void _drawShowroom(Canvas canvas, Size size) {
    final floorY = size.height * 0.78;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, floorY),
        width: size.width * 0.82,
        height: size.height * 0.28,
      ),
      Paint()..color = const Color(0x33E0B46C),
    );
    canvas.drawLine(
      Offset(size.width * 0.12, floorY),
      Offset(size.width * 0.88, floorY),
      Paint()
        ..color = const Color(0xAAE0B46C)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BuggyPreviewPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.vehicle != vehicle;
  }
}
