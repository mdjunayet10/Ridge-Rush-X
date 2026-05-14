import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game_state.dart';
import 'terrain_generator.dart';
import 'vehicle_definitions.dart';
import '../widgets/vehicle_art.dart';

class PlayerCar {
  PlayerCar({
    required Vector2 position,
    required this.angle,
    required this.engineLevel,
    required this.tiresLevel,
    required this.suspensionLevel,
    this.stabilityLevel = 1,
    required this.vehicle,
  }) : position = position.clone();

  static const double rideHeight = 56;
  static const double baseWheelRadius = 30;

  static const Offset _baseRearWheelMount = Offset(-55, 26);
  static const Offset _baseFrontWheelMount = Offset(60, 25);
  static const double _contactSlop = 11;
  static const double _compressionTravel = 22;
  static const double _maxUpgradeLevel = 5;

  final int engineLevel;
  final int tiresLevel;
  final int suspensionLevel;
  final int stabilityLevel;
  final VehicleDefinition vehicle;

  final Vector2 position;
  final Vector2 velocity = Vector2.zero();

  double angle;
  double angularVelocity = 0;
  double wheelSpin = 0;
  double upsideDownTime = 0;
  double extremeAngleTime = 0;
  double frontCompression = 0;
  double rearCompression = 0;
  double lastLandingSpeed = 0;

  bool grounded = true;
  bool frontWheelGrounded = true;
  bool rearWheelGrounded = true;
  bool justLanded = false;
  bool justJumped = false;
  Offset _previousCenter = Offset.zero;

  double get speedX => velocity.x;

  double get wheelRadius => baseWheelRadius * vehicle.wheelScale;

  double get _speedTrait =>
      _sharedVehicleTrait(vehicle.speed, min: 0.92, max: 1.10, influence: 0.42);

  double get _gripTrait =>
      _sharedVehicleTrait(vehicle.grip, min: 0.94, max: 1.12, influence: 0.44);

  double get _suspensionTrait => _sharedVehicleTrait(
    vehicle.suspension,
    min: 0.94,
    max: 1.12,
    influence: 0.46,
  );

  double get _stabilityTrait => _sharedVehicleTrait(
    vehicle.stability,
    min: 0.92,
    max: 1.12,
    influence: 0.48,
  );

  double get _massTrait =>
      _sharedVehicleTrait(vehicle.mass, min: 0.92, max: 1.10, influence: 0.34);

  double get _engineEase =>
      ((engineLevel - 1) / (_maxUpgradeLevel - 1)).clamp(0, 1).toDouble();

  double get _tireEase =>
      ((tiresLevel - 1) / (_maxUpgradeLevel - 1)).clamp(0, 1).toDouble();

  double get _suspensionEase =>
      ((suspensionLevel - 1) / (_maxUpgradeLevel - 1)).clamp(0, 1).toDouble();

  double get _stabilityEase =>
      ((stabilityLevel - 1) / (_maxUpgradeLevel - 1)).clamp(0, 1).toDouble();

  Offset get center => Offset(position.x, position.y);

  Offset get previousCenter => _previousCenter;

  Offset get _rearWheelMount => switch (vehicle.silhouette) {
    VehicleSilhouette.jeep => const Offset(-58, 27),
    VehicleSilhouette.motorbike => const Offset(-50, 25),
    VehicleSilhouette.atv => const Offset(-58, 26),
    VehicleSilhouette.monsterTruck => const Offset(-72, 37),
    VehicleSilhouette.cargoTruck => const Offset(-74, 30),
    VehicleSilhouette.desertRacer => const Offset(-70, 24),
    VehicleSilhouette.rover => const Offset(-64, 31),
    VehicleSilhouette.buggy => _baseRearWheelMount,
  };

  Offset get _frontWheelMount => switch (vehicle.silhouette) {
    VehicleSilhouette.jeep => const Offset(62, 27),
    VehicleSilhouette.motorbike => const Offset(58, 23),
    VehicleSilhouette.atv => const Offset(62, 25),
    VehicleSilhouette.monsterTruck => const Offset(78, 36),
    VehicleSilhouette.cargoTruck => const Offset(80, 30),
    VehicleSilhouette.desertRacer => const Offset(78, 23),
    VehicleSilhouette.rover => const Offset(68, 30),
    VehicleSilhouette.buggy => _baseFrontWheelMount,
  };

  Offset get rearWheelCenter =>
      _worldPoint(_wheelDrawMount(_rearWheelMount, rearCompression));

  Offset get frontWheelCenter =>
      _worldPoint(_wheelDrawMount(_frontWheelMount, frontCompression));

  List<Offset> pickupAnchors() {
    return [
      center,
      rearWheelCenter,
      frontWheelCenter,
      _worldPoint(const Offset(-48, -10)),
      _worldPoint(const Offset(0, -30)),
      _worldPoint(const Offset(54, -12)),
      _worldPoint(_driverHeadLocal),
    ];
  }

  List<Offset> ceilingProbePoints() {
    return [
      _worldPoint(const Offset(-58, -18)),
      _worldPoint(const Offset(-28, -38)),
      _worldPoint(const Offset(0, -48)),
      _worldPoint(const Offset(34, -36)),
      _worldPoint(const Offset(62, -16)),
      _worldPoint(_driverHeadLocal),
    ];
  }

  Offset get _driverHeadLocal => switch (vehicle.silhouette) {
    VehicleSilhouette.motorbike => const Offset(6, -64),
    VehicleSilhouette.atv => const Offset(2, -62),
    VehicleSilhouette.jeep => const Offset(6, -58),
    VehicleSilhouette.monsterTruck => const Offset(0, -56),
    VehicleSilhouette.cargoTruck => const Offset(45, -54),
    VehicleSilhouette.desertRacer => const Offset(18, -52),
    VehicleSilhouette.rover => const Offset(0, -58),
    VehicleSilhouette.buggy => const Offset(-4, -58),
  };

  void reset({required double x, required TerrainGenerator terrain}) {
    final slopeAngle = math.atan(terrain.slopeAt(x));
    position
      ..x = x
      ..y = terrain.heightAt(x) - rideHeight;
    velocity.setZero();
    angle = slopeAngle;
    angularVelocity = 0;
    wheelSpin = 0;
    upsideDownTime = 0;
    extremeAngleTime = 0;
    frontCompression = 0.2;
    rearCompression = 0.2;
    lastLandingSpeed = 0;
    grounded = true;
    frontWheelGrounded = true;
    rearWheelGrounded = true;
    justLanded = false;
    justJumped = false;
    _previousCenter = center;
  }

  void reviveAt({required double x, required TerrainGenerator terrain}) {
    final safeX = math.max(90.0, x);
    final slopeAngle = math.atan(terrain.slopeAt(safeX));
    position
      ..x = safeX
      ..y = terrain.heightAt(safeX) - rideHeight - 8;
    velocity
      ..x = math.max(170.0, velocity.x.abs() * 0.35)
      ..y = -70;
    angle = slopeAngle.clamp(-0.28, 0.28).toDouble();
    angularVelocity = 0;
    upsideDownTime = 0;
    extremeAngleTime = 0;
    frontCompression = 0.18;
    rearCompression = 0.18;
    lastLandingSpeed = 0;
    grounded = true;
    frontWheelGrounded = true;
    rearWheelGrounded = true;
    justLanded = false;
    justJumped = false;
    _previousCenter = center;
  }

  void update({
    required double dt,
    required TerrainGenerator terrain,
    required ControlInput controls,
    double powerScale = 1,
  }) {
    final safeDt = dt.clamp(0.0, 1 / 30).toDouble();
    final wasGrounded = grounded;
    justLanded = false;
    justJumped = false;
    lastLandingSpeed = 0;
    _previousCenter = center;

    final fuelPower = powerScale.clamp(0, 1).toDouble();
    final gas = controls.gas ? fuelPower : 0.0;
    final brake = controls.brake ? 1.0 : 0.0;

    // Lean controls are treated as optional helpers only. The main vehicle
    // control is now gas/brake, matching the simple reference feel.
    final helperLean =
        (controls.leanForward ? 1.0 : 0.0) - (controls.leanBack ? 1.0 : 0.0);

    final roadSlope = terrain.slopeAt(position.x);
    final roadAngle = math.atan(roadSlope).clamp(-0.78, 0.78).toDouble();
    final surfaceGrip = terrain.gripMultiplierAt(position.x);
    final surfaceDrag = terrain.rollingDragAt(position.x);
    final surfacePitchKick = terrain.pitchKickAt(position.x);

    final engineEase = _engineEase;
    final tireEase = _tireEase;
    final suspensionEase = _suspensionEase;
    final stabilityEase = _stabilityEase;
    final speedTrait = _speedTrait;
    final gripTrait = _gripTrait;
    final suspensionTrait = _suspensionTrait;
    final stabilityTrait = _stabilityTrait;
    final safeMass = _massTrait;
    final massDrag = 1 / math.sqrt(safeMass);

    // Shared reference tuning: a springy rear-drive toy car for every vehicle.
    final enginePower =
        (640 + engineLevel * 92 + engineEase * 115) * speedTrait * massDrag;
    final reversePower = enginePower * 0.46;
    final maxForwardSpeed =
        (560 + engineLevel * 48 + engineEase * 68) * speedTrait;
    final traction = (1.12 + tiresLevel * 0.12 + tireEase * 0.16) * gripTrait;
    final suspensionStrength =
        (24.5 + suspensionLevel * 3.9 + suspensionEase * 3.8) * suspensionTrait;
    final suspensionBounce =
        (0.16 + suspensionLevel * 0.014 + suspensionEase * 0.024) *
        suspensionTrait;

    if (grounded) {
      final effectiveTraction = traction * surfaceGrip;
      final driveContact = rearWheelGrounded
          ? 1.0
          : frontWheelGrounded
          ? 0.68
          : 0.0;

      if (gas > 0) {
        velocity.x +=
            gas * enginePower * effectiveTraction * driveContact * safeDt;
      }

      if (brake > 0) {
        if (velocity.x > 34) {
          velocity.x -=
              brake *
              enginePower *
              (1.04 + (1 - surfaceGrip) * 0.20) *
              traction *
              safeDt;
        } else {
          // Low-speed brake becomes a gentle reverse. This keeps recovery easy
          // without turning the car into an instant backward rocket.
          velocity.x -=
              brake * reversePower * (0.92 + tireEase * 0.16) * safeDt;
        }
      }

      velocity.x *= math.pow(surfaceDrag, safeDt * 60).toDouble();

      // In Flutter coordinates, an uphill to the right has a negative slope.
      // This gives hills weight while upgrades reduce uphill bogging.
      final slopeDragRelief = roadSlope < 0
          ? 1 - (engineEase * 0.30 + tireEase * 0.22)
          : 1.0;
      velocity.x += roadSlope * 152 * slopeDragRelief * safeDt;

      if (!controls.gas && !controls.brake) {
        velocity.x *= math.pow(0.988, safeDt * 60).toDouble();
      }

      // HCR-style contact behavior: when both wheels are planted, terrain and
      // suspension own the body angle. Gas/brake pitch becomes strong only
      // with one wheel touching or in the air.
      final relativeGroundAngle = _normalizeAngle(angle - roadAngle);
      final speedFactor = (velocity.x.abs() / 245).clamp(0.42, 2.08).toDouble();
      final noseUpRoom = ((relativeGroundAngle + 0.72) / 0.72)
          .clamp(0.0, 1.0)
          .toDouble();
      final noseDownRoom = ((0.78 - relativeGroundAngle) / 0.78)
          .clamp(0.0, 1.0)
          .toDouble();
      final twoWheelContact = rearWheelGrounded && frontWheelGrounded;
      final oneWheelContact = rearWheelGrounded != frontWheelGrounded;
      final gasPitchAuthority = twoWheelContact
          ? 0.18
          : oneWheelContact
          ? 0.72
          : 0.48;
      final brakePitchAuthority = twoWheelContact
          ? 0.26
          : oneWheelContact
          ? 0.78
          : 0.55;
      final gasLift =
          gas *
          (1.28 - suspensionEase * 0.10 - stabilityEase * 0.18) *
          noseUpRoom *
          gasPitchAuthority;
      final brakeDip =
          brake *
          (2.80 - suspensionEase * 0.14 - stabilityEase * 0.22) *
          noseDownRoom *
          brakePitchAuthority;
      angularVelocity += (-gasLift + brakeDip) * speedFactor * safeDt;

      angularVelocity += helperLean * 0.80 * safeDt;
      angularVelocity += surfacePitchKick * (1.15 + tireEase * 0.18) * safeDt;

      if (relativeGroundAngle < -0.42) {
        angularVelocity +=
            (-0.42 - relativeGroundAngle) *
            (4.6 + stabilityEase * 1.4) *
            safeDt;
      } else if (relativeGroundAngle > 0.50) {
        angularVelocity -=
            (relativeGroundAngle - 0.50) * (4.2 + stabilityEase * 1.3) * safeDt;
      }
    } else {
      // Air control follows the reference: gas = nose up, brake = nose down.
      final airResponse =
          (1.08 + suspensionEase * 0.10 + stabilityEase * 0.16) / safeMass;
      angularVelocity +=
          (-gas * 3.15 + brake * 4.10 + helperLean * 0.95) *
          airResponse *
          safeDt;

      // A tiny self-correction helps the car feel recoverable, but it does not
      // take control away from the player.
      final airTargetAngle = (-0.04 + roadAngle * 0.08)
          .clamp(-0.18, 0.12)
          .toDouble();
      final relativeAirAngle = _normalizeAngle(angle - airTargetAngle);
      angularVelocity +=
          _normalizeAngle(airTargetAngle - angle) *
          (0.22 + stabilityTrait * 0.07 + stabilityEase * 0.16) *
          safeDt;

      if (relativeAirAngle < -1.20) {
        angularVelocity +=
            (-1.20 - relativeAirAngle) *
            (1.25 + stabilityTrait * 0.28 + stabilityEase * 0.36) *
            safeDt;
      }
      if (relativeAirAngle > 1.38) {
        angularVelocity -=
            (relativeAirAngle - 1.38) *
            (1.20 + stabilityTrait * 0.28 + stabilityEase * 0.36) *
            safeDt;
      }

      velocity.x *= math
          .pow(0.9965 - tireEase * 0.0008, safeDt * 60)
          .toDouble();
      angularVelocity *= math
          .pow(
            0.964 - suspensionEase * 0.004 - stabilityEase * 0.006,
            safeDt * 60,
          )
          .toDouble();
    }

    velocity.x = velocity.x
        .clamp(-220 - tireEase * 35, maxForwardSpeed)
        .toDouble();
    velocity.y += (1265 + safeMass * 82) * safeDt;
    velocity.y = velocity.y.clamp(-610, 1220).toDouble();

    position
      ..x += velocity.x * safeDt
      ..y += velocity.y * safeDt;

    if (position.x < 80) {
      position.x = 80;
      velocity.x = math.max(0.0, velocity.x);
    }

    final rearContact = _sampleWheel(_rearWheelMount, terrain);
    final frontContact = _sampleWheel(_frontWheelMount, terrain);

    rearWheelGrounded = rearContact.isGrounded;
    frontWheelGrounded = frontContact.isGrounded;
    grounded = rearWheelGrounded || frontWheelGrounded;

    _resolveWheelContacts(
      dt: safeDt,
      terrain: terrain,
      rearContact: rearContact,
      frontContact: frontContact,
      suspensionStrength: suspensionStrength,
      suspensionBounce: suspensionBounce,
    );

    if (wasGrounded && !grounded && velocity.x.abs() > 125) {
      justJumped = true;
      final takeoffPop =
          (velocity.x.abs() / 560).clamp(0.0, 1.0).toDouble() *
          (controls.gas ? 18.0 : 10.0);
      velocity.y -= takeoffPop;
      angularVelocity -= gas * 0.025;
    }
    if (!wasGrounded && grounded) {
      justLanded = true;
    }

    if (grounded && angle.abs() > 0.72) {
      angularVelocity +=
          (angle.isNegative ? 1 : -1) * angle.abs() * 0.46 * safeDt;
    }
    if (grounded && angle.abs() > 1.08) {
      extremeAngleTime += safeDt;
      angularVelocity += (angle.isNegative ? 1 : -1) * 0.62 * safeDt;
    } else {
      extremeAngleTime = math.max(0.0, extremeAngleTime - safeDt * 2.3);
    }

    final maxAngular =
        (grounded ? 6.25 : 7.75) /
        (stabilityTrait + stabilityEase * 0.24).clamp(0.90, 1.36);
    angularVelocity = angularVelocity.clamp(-maxAngular, maxAngular).toDouble();

    final damping = grounded ? 0.875 : 0.966;
    angularVelocity *= math.pow(damping, safeDt * 60).toDouble();
    angle = _normalizeAngle(angle + angularVelocity * safeDt);

    if (grounded && frontWheelGrounded && rearWheelGrounded) {
      final target = math
          .atan2(
            terrain.heightAt(frontWheelCenter.dx) -
                terrain.heightAt(rearWheelCenter.dx),
            frontWheelCenter.dx - rearWheelCenter.dx,
          )
          .clamp(-0.74, 0.74)
          .toDouble();
      final alignT = (1 - math.exp(-(8.8 + stabilityEase * 3.0) * safeDt))
          .clamp(0.0, 0.30)
          .toDouble();
      angle = _normalizeAngle(angle + _normalizeAngle(target - angle) * alignT);
      angularVelocity *= math.pow(0.72, safeDt * 60).toDouble();
    }

    wheelSpin += velocity.x * safeDt / wheelRadius;

    if (math.cos(angle) < -0.20) {
      upsideDownTime += grounded ? safeDt : safeDt * 0.55;
    } else {
      upsideDownTime = math.max(0.0, upsideDownTime - safeDt * 2.5);
    }
  }

  bool isCrashed(TerrainGenerator terrain) {
    final roadY = terrain.heightAt(position.x);
    if (upsideDownTime > 1.85 + _suspensionEase * 0.35 ||
        extremeAngleTime > 3.10 + _suspensionEase * 0.45 ||
        position.y > roadY + 245) {
      return true;
    }

    final roof = _worldPoint(const Offset(2, -43));
    final hood = _worldPoint(const Offset(58, -17));
    final tail = _worldPoint(const Offset(-58, -13));
    final head = _worldPoint(_driverHeadLocal);
    final impactAllowance = _suspensionEase * 72;
    final hardImpact =
        lastLandingSpeed > 330 + impactAllowance ||
        (velocity.y > 360 + impactAllowance && !grounded);
    final nearFlip = upsideDownTime > 0.35 || angle.abs() > 1.32;

    final roofHit = roof.dy > terrain.heightAt(roof.dx) - 5;
    final hoodHit = hood.dy > terrain.heightAt(hood.dx) + 3;
    final tailHit = tail.dy > terrain.heightAt(tail.dx) + 3;
    final headHit = head.dy > terrain.heightAt(head.dx) - 8;

    bool hitsCeiling(Offset point, double allowance) {
      final ceilingY = terrain.ceilingHeightAt(point.dx);
      return ceilingY != null && point.dy <= ceilingY + allowance;
    }

    final roofCeilingHit = hitsCeiling(roof, 5);
    final headCeilingHit = hitsCeiling(head, 10);
    final noseCeilingHit = hitsCeiling(hood, 4);

    return (headHit && nearFlip && (hardImpact || angle.abs() > 1.45)) ||
        (roofHit && nearFlip && (hardImpact || angle.abs() > 1.45)) ||
        ((hoodHit || tailHit) && hardImpact && angle.abs() > 1.18) ||
        headCeilingHit ||
        (roofCeilingHit && (velocity.y < -80 || angle.abs() > 0.38)) ||
        (noseCeilingHit && velocity.y < -120);
  }

  void render(Canvas canvas) {
    _drawShadow(canvas);

    canvas.save();
    canvas.translate(position.x, position.y);
    canvas.rotate(angle);

    VehicleArt.drawVehicle(
      canvas,
      vehicle: vehicle,
      rearWheel: _wheelDrawMount(_rearWheelMount, rearCompression),
      frontWheel: _wheelDrawMount(_frontWheelMount, frontCompression),
      wheelRadius: wheelRadius,
      wheelSpin: wheelSpin,
    );

    canvas.restore();
  }

  void _resolveWheelContacts({
    required double dt,
    required TerrainGenerator terrain,
    required _WheelContact rearContact,
    required _WheelContact frontContact,
    required double suspensionStrength,
    required double suspensionBounce,
  }) {
    final contacts = <_WheelContact>[
      if (rearWheelGrounded) rearContact,
      if (frontWheelGrounded) frontContact,
    ];

    if (contacts.isEmpty) {
      rearCompression = _approach(rearCompression, 0, 8.5, dt);
      frontCompression = _approach(frontCompression, 0, 8.5, dt);
      return;
    }

    final maxPenetration = contacts.fold<double>(
      0,
      (value, contact) => math.max(value, contact.penetration),
    );

    if (maxPenetration > 0) {
      // Stronger but capped correction keeps the wheels visually on the road.
      position.y -= maxPenetration.clamp(0, 32).toDouble() * 0.88;
    }

    var roadVelocityY = 0.0;
    for (final contact in contacts) {
      roadVelocityY += terrain.slopeAt(contact.x) * velocity.x;
    }
    roadVelocityY /= contacts.length;

    if (velocity.y > roadVelocityY) {
      final impactSpeed = velocity.y - roadVelocityY;
      final absorbedImpact = impactSpeed / (1 + _suspensionEase * 0.48);
      lastLandingSpeed = math.max(lastLandingSpeed, absorbedImpact);

      // The reference car lands like a toy with springs: enough bounce to feel
      // alive, but not so much that every landing becomes a trampoline.
      final bounce = (impactSpeed * suspensionBounce).clamp(0, 78).toDouble();
      velocity.y = roadVelocityY - bounce;
    } else {
      velocity.y = _lerp(
        velocity.y,
        roadVelocityY,
        0.24 + suspensionLevel * 0.022 + _suspensionEase * 0.08,
      );
    }

    final rearTarget = rearWheelGrounded
        ? ((rearContact.penetration + _contactSlop) / 35).clamp(0, 1).toDouble()
        : 0.0;
    final frontTarget = frontWheelGrounded
        ? ((frontContact.penetration + _contactSlop) / 35)
              .clamp(0, 1)
              .toDouble()
        : 0.0;

    rearCompression = _approach(rearCompression, rearTarget, 19, dt);
    frontCompression = _approach(frontCompression, frontTarget, 19, dt);

    if (rearWheelGrounded && frontWheelGrounded) {
      final targetAngle = math.atan2(
        frontContact.roadY - rearContact.roadY,
        frontContact.x - rearContact.x,
      );
      final angleError = _normalizeAngle(targetAngle - angle);

      // Suspension now has real authority, so the body follows the wheels and
      // the motion reads as springy instead of a heavy rigid block.
      angularVelocity +=
          angleError *
          suspensionStrength *
          _stabilityTrait *
          (0.28 + _stabilityEase * 0.10) *
          dt;

      // Compression difference gives natural bobbing/tilting over bumps.
      angularVelocity += (frontCompression - rearCompression) * 0.72 * dt;
    } else if (rearWheelGrounded) {
      // Rear-only contact pushes the tail up, dipping the nose for recovery.
      angularVelocity +=
          (1.05 + rearCompression * 1.28 + velocity.x.abs() / 680) * dt;
    } else if (frontWheelGrounded) {
      // Front-only contact pushes the nose up, helping stop harsh nose-dives.
      angularVelocity -=
          (1.05 + frontCompression * 1.24 + velocity.x.abs() / 720) * dt;
    }
  }

  _WheelContact _sampleWheel(Offset localMount, TerrainGenerator terrain) {
    final wheel = _worldPoint(localMount);
    final roadY = terrain.heightAt(wheel.dx);
    final penetration = wheel.dy + wheelRadius - roadY;
    final roadVelocityY = terrain.slopeAt(wheel.dx) * velocity.x;

    // Looser contact slop makes pickups/landings match what the player sees:
    // if a big tire visually touches the road, the physics should agree.
    final movingTowardRoad = velocity.y >= roadVelocityY - 420;

    return _WheelContact(
      x: wheel.dx,
      roadY: roadY,
      penetration: penetration,
      isGrounded: penetration >= -_contactSlop && movingTowardRoad,
    );
  }

  Offset _worldPoint(Offset local) {
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Offset(
      position.x + local.dx * cosA - local.dy * sinA,
      position.y + local.dx * sinA + local.dy * cosA,
    );
  }

  Offset _wheelDrawMount(Offset mount, double compression) {
    return Offset(mount.dx, mount.dy - compression * _compressionTravel);
  }

  void _drawShadow(Canvas canvas) {
    final shadowPaint = Paint()..color = const Color(0x55000000);
    final lift = grounded
        ? 0.0
        : (velocity.y.abs() * 0.01).clamp(4, 24).toDouble();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(position.x, position.y + 47 + lift),
        width: grounded ? 160 : 126,
        height: grounded ? 25 : 16,
      ),
      shadowPaint,
    );
  }

  static double _normalizeAngle(double value) {
    var angle = value;
    while (angle > math.pi) {
      angle -= math.pi * 2;
    }
    while (angle < -math.pi) {
      angle += math.pi * 2;
    }
    return angle;
  }

  static double _approach(
    double current,
    double target,
    double sharpness,
    double dt,
  ) {
    final t = 1 - math.exp(-sharpness * dt);
    return _lerp(current, target, t);
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }

  static double _sharedVehicleTrait(
    double raw, {
    required double min,
    required double max,
    required double influence,
  }) {
    return (1 + (raw - 1) * influence).clamp(min, max).toDouble();
  }
}

class _WheelContact {
  const _WheelContact({
    required this.x,
    required this.roadY,
    required this.penetration,
    required this.isGrounded,
  });

  final double x;
  final double roadY;
  final double penetration;
  final bool isGrounded;
}
