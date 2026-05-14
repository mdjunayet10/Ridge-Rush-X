import 'dart:async';
import 'dart:math' as math;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/save_service.dart';
import '../services/sfx_service.dart';
import 'collectibles.dart';
import 'game_particle.dart';
import 'game_state.dart';
import 'player_car.dart';
import 'stage_definitions.dart';
import 'terrain_generator.dart';

enum _CoinPattern {
  roadLine,
  lowArc,
  fuelCluster,
  rampReward,
  safeTrail,
  riskyRidge,
  bonusPocket,
}

class HillRiderGame extends FlameGame with KeyboardEvents {
  HillRiderGame({required this.saveService, required this.sfxService})
    : stage = saveService.selectedStage,
      terrain = TerrainGenerator(stage: saveService.selectedStage),
      hud = ValueNotifier<GameSnapshot>(
        GameSnapshot.initial(
          totalCoins: saveService.totalCoins,
          totalGems: saveService.totalGems,
          bestDistanceMeters: saveService.stageBestDistance(
            saveService.selectedStage.id,
          ),
        ),
      ) {
    final selectedVehicle = saveService.selectedVehicle;
    _fuelTankLevel = saveService.upgradeLevel('fuel_tank');
    _fuelCapacity = _fuelCapacityForLevel(_fuelTankLevel);
    _fuel = _fuelCapacity;
    car = PlayerCar(
      position: Vector2(_startX, terrain.heightAt(_startX)),
      angle: math.atan(terrain.slopeAt(_startX)),
      engineLevel: saveService.upgradeLevel('engine'),
      tiresLevel: saveService.upgradeLevel('tires'),
      suspensionLevel: saveService.upgradeLevel('suspension'),
      stabilityLevel: saveService.upgradeLevel('stability'),
      vehicle: selectedVehicle,
    );
  }

  static const double _startX = 140;
  static const double _pixelsPerMeter = 10;
  static const double _emptyFuelGraceSeconds = 1.15;
  static const double _maxFuelCoastSeconds = 3.9;

  static double _fuelCapacityForLevel(int level) {
    final safeLevel = level.clamp(1, SaveService.maxUpgradeLevel).toInt();
    return 25.0 + safeLevel * 5.0 + _upgradeEase(safeLevel) * 4.0;
  }

  static double _fuelPowerScale(double fuelFraction) {
    return fuelFraction > 0 ? 1 : 0;
  }

  static double _upgradeEase(int level) =>
      ((level - 1) / (SaveService.maxUpgradeLevel - 1)).clamp(0, 1).toDouble();

  final SaveService saveService;
  final SfxService sfxService;
  final StageDefinition stage;
  final TerrainGenerator terrain;
  final ValueNotifier<GameSnapshot> hud;

  late final PlayerCar car;
  late final double _fuelCapacity;
  late final int _fuelTankLevel;

  final List<Collectible> _collectibles = [];
  final List<Collectible> _collectiblePool = [];
  final List<GameParticle> _particles = [];
  final List<GameParticle> _particlePool = [];
  final Set<RiderControl> _activeControls = {};
  final math.Random _random = math.Random(42);

  RiderPhase _phase = RiderPhase.running;
  double _fuel = 1;
  double _outOfFuelTime = 0;
  double _distanceMeters = 0;
  int _coinsThisRun = 0;
  int _gemsThisRun = 0;
  int _nextCollectibleId = 0;
  double _nextCollectibleX = 520;
  double _cameraX = 0;
  double _cameraY = 0;
  double _cameraZoom = 1;
  double _cameraShake = 0;
  double _time = 0;
  double _hudTick = 0;
  double _smoothedFps = 60;
  double _dustTick = 0;
  double _speedStreakTick = 0;
  double _rpmFraction = 0;
  double _boostFraction = 0;
  String _gameOverReason = '';
  bool _cameraReady = false;
  bool _rewardsBanked = false;
  bool _continuedThisRun = false;
  final Set<int> _claimedDistanceRewardMeters = <int>{};

  String get _destinationName => switch (stage.id) {
    'broken_bridge' => 'Bridge Camp',
    'high_dunes' => 'Dune Tower',
    'rocky_peaks' => 'Rocky Peak Gate',
    'storm_canyon' => 'Storm Relay Tower',
    _ => 'Canyon Gate',
  };

  double get _stageDifficulty {
    final index = stageDefinitions.indexWhere((item) => item.id == stage.id);
    return index < 0
        ? 0.0
        : (index / math.max(1, stageDefinitions.length - 1))
              .clamp(0, 1)
              .toDouble();
  }

  int get _nextCheckpointMeters {
    final checkpoints = {
      ...stage.levels.map((level) => level.endMeters),
      stage.goalMeters,
    }.toList()..sort();
    for (final checkpoint in checkpoints) {
      if (_distanceMeters < checkpoint) {
        return checkpoint;
      }
    }
    return stage.goalMeters;
  }

  ControlInput get controls => ControlInput(
    gas: _activeControls.contains(RiderControl.gas),
    brake: _activeControls.contains(RiderControl.brake),
    leanBack: _activeControls.contains(RiderControl.leanBack),
    leanForward: _activeControls.contains(RiderControl.leanForward),
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    restart();
  }

  void setControl(RiderControl control, bool pressed) {
    if (pressed) {
      _activeControls.add(control);
    } else {
      _activeControls.remove(control);
    }
  }

  void restart() {
    _activeControls.clear();
    _phase = RiderPhase.running;
    _fuel = _fuelCapacity;
    _outOfFuelTime = 0;
    _distanceMeters = 0;
    _coinsThisRun = 0;
    _gemsThisRun = 0;
    _rewardsBanked = false;
    _continuedThisRun = false;
    _nextCollectibleId = 0;
    _nextCollectibleX = 520;
    _time = 0;
    _hudTick = 0;
    _gameOverReason = '';
    _claimedDistanceRewardMeters.clear();
    _releaseAllCollectibles();
    car.reset(x: _startX, terrain: terrain);
    _ensureCollectiblesAhead();
    _releaseAllParticles();
    _dustTick = 0;
    _speedStreakTick = 0;
    _rpmFraction = 0;
    _boostFraction = 0;
    _cameraShake = 0;
    _cameraZoom = 1;
    _cameraReady = false;
    _updateCamera(1, force: true);
    _publishHud();
  }

  Future<void> retryRun() async {
    if (_phase != RiderPhase.running && !_rewardsBanked) {
      await _bankRunProgress();
    }
    restart();
  }

  Future<bool> continueWithGem() async {
    if (!_canContinueWithGem) {
      return false;
    }

    var paid = false;
    if (saveService.totalGems > 0) {
      paid = await saveService.spendGems(1);
    } else if (_gemsThisRun > 0) {
      _gemsThisRun -= 1;
      paid = true;
    }

    if (!paid) {
      _publishHud();
      return false;
    }

    _continuedThisRun = true;
    _phase = RiderPhase.running;
    _gameOverReason = '';
    _fuel = _fuelCapacity;
    _outOfFuelTime = 0;
    _activeControls.clear();
    car.reviveAt(x: math.max(_startX, car.position.x - 130), terrain: terrain);
    _cameraShake = math.max(_cameraShake, 1.2);
    _spawnGemSparkle(car.center.translate(0, -52));
    _publishHud();
    return true;
  }

  Future<void> quitToMainMenu() async {
    _activeControls.clear();
    if (!_rewardsBanked) {
      await _bankRunProgress();
    }
    _publishHud();
  }

  @override
  void onRemove() {
    if (!_rewardsBanked &&
        (_coinsThisRun > 0 || _gemsThisRun > 0 || _distanceMeters > 1)) {
      unawaited(_bankRunProgress());
    }
    hud.dispose();
    super.onRemove();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    _syncKeyboardControl(
      RiderControl.gas,
      keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
          keysPressed.contains(LogicalKeyboardKey.keyD),
    );
    _syncKeyboardControl(
      RiderControl.brake,
      keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
          keysPressed.contains(LogicalKeyboardKey.keyA),
    );
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);

    final safeDt = dt.clamp(0, 1 / 20).toDouble();
    final instantFps = safeDt <= 0 ? 60.0 : 1 / safeDt;
    _smoothedFps = _lerp(
      _smoothedFps,
      instantFps.clamp(1, 120).toDouble(),
      0.04,
    );
    _time += safeDt;

    if (_phase != RiderPhase.running) {
      _updateParticles(safeDt);
      _updateCamera(safeDt);
      return;
    }

    final currentControls = controls;
    final fuelFraction = (_fuel / _fuelCapacity).clamp(0, 1).toDouble();
    final powerScale = _fuelPowerScale(fuelFraction);
    var remainingCarTime = safeDt;
    while (remainingCarTime > 0) {
      final step = math.min(remainingCarTime, 1 / 45);
      car.update(
        dt: step,
        terrain: terrain,
        controls: currentControls,
        powerScale: powerScale,
      );
      remainingCarTime -= step;
    }
    if ((currentControls.gas || currentControls.brake) && car.grounded) {
      final load = currentControls.gas ? powerScale : 0.55;
      sfxService.playEngineTick(
        throttle: load,
        speedFraction: (car.speedX.abs() / 640).clamp(0, 1).toDouble(),
      );
    }
    if (currentControls.brake && car.grounded && car.speedX.abs() > 120) {
      sfxService.playSkid();
    }
    if (car.justJumped) {
      sfxService.play(SfxCue.jump, volume: 0.34);
      _spawnDustBurst(car.rearWheelCenter, 5, 0.75);
    }
    if (car.justLanded) {
      final impact = car.lastLandingSpeed;
      if (impact > 85) {
        sfxService.play(
          SfxCue.landing,
          volume: (0.18 + impact / 900).clamp(0.18, 0.5).toDouble(),
        );
      }
      if (impact > 180) {
        _cameraShake = math.max(_cameraShake, (impact / 150).clamp(0.8, 3.2));
      }
      _spawnLandingPuff(impact);
    }
    _spawnDrivingDust(currentControls, safeDt);
    _spawnSpeedStreaks(safeDt);

    _distanceMeters = math.max(
      0.0,
      (car.position.x - _startX) / _pixelsPerMeter,
    );
    _awardDistanceMilestones();
    _fuel -= safeDt * (1.0 + _stageDifficulty * 0.03);
    _fuel = math.max(0, _fuel);
    if (_fuel <= 0) {
      _outOfFuelTime += safeDt;
    } else {
      _outOfFuelTime = 0;
    }
    _updateMeters(currentControls, safeDt);

    _ensureCollectiblesAhead();
    _collectNearbyItems();
    _removeOldCollectibles();
    _updateParticles(safeDt);
    _updateCamera(safeDt);
    _cameraShake = math.max(0.0, _cameraShake - safeDt * 7.5);

    if (_distanceMeters >= stage.goalMeters) {
      _completeStage();
    } else if (_shouldEndOutOfFuel()) {
      _endRun('Out of Fuel');
    } else if (_fellIntoDangerPit()) {
      _endRun('Fell Into Canyon');
    } else if (_hitLowCeiling()) {
      _endRun('Hit Low Ceiling');
    } else if (car.isCrashed(terrain)) {
      final reason = car.upsideDownTime > 0.45 || car.extremeAngleTime > 0.55
          ? 'Flipped'
          : 'Crashed';
      _endRun(reason);
    }

    _hudTick += safeDt;
    if (_hudTick > 0.14) {
      _hudTick = 0;
      _publishHud();
    }
  }

  @override
  void render(Canvas canvas) {
    _drawSky(canvas);

    canvas.save();
    final shakeX = math.sin(_time * 78.0) * _cameraShake;
    final shakeY = math.cos(_time * 91.0) * _cameraShake * 0.7;
    canvas.translate(
      size.x * (1 - _cameraZoom) * 0.5,
      size.y * (1 - _cameraZoom) * 0.58,
    );
    canvas.scale(_cameraZoom);
    canvas.translate(-_cameraX + shakeX, -_cameraY + shakeY);

    _drawDistantHills(canvas, _cameraX, _cameraY);
    _drawTerrain(canvas, _cameraX, _cameraY);

    final left = _cameraX - 180;
    final right = _cameraX + size.x + 180;
    final top = _cameraY - 160;
    final bottom = _cameraY + size.y + 180;

    for (final particle in _particles) {
      final position = particle.position;
      if (position.dx >= left &&
          position.dx <= right &&
          position.dy >= top &&
          position.dy <= bottom) {
        particle.render(canvas);
      }
    }

    for (final collectible in _collectibles) {
      final position = collectible.position;
      if (position.dx >= left && position.dx <= right) {
        collectible.render(canvas, _time);
      }
    }

    car.render(canvas);

    canvas.restore();
    super.render(canvas);
  }

  bool _fellIntoDangerPit() {
    if (!terrain.isDangerPit(car.position.x)) {
      return false;
    }
    final pitBottomY = terrain.heightAt(car.position.x);
    return car.position.y > pitBottomY - 105 && car.velocity.y > 100;
  }

  bool _hitLowCeiling() {
    for (final point in car.ceilingProbePoints()) {
      final ceilingY = terrain.ceilingHeightAt(point.dx);
      if (ceilingY != null && point.dy <= ceilingY + 8) {
        return true;
      }
    }
    return false;
  }

  bool _shouldEndOutOfFuel() {
    if (_fuel > 0) {
      return false;
    }
    if (_outOfFuelTime >= _maxFuelCoastSeconds) {
      return true;
    }
    if (_outOfFuelTime < _emptyFuelGraceSeconds) {
      return false;
    }
    return car.grounded &&
        car.velocity.x.abs() < 34 &&
        car.velocity.y.abs() < 80;
  }

  void _updateMeters(ControlInput currentControls, double dt) {
    final throttle = currentControls.gas && _fuel > 0 ? 1.0 : 0.0;
    final speedLoad = (car.speedX.abs() / 560).clamp(0, 1).toDouble();
    final airLoad = car.grounded ? 0.0 : 0.16;
    final targetRpm = (throttle * 0.58 + speedLoad * 0.36 + airLoad)
        .clamp(0, 1)
        .toDouble();
    _rpmFraction += (targetRpm - _rpmFraction) * (1 - math.exp(-9.0 * dt));

    final boostCharge = (car.speedX.abs() - 250).clamp(0, 330).toDouble() / 330;
    final airborneBonus = car.grounded ? 0.0 : 0.22;
    final targetBoost = (boostCharge + airborneBonus).clamp(0, 1).toDouble();
    _boostFraction +=
        (targetBoost - _boostFraction) * (1 - math.exp(-4.6 * dt));
  }

  void _syncKeyboardControl(RiderControl control, bool pressed) {
    if (pressed) {
      _activeControls.add(control);
    } else {
      _activeControls.remove(control);
    }
  }

  void _ensureCollectiblesAhead() {
    final targetX = math.min(
      car.position.x + math.max(size.x, 720.0) * 0.92,
      _startX + stage.goalMeters * _pixelsPerMeter + 220,
    );

    while (_nextCollectibleX < targetX) {
      final clusterIndex = (_nextCollectibleX / 300).floor();
      final seed = _clusterSeed(clusterIndex);
      final hasRamp = terrain.hasJumpApproachBefore(_nextCollectibleX);
      final pattern = _patternForCluster(
        clusterIndex: clusterIndex,
        seed: seed,
        hasRamp: hasRamp,
      );

      switch (pattern) {
        case _CoinPattern.roadLine:
          _addRoadCoins(
            _nextCollectibleX,
            4 + clusterIndex % 3,
            39,
            55 + seed * 22,
          );
        case _CoinPattern.lowArc:
          _addArcCoins(_nextCollectibleX + 14, 5, 39, 66, 24 + seed * 20);
        case _CoinPattern.fuelCluster:
          _addFuelCluster(_nextCollectibleX);
        case _CoinPattern.rampReward:
          _addArcCoins(_nextCollectibleX + 24, 7, 40, 96, 76);
          if (clusterIndex.isEven) {
            _addGemAt(_nextCollectibleX + 168, 150);
          }
        case _CoinPattern.safeTrail:
          _addSafeTrail(_nextCollectibleX, clusterIndex);
        case _CoinPattern.riskyRidge:
          _addRiskyRidge(_nextCollectibleX, clusterIndex);
        case _CoinPattern.bonusPocket:
          _addBonusPocket(_nextCollectibleX, clusterIndex);
      }

      // Keep collectible density independent from Performance Mode so fuel
      // fairness never changes because of a graphics setting.
      _nextCollectibleX += 305 + seed * 95 + (clusterIndex % 3) * 28;
    }
  }

  double _clusterSeed(int clusterIndex) {
    final raw = math.sin(clusterIndex * 12.9898 + 78.233) * 43758.5453123;
    return raw - raw.floorToDouble();
  }

  _CoinPattern _patternForCluster({
    required int clusterIndex,
    required double seed,
    required bool hasRamp,
  }) {
    final fuelStride = _stageDifficulty > 0.65
        ? 6
        : _stageDifficulty > 0.30
        ? 5
        : 5;
    if (clusterIndex % fuelStride == 3) {
      return _CoinPattern.fuelCluster;
    }
    if (hasRamp && seed > 0.34) {
      return _CoinPattern.rampReward;
    }
    if (clusterIndex % 11 == 7) {
      return _CoinPattern.bonusPocket;
    }
    if (seed > 0.78) {
      return _CoinPattern.riskyRidge;
    }
    if (seed > 0.52) {
      return _CoinPattern.safeTrail;
    }
    if (seed > 0.25) {
      return _CoinPattern.lowArc;
    }
    return _CoinPattern.roadLine;
  }

  void _addRoadCoins(double startX, int count, double spacing, double lift) {
    for (var i = 0; i < count; i += 1) {
      final x = startX + i * spacing;
      final slope = terrain.slopeAt(x).abs();
      if (slope > 0.62) {
        continue;
      }
      _addCoinAt(x, terrain.heightAt(x) - lift.clamp(45, 95));
    }
  }

  void _addSafeTrail(double startX, int clusterIndex) {
    final count = 4 + clusterIndex % 2;
    for (var i = 0; i < count; i += 1) {
      final x = startX + i * 48;
      final lift = 50 + math.sin((clusterIndex + i) * 0.8) * 10;
      _addCoinAt(x, terrain.heightAt(x) - lift);
    }
    if (clusterIndex % 3 == 0) {
      final fuelX = startX + count * 44 + 36;
      _addFuelAt(fuelX, 72);
    }
  }

  void _addRiskyRidge(double startX, int clusterIndex) {
    final count = 5 + clusterIndex % 3;
    final baseLift = 108 + (clusterIndex % 2) * 18;
    for (var i = 0; i < count; i += 1) {
      final x = startX + i * 42;
      final t = count == 1 ? 0.0 : i / (count - 1);
      final lift = baseLift + math.sin(t * math.pi) * 58;
      _addCoinAt(x, terrain.heightAt(x) - lift);
    }
    if (clusterIndex % 5 == 2) {
      _addGemAt(startX + 116, baseLift + 92);
    }
  }

  void _addBonusPocket(double startX, int clusterIndex) {
    final centerX = startX + 92;
    final centerY = terrain.heightAt(centerX) - 92;
    for (var i = 0; i < 6; i += 1) {
      final angle = i * math.pi / 3 + clusterIndex * 0.18;
      _addCoinAt(
        centerX + math.cos(angle) * 54,
        centerY + math.sin(angle) * 24,
      );
    }
    if (clusterIndex % 2 == 0) {
      _addGemAt(centerX, 144);
    }
  }

  void _addArcCoins(
    double startX,
    int count,
    double spacing,
    double lift,
    double arcHeight,
  ) {
    for (var i = 0; i < count; i += 1) {
      final x = startX + i * spacing;
      final t = count == 1 ? 0.0 : i / (count - 1);
      final roadLift = lift + math.sin(t * math.pi) * arcHeight;
      final maxLift = arcHeight > 44 ? 178.0 : 100.0;
      _addCoinAt(x, terrain.heightAt(x) - roadLift.clamp(45, maxLift));
    }
  }

  void _addFuelCluster(double startX) {
    final fuelX = startX + 72;
    _addFuelAt(fuelX, 78);
    if (_stageDifficulty > 0.38 && startX % 2 > 1) {
      _addFuelAt(startX + 186, 82);
    }
    _addRoadCoins(startX - 18, 2, 34, 56);
    _addRoadCoins(startX + 122, 3, 34, 62);
  }

  void _addFuelAt(double x, double lift) {
    _spawnCollectible(
      CollectibleType.fuel,
      Offset(x, terrain.heightAt(x) - lift),
    );
  }

  void _addGemAt(double x, double lift) {
    _spawnCollectible(
      CollectibleType.gem,
      Offset(x, terrain.heightAt(x) - lift),
    );
  }

  void _addCoinAt(double x, double y) {
    final roadY = terrain.heightAt(x);
    final safeY = y.clamp(roadY - 185, roadY - 45).toDouble();
    _spawnCollectible(CollectibleType.coin, Offset(x, safeY));
  }

  void _spawnCollectible(CollectibleType type, Offset position) {
    final collectible = _collectiblePool.isNotEmpty
        ? _collectiblePool.removeLast()
        : Collectible(id: 0, type: type, position: position);
    collectible.reset(id: _nextCollectibleId++, type: type, position: position);
    _collectibles.add(collectible);
  }

  void _collectNearbyItems() {
    final anchors = car.pickupAnchors();
    final wheelPickupRadius = car.wheelRadius + 18;
    final bodyPickupRadius = 46.0;

    for (final collectible in _collectibles) {
      if (collectible.collected) {
        continue;
      }

      if (!_isCollectibleTouchingVehicle(
        collectible,
        anchors,
        wheelPickupRadius,
        bodyPickupRadius,
      )) {
        continue;
      }

      collectible.collected = true;
      switch (collectible.type) {
        case CollectibleType.coin:
          _coinsThisRun += 1;
          sfxService.play(SfxCue.coinCollect, volume: 0.5);
          _spawnCoinSparkle(collectible.position);
        case CollectibleType.gem:
          _gemsThisRun += 1;
          sfxService.play(SfxCue.coinCollect, volume: 0.62);
          _spawnGemSparkle(collectible.position);
        case CollectibleType.fuel:
          _fuel = _fuelCapacity;
          _outOfFuelTime = 0;
          sfxService.play(SfxCue.fuelCollect, volume: 0.55);
          _spawnFuelSparkle(collectible.position);
      }
      _publishHud();
    }
  }

  bool _isCollectibleTouchingVehicle(
    Collectible collectible,
    List<Offset> anchors,
    double wheelPickupRadius,
    double bodyPickupRadius,
  ) {
    final itemRadius = collectible.collectRadius;

    // Wheels get their own larger touch area because they are the clearest
    // visual contact points. Body anchors keep coins from missing when the
    // car visually overlaps them but the center point is far away.
    for (var i = 0; i < anchors.length; i += 1) {
      final anchorRadius = i == 1 || i == 2
          ? wheelPickupRadius
          : bodyPickupRadius;
      if ((collectible.position - anchors[i]).distance <=
          itemRadius + anchorRadius) {
        return true;
      }
    }

    final speedPadding = (car.velocity.length * 0.018).clamp(0, 28).toDouble();
    final sweptRadius = itemRadius + bodyPickupRadius + speedPadding;
    return _distanceToSegment(
          collectible.position,
          car.previousCenter,
          car.center,
        ) <=
        sweptRadius;
  }

  double _distanceToSegment(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared <= 0.0001) {
      return (point - a).distance;
    }
    final ap = point - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lengthSquared)
        .clamp(0, 1)
        .toDouble();
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (point - closest).distance;
  }

  void _removeOldCollectibles() {
    for (var i = _collectibles.length - 1; i >= 0; i -= 1) {
      final collectible = _collectibles[i];
      if (collectible.collected ||
          collectible.position.dx < car.position.x - 420) {
        _collectibles.removeAt(i);
        _releaseCollectible(collectible);
      }
    }
  }

  void _releaseCollectible(Collectible collectible) {
    if (_collectiblePool.length < 96) {
      _collectiblePool.add(collectible);
    }
  }

  void _releaseAllCollectibles() {
    for (final collectible in _collectibles) {
      _releaseCollectible(collectible);
    }
    _collectibles.clear();
  }

  void _completeStage() {
    if (_phase != RiderPhase.running) {
      return;
    }
    _phase = RiderPhase.stageComplete;
    _gameOverReason = 'Destination Reached';
    _activeControls.clear();
    sfxService.play(SfxCue.fuelCollect, volume: 0.58);
    _cameraShake = math.max(_cameraShake, 1.6);
    _spawnStageCompleteSparkles();
    _publishHud();
    unawaited(_bankRunProgress().then((_) => _publishHud()));
  }

  void _endRun(String reason) {
    if (_phase != RiderPhase.running) {
      return;
    }
    _phase = RiderPhase.gameOver;
    _gameOverReason = reason;
    _activeControls.clear();
    sfxService.play(SfxCue.crash, volume: 0.6);
    _cameraShake = math.max(_cameraShake, 3.8);
    _spawnCrashParticles();
    _publishHud();
  }

  Future<void> _bankRunProgress() async {
    if (_rewardsBanked) {
      return;
    }
    _rewardsBanked = true;
    await saveService.completeRun(
      distanceMeters: _distanceMeters,
      coinsEarned: _coinsThisRun,
      gemsEarned: _gemsThisRun,
      stageId: stage.id,
      stars: _starsForDistance(),
    );
  }

  int _starsForDistance() {
    var stars = 0;
    for (final goal in stage.starGoals) {
      if (_distanceMeters >= goal) {
        stars += 1;
      }
    }
    return stars;
  }

  void _awardDistanceMilestones() {
    for (var i = 0; i < stage.levels.length; i += 1) {
      final meters = stage.levels[i].endMeters;
      if (meters >= stage.goalMeters || _distanceMeters < meters) {
        continue;
      }
      if (!_claimedDistanceRewardMeters.add(meters)) {
        continue;
      }
      final reward = _checkpointRewardFor(i);
      _coinsThisRun += reward;
      if (i == stage.levels.length - 2 && _stageDifficulty > 0.35) {
        _gemsThisRun += 1;
        _spawnGemSparkle(car.center.translate(0, -72));
      } else {
        _spawnCoinSparkle(car.center.translate(0, -64));
      }
      sfxService.play(SfxCue.coinCollect, volume: 0.42);
      _cameraShake = math.max(_cameraShake, 0.55);
    }
  }

  int _checkpointRewardFor(int levelIndex) {
    final stageBonus = (_stageDifficulty * 12).round();
    return 8 + levelIndex * 4 + stageBonus;
  }

  bool get _canContinueWithGem {
    if (_phase != RiderPhase.gameOver || _continuedThisRun) {
      return false;
    }
    return saveService.totalGems > 0 || _gemsThisRun > 0;
  }

  void _updateCamera(double dt, {bool force = false}) {
    final speedLead = car.velocity.x.clamp(0, 760).toDouble() * 0.4;
    final hillLead =
        terrain.slopeAt(car.position.x + 210).clamp(-0.7, 0.7) * 42;
    final desiredX = math.max(
      0.0,
      car.position.x - size.x * 0.42 + speedLead + hillLead,
    );
    final verticalLook = car.grounded
        ? 0.0
        : car.velocity.y.clamp(-260, 430).toDouble() * 0.065;
    final aheadX = car.position.x + size.x * 0.48 + speedLead * 0.45;
    final aheadRoadY = terrain.heightAt(aheadX) - PlayerCar.rideHeight;
    final focusY = _lerp(
      car.position.y,
      aheadRoadY,
      car.grounded ? 0.16 : 0.08,
    );
    final desiredY = focusY - size.y * 0.61 + verticalLook;
    final desiredZoom =
        (1.0 -
                (car.velocity.x.abs() / 9000).clamp(0, 0.055).toDouble() -
                (car.grounded ? 0 : 0.035))
            .clamp(0.91, 1.02)
            .toDouble();

    if (force || !_cameraReady) {
      _cameraX = desiredX;
      _cameraY = desiredY;
      _cameraZoom = desiredZoom;
      _cameraReady = true;
      return;
    }

    final xSharpness = car.grounded ? 7.8 : 8.6;
    final ySharpness = car.grounded ? 3.8 : 4.8;
    _cameraX += (desiredX - _cameraX) * (1 - math.exp(-xSharpness * dt));
    _cameraY += (desiredY - _cameraY) * (1 - math.exp(-ySharpness * dt));
    _cameraZoom += (desiredZoom - _cameraZoom) * (1 - math.exp(-4.2 * dt));
  }

  void _spawnDrivingDust(ControlInput currentControls, double dt) {
    if (!car.grounded || car.speedX.abs() < 45) {
      return;
    }
    if (!currentControls.gas && !currentControls.brake) {
      return;
    }

    _dustTick -= dt;
    if (_dustTick > 0) {
      return;
    }
    _dustTick = saveService.performanceModeEnabled
        ? (car.speedX.abs() > 260 ? 0.14 : 0.18)
        : (car.speedX.abs() > 260 ? 0.075 : 0.11);

    final source = car.rearWheelGrounded
        ? car.rearWheelCenter
        : car.frontWheelCenter;
    _addParticle(
      kind: ParticleKind.dust,
      position: source.translate(-12 + _random.nextDouble() * 6, 12),
      velocity: Offset(
        -70 - _random.nextDouble() * 55 - car.speedX.abs() * 0.12,
        -18 - _random.nextDouble() * 28,
      ),
      color: const Color(0x995B6A82),
      radius: 6 + _random.nextDouble() * 5,
      life: 0.36 + _random.nextDouble() * 0.18,
      gravity: 70,
    );
  }

  void _spawnDustBurst(Offset origin, int count, double scale) {
    for (var i = 0; i < count; i += 1) {
      _addParticle(
        kind: ParticleKind.dust,
        position: origin.translate(_random.nextDouble() * 12 - 6, 11),
        velocity: Offset(
          -45 - _random.nextDouble() * 85,
          -28 - _random.nextDouble() * 45,
        ),
        color: const Color(0xAA62718E),
        radius: (5 + _random.nextDouble() * 7) * scale,
        life: 0.32 + _random.nextDouble() * 0.24,
        gravity: 85,
      );
    }
  }

  void _spawnLandingPuff(double impact) {
    final count = saveService.performanceModeEnabled
        ? (2 + impact / 170).clamp(2, 5).floor()
        : (4 + impact / 130).clamp(4, 8).floor();
    _spawnDustBurst(car.rearWheelCenter, count, 1.05);
    _spawnDustBurst(car.frontWheelCenter, count ~/ 2, 0.9);
    if (impact > 120) {
      _addParticle(
        kind: ParticleKind.shockwave,
        position: car.center.translate(0, 48),
        velocity: Offset.zero,
        color: const Color(0xAAE0B46C),
        radius: (impact / 36).clamp(5, 13).toDouble(),
        life: 0.36,
      );
    }
    if (impact > 230) {
      _spawnHardLandingSparks(car.frontWheelCenter, impact);
    }
  }

  void _spawnHardLandingSparks(Offset origin, double impact) {
    final count = (impact / 55).clamp(4, 10).floor();
    for (var i = 0; i < count; i += 1) {
      final angle = -math.pi + _random.nextDouble() * math.pi;
      final speed = 90 + _random.nextDouble() * 145;
      _addParticle(
        kind: ParticleKind.sparkle,
        position: origin,
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: const Color(0xFFFFD166),
        radius: 6 + _random.nextDouble() * 4,
        life: 0.28 + _random.nextDouble() * 0.2,
        gravity: 260,
      );
    }
  }

  void _spawnCoinSparkle(Offset origin) {
    for (var i = 0; i < 4; i += 1) {
      final angle = i * math.pi / 4 + _random.nextDouble() * 0.28;
      final speed = 55 + _random.nextDouble() * 70;
      _addParticle(
        kind: ParticleKind.sparkle,
        position: origin,
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: const Color(0xFFFFD166),
        radius: 7 + _random.nextDouble() * 4,
        life: 0.38 + _random.nextDouble() * 0.18,
        gravity: 60,
      );
    }
  }

  void _spawnFuelSparkle(Offset origin) {
    for (var i = 0; i < 6; i += 1) {
      final angle = -math.pi + i * math.pi / 5;
      final speed = 50 + _random.nextDouble() * 65;
      _addParticle(
        kind: ParticleKind.sparkle,
        position: origin,
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: const Color(0xFF8CCF75),
        radius: 8,
        life: 0.42,
        gravity: 55,
      );
    }
  }

  void _spawnGemSparkle(Offset origin) {
    for (var i = 0; i < 7; i += 1) {
      final angle = i * math.pi / 3.5 + _random.nextDouble() * 0.18;
      final speed = 70 + _random.nextDouble() * 85;
      _addParticle(
        kind: ParticleKind.sparkle,
        position: origin,
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: const Color(0xFF7FD9DF),
        radius: 8 + _random.nextDouble() * 5,
        life: 0.46,
        gravity: 80,
      );
    }
  }

  void _spawnStageCompleteSparkles() {
    final origin = car.center.translate(40, -55);
    final burstCount = saveService.performanceModeEnabled ? 10 : 18;
    for (var i = 0; i < burstCount; i += 1) {
      final angle = -math.pi + i * math.pi / 12 + _random.nextDouble() * 0.18;
      final speed = 70 + _random.nextDouble() * 150;
      _addParticle(
        kind: ParticleKind.sparkle,
        position: origin.translate(_random.nextDouble() * 52 - 26, 0),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: i.isEven ? const Color(0xFFFFD166) : const Color(0xFFE7FDFF),
        radius: 8 + _random.nextDouble() * 5,
        life: 0.62 + _random.nextDouble() * 0.32,
        gravity: 75,
      );
    }
  }

  void _spawnCrashParticles() {
    final origin = car.center;
    final crashCount = saveService.performanceModeEnabled ? 8 : 14;
    for (var i = 0; i < crashCount; i += 1) {
      final angle = _random.nextDouble() * math.pi * 2;
      final speed = 85 + _random.nextDouble() * 210;
      _addParticle(
        kind: ParticleKind.crash,
        position: origin.translate(_random.nextDouble() * 28 - 14, -8),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: i.isEven ? const Color(0xFFE0B46C) : const Color(0xFFFFD166),
        radius: 5 + _random.nextDouble() * 6,
        life: 0.56 + _random.nextDouble() * 0.36,
        gravity: 380,
      );
    }
  }

  void _spawnSpeedStreaks(double dt) {
    if (saveService.performanceModeEnabled ||
        !car.grounded ||
        car.speedX < 390) {
      return;
    }

    _speedStreakTick -= dt;
    if (_speedStreakTick > 0) {
      return;
    }
    _speedStreakTick = 0.065;

    _addParticle(
      kind: ParticleKind.speedStreak,
      position: car.center.translate(-80 - _random.nextDouble() * 30, -28),
      velocity: Offset(-95 - _random.nextDouble() * 70, 0),
      color: const Color(0x66E0B46C),
      radius: 2.2 + _random.nextDouble() * 1.6,
      life: 0.22,
    );
  }

  void _updateParticles(double dt) {
    for (final particle in _particles) {
      particle.update(dt);
    }
    for (var i = _particles.length - 1; i >= 0; i -= 1) {
      final particle = _particles[i];
      if (particle.isDead) {
        _particles.removeAt(i);
        _releaseParticle(particle);
      }
    }
  }

  void _addParticle({
    required ParticleKind kind,
    required Offset position,
    required Offset velocity,
    required Color color,
    required double radius,
    required double life,
    double gravity = 0,
  }) {
    final particle = _particlePool.isNotEmpty
        ? _particlePool.removeLast()
        : GameParticle.empty();
    particle.reset(
      kind: kind,
      position: position,
      velocity: velocity,
      color: color,
      radius: radius,
      life: life,
      gravity: gravity,
    );
    _particles.add(particle);
    _trimParticles();
  }

  void _releaseParticle(GameParticle particle) {
    if (_particlePool.length < 48) {
      _particlePool.add(particle);
    }
  }

  void _releaseAllParticles() {
    for (final particle in _particles) {
      _releaseParticle(particle);
    }
    _particles.clear();
  }

  void _trimParticles() {
    final maxParticles = saveService.performanceModeEnabled ? 8 : 26;
    if (_particles.length <= maxParticles) {
      return;
    }
    final removeCount = _particles.length - maxParticles;
    for (var i = 0; i < removeCount; i += 1) {
      _releaseParticle(_particles[i]);
    }
    _particles.removeRange(0, removeCount);
  }

  double _dangerFraction() {
    final fuelDanger = _fuelCapacity <= 0
        ? 0.0
        : ((0.22 - _fuel / _fuelCapacity) / 0.22).clamp(0, 1).toDouble();
    final flipDanger = math.max(
      (car.upsideDownTime / 1.35).clamp(0, 1).toDouble(),
      (car.extremeAngleTime / 1.9).clamp(0, 1).toDouble(),
    );
    return math.max(fuelDanger, flipDanger);
  }

  void _publishHud() {
    final pendingCoins = _rewardsBanked ? 0 : _coinsThisRun;
    final pendingGems = _rewardsBanked ? 0 : _gemsThisRun;
    final currentLevel = stage.levelForDistance(_distanceMeters);
    final currentLevelIndex = stage.levelIndexForDistance(_distanceMeters);
    hud.value = GameSnapshot(
      phase: _phase,
      distanceMeters: _distanceMeters,
      bestDistanceMeters: math.max(
        saveService.stageBestDistance(stage.id),
        _distanceMeters,
      ),
      coinsThisRun: _coinsThisRun,
      gemsThisRun: _gemsThisRun,
      totalCoins: saveService.totalCoins + pendingCoins,
      totalGems: saveService.totalGems + pendingGems,
      fuelFraction: (_fuel / _fuelCapacity).clamp(0, 1).toDouble(),
      speedFraction: (car.velocity.x.abs() / 640).clamp(0, 1).toDouble(),
      rpmFraction: _rpmFraction.clamp(0, 1).toDouble(),
      boostFraction: _boostFraction.clamp(0, 1).toDouble(),
      stageName: stage.name,
      stageGoalMeters: stage.goalMeters,
      destinationName: _destinationName,
      nextCheckpointMeters: _nextCheckpointMeters,
      levelName: currentLevel.name,
      levelDescription: currentLevel.description,
      levelIndex: currentLevelIndex,
      totalLevels: stage.levels.isEmpty ? 1 : stage.levels.length,
      levelStartMeters: currentLevel.startMeters,
      levelEndMeters: currentLevel.endMeters,
      stageStars: math.max(
        saveService.stageStars(stage.id),
        _starsForDistance(),
      ),
      canContinueWithGem: _canContinueWithGem,
      warningText: '',
      dangerFraction: _dangerFraction(),
      performanceText: '',
      gameOverReason: _gameOverReason,
    );
  }

  void _drawSky(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          stage.skyTop,
          stage.skyMid,
          stage.skyBottom,
          const Color(0xFF221A24),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    _drawSkyBody(canvas);
    _drawStageClouds(canvas);
    _drawWeather(canvas);
  }

  void _drawSkyBody(Canvas canvas) {
    final body = _skyBodyForStage;
    final center = Offset(size.x * body.dx, size.y * body.dy);
    canvas.drawCircle(
      center,
      body.glowRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [body.glowColor, body.glowColor.withValues(alpha: 0)],
            ).createShader(
              Rect.fromCircle(center: center, radius: body.glowRadius),
            ),
    );
    canvas.drawCircle(center, body.radius, Paint()..color = body.coreColor);
    if (stage.id == 'storm_canyon') {
      canvas.drawCircle(
        center.translate(12, -8),
        body.radius * 0.82,
        Paint()..color = stage.skyTop.withValues(alpha: 0.62),
      );
    }
  }

  _SkyBody get _skyBodyForStage {
    return switch (stage.id) {
      'broken_bridge' => const _SkyBody(
        dx: 0.80,
        dy: 0.17,
        radius: 30,
        glowRadius: 72,
        coreColor: Color(0xFFE7FDFF),
        glowColor: Color(0x668CFBFF),
      ),
      'high_dunes' => const _SkyBody(
        dx: 0.76,
        dy: 0.19,
        radius: 48,
        glowRadius: 120,
        coreColor: Color(0xFFFFD166),
        glowColor: Color(0xAAFFD166),
      ),
      'rocky_peaks' => const _SkyBody(
        dx: 0.74,
        dy: 0.16,
        radius: 34,
        glowRadius: 86,
        coreColor: Color(0xFFFFE7B0),
        glowColor: Color(0x66F8F0FF),
      ),
      'storm_canyon' => const _SkyBody(
        dx: 0.78,
        dy: 0.16,
        radius: 35,
        glowRadius: 92,
        coreColor: Color(0xFFDBEAFE),
        glowColor: Color(0x667FD9DF),
      ),
      _ => const _SkyBody(
        dx: 0.78,
        dy: 0.18,
        radius: 38,
        glowRadius: 74,
        coreColor: Color(0xFFFFE2A1),
        glowColor: Color(0x99FFF4C7),
      ),
    };
  }

  void _drawStageClouds(Canvas canvas) {
    final count = saveService.performanceModeEnabled ? 4 : 8;
    final cloudPaint = Paint()
      ..color = switch (stage.id) {
        'broken_bridge' => const Color(0x668CFBFF),
        'high_dunes' => const Color(0x44FFE3B0),
        'rocky_peaks' => const Color(0x66F8F0FF),
        'storm_canyon' => const Color(0x77415A77),
        _ => const Color(0x55FFF8E8),
      };
    for (var i = 0; i < count; i += 1) {
      final speed = stage.id == 'storm_canyon' ? 0.075 : 0.045;
      final x =
          (i * 172.0 - _cameraX * speed + math.sin(_time * 0.18 + i) * 12) %
              (size.x + 240) -
          120;
      final y = size.y * (0.13 + (i % 3) * 0.075);
      final width = stage.id == 'storm_canyon'
          ? 160.0
          : stage.id == 'high_dunes'
          ? 138.0
          : 120.0;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: width, height: 28),
        cloudPaint,
      );
      if (stage.id == 'storm_canyon' && i.isEven) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x + 48, y + 10),
            width: 100,
            height: 22,
          ),
          cloudPaint,
        );
      }
    }
  }

  void _drawWeather(Canvas canvas) {
    if (saveService.performanceModeEnabled) {
      return;
    }
    switch (stage.id) {
      case 'broken_bridge':
        _drawRain(canvas, count: 34, color: const Color(0x668CFBFF));
        _drawMistBand(canvas, const Color(0x338CFBFF), size.y * 0.58);
      case 'high_dunes':
        _drawSandWind(canvas);
        _drawMistBand(canvas, const Color(0x22FFD166), size.y * 0.66);
      case 'rocky_peaks':
        _drawSnow(canvas);
      case 'storm_canyon':
        _drawRain(canvas, count: 56, color: const Color(0x887FD9DF));
        _drawLightning(canvas);
      default:
        _drawDustMotes(canvas);
    }
  }

  void _drawRain(Canvas canvas, {required int count, required Color color}) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i += 1) {
      final x = (i * 47.0 + _time * 360 + _cameraX * 0.08) % (size.x + 80) - 40;
      final y = (i * 83.0 + _time * 520) % (size.y + 120) - 60;
      canvas.drawLine(Offset(x, y), Offset(x - 18, y + 44), paint);
    }
  }

  void _drawSnow(Canvas canvas) {
    final paint = Paint()..color = const Color(0xAAE7FDFF);
    for (var i = 0; i < 38; i += 1) {
      final x =
          (i * 61.0 + math.sin(_time * 0.9 + i) * 26 + _cameraX * 0.04) %
              (size.x + 80) -
          40;
      final y = (i * 79.0 + _time * 48) % (size.y + 80) - 40;
      canvas.drawCircle(Offset(x, y), 1.8 + (i % 3) * 0.8, paint);
    }
  }

  void _drawSandWind(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0x55FFD166)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 11; i += 1) {
      final x =
          (i * 148.0 - _time * 86 + _cameraX * 0.06) % (size.x + 180) - 90;
      final y = size.y * (0.42 + (i % 4) * 0.065);
      final path = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x + 42, y - 10, x + 92, y + 3)
        ..quadraticBezierTo(x + 132, y + 14, x + 176, y + 1);
      canvas.drawPath(path, paint);
    }
  }

  void _drawDustMotes(Canvas canvas) {
    final paint = Paint()..color = const Color(0x33FFD166);
    for (var i = 0; i < 14; i += 1) {
      final x = (i * 113.0 + _time * 18 + _cameraX * 0.035) % (size.x + 70);
      final y = size.y * (0.24 + (i % 5) * 0.075);
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 2), paint);
    }
  }

  void _drawMistBand(Canvas canvas, Color color, double y) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 4; i += 1) {
      final x =
          (i * 260.0 - _cameraX * 0.06 + _time * 18) % (size.x + 260) - 130;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y + i * 18), width: 260, height: 42),
        paint,
      );
    }
  }

  void _drawLightning(Canvas canvas) {
    final pulse = math.sin(_time * 1.7);
    if (pulse < 0.92) {
      return;
    }
    final x = size.x * (0.30 + math.sin(_time * 0.31).abs() * 0.36);
    final path = Path()
      ..moveTo(x, size.y * 0.08)
      ..lineTo(x - 28, size.y * 0.22)
      ..lineTo(x + 6, size.y * 0.22)
      ..lineTo(x - 20, size.y * 0.38);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x99E7FDFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDistantHills(Canvas canvas, double cameraX, double cameraY) {
    _drawMountainLayer(
      canvas,
      cameraX: cameraX,
      cameraY: cameraY,
      parallax: 0.1,
      baseY: cameraY + size.y * 0.52,
      height: 170,
      color: stage.hillBack,
      rimColor: stage.accent.withValues(alpha: 0.24),
      phase: 0.5,
    );
    if (!saveService.performanceModeEnabled) {
      _drawMountainLayer(
        canvas,
        cameraX: cameraX,
        cameraY: cameraY,
        parallax: 0.18,
        baseY: cameraY + size.y * 0.63,
        height: 145,
        color: stage.hillMid,
        rimColor: stage.accent.withValues(alpha: 0.2),
        phase: 1.3,
      );
    }
    if (!saveService.performanceModeEnabled) {
      _drawMountainLayer(
        canvas,
        cameraX: cameraX,
        cameraY: cameraY,
        parallax: 0.34,
        baseY: cameraY + size.y * 0.74,
        height: 106,
        color: stage.hillFront,
        rimColor: stage.accent.withValues(alpha: 0.2),
        phase: 2.7,
      );
    }
    if (!saveService.performanceModeEnabled) {
      _drawMistAndOutpostLights(canvas, cameraX, cameraY);
    }
  }

  void _drawTerrain(Canvas canvas, double cameraX, double cameraY) {
    final startX = cameraX - (saveService.performanceModeEnabled ? 80 : 120);
    final endX =
        cameraX + size.x + (saveService.performanceModeEnabled ? 100 : 140);
    final bottomY = cameraY + size.y + 260;
    final points = terrain.sample(
      startX,
      endX,
      step: saveService.performanceModeEnabled ? 96 : 52,
    );

    if (points.isEmpty) {
      return;
    }

    final ground = Path()
      ..moveTo(points.first.dx, bottomY)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points) {
      ground.lineTo(point.dx, point.dy);
    }
    ground
      ..lineTo(points.last.dx, bottomY)
      ..close();

    final soilPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [stage.soilTop, stage.soilBottom],
          ).createShader(
            Rect.fromLTWH(startX, cameraY, endX - startX, bottomY - cameraY),
          );
    final roadShadow = Paint()
      ..color = const Color(0xAA241915)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final packedDirt = Paint()
      ..color = stage.roadLip.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final roadPaint = Paint()
      ..color = const Color(0xFFFFD792)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(ground, soilPaint);
    if (!saveService.performanceModeEnabled) {
      _drawRockMass(canvas, points, bottomY);
    }
    _drawSurfacePatches(canvas, startX, endX);
    _drawBridgeObstacles(canvas, startX, endX);
    _drawLowCeilings(canvas, startX, endX);

    final top = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      top.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(top, roadShadow);
    canvas.drawPath(top, packedDirt);
    canvas.drawPath(top, roadPaint);
    _drawRoadTextureMarks(canvas, points);
    _drawStageGroundDetails(canvas, startX, endX);

    _drawTrailObjects(canvas, startX, endX);

    if (!saveService.performanceModeEnabled) {
      final rockLine = Paint()
        ..color = const Color(0x6645362A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      final rockFill = Paint()..color = const Color(0xFF2D201A);
      for (var x = points.first.dx; x < points.last.dx; x += 168) {
        final y = terrain.heightAt(x) + 38 + math.sin(x * 0.014) * 18;
        canvas.drawLine(Offset(x, y), Offset(x + 56, y + 16), rockLine);
        canvas.drawLine(
          Offset(x + 20, y + 62),
          Offset(x + 88, y + 50 + math.sin(x * 0.021) * 16),
          rockLine,
        );
        canvas.drawCircle(
          Offset(x + 78, y + 32),
          2.4,
          Paint()..color = const Color(0x442F3E63),
        );
        final rock = Path()
          ..moveTo(x + 8, y + 96)
          ..lineTo(x + 30, y + 72)
          ..lineTo(x + 58, y + 103)
          ..close();
        canvas.drawPath(rock, rockFill);
      }
    }
  }

  void _drawStageGroundDetails(Canvas canvas, double startX, double endX) {
    if (saveService.performanceModeEnabled) {
      return;
    }
    switch (stage.id) {
      case 'broken_bridge':
        _drawValleyReeds(canvas, startX, endX);
      case 'high_dunes':
        _drawDesertPlants(canvas, startX, endX);
      case 'rocky_peaks':
        _drawSnowyPines(canvas, startX, endX);
      case 'storm_canyon':
        _drawStormPosts(canvas, startX, endX);
      default:
        _drawCanyonShrubs(canvas, startX, endX);
    }
  }

  void _drawCanyonShrubs(Canvas canvas, double startX, double endX) {
    final paint = Paint()..color = const Color(0xFF75B843);
    final stem = Paint()
      ..color = const Color(0xFF3D5E28)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var x = (startX / 210).floor() * 210.0; x < endX; x += 210) {
      final y = terrain.heightAt(x) + 2;
      canvas.drawLine(Offset(x, y), Offset(x + 4, y - 19), stem);
      canvas.drawCircle(Offset(x - 5, y - 10), 5, paint);
      canvas.drawCircle(Offset(x + 5, y - 15), 5, paint);
    }
  }

  void _drawValleyReeds(Canvas canvas, double startX, double endX) {
    final reed = Paint()
      ..color = const Color(0xAA8CFBFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final flower = Paint()..color = const Color(0xFFE7FDFF);
    for (var x = (startX / 118).floor() * 118.0; x < endX; x += 118) {
      final y = terrain.heightAt(x);
      for (var i = 0; i < 3; i += 1) {
        final dx = i * 8.0 - 7;
        canvas.drawLine(
          Offset(x + dx, y + 4),
          Offset(x + dx + math.sin(x + i) * 4, y - 26 - i * 5),
          reed,
        );
      }
      canvas.drawCircle(Offset(x + 12, y - 26), 2.8, flower);
    }
  }

  void _drawDesertPlants(Canvas canvas, double startX, double endX) {
    final cactus = Paint()
      ..color = const Color(0xFF4F8F44)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final duneGrass = Paint()
      ..color = const Color(0x99FFD166)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = (startX / 260).floor() * 260.0; x < endX; x += 260) {
      final y = terrain.heightAt(x);
      canvas.drawLine(Offset(x, y + 2), Offset(x, y - 42), cactus);
      canvas.drawLine(Offset(x, y - 22), Offset(x - 18, y - 28), cactus);
      canvas.drawLine(Offset(x, y - 31), Offset(x + 18, y - 36), cactus);
      for (var i = 0; i < 5; i += 1) {
        final dx = 44 + i * 9;
        canvas.drawLine(
          Offset(x + dx, y + 4),
          Offset(x + dx + 8, y - 12 - (i % 2) * 4),
          duneGrass,
        );
      }
    }
  }

  void _drawSnowyPines(Canvas canvas, double startX, double endX) {
    final trunk = Paint()
      ..color = const Color(0xFF3A2418)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final pine = Paint()..color = const Color(0xFF2F5B46);
    final snow = Paint()..color = const Color(0xFFE7FDFF);
    for (var x = (startX / 235).floor() * 235.0; x < endX; x += 235) {
      final y = terrain.heightAt(x);
      canvas.drawLine(Offset(x, y), Offset(x, y - 54), trunk);
      for (var i = 0; i < 3; i += 1) {
        final top = y - 70 + i * 18;
        final half = 28 - i * 4;
        final path = Path()
          ..moveTo(x, top)
          ..lineTo(x - half, top + 34)
          ..lineTo(x + half, top + 34)
          ..close();
        canvas.drawPath(path, pine);
        canvas.drawLine(
          Offset(x - half * 0.62, top + 22),
          Offset(x + half * 0.50, top + 18),
          snow..strokeWidth = 3,
        );
      }
    }
  }

  void _drawStormPosts(Canvas canvas, double startX, double endX) {
    final post = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final wire = Paint()
      ..color = const Color(0xAA7FD9DF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final lamp = Paint()..color = const Color(0xFFFFD166);
    Offset? previousTop;
    for (var x = (startX / 300).floor() * 300.0; x < endX; x += 300) {
      final y = terrain.heightAt(x);
      final top = Offset(x, y - 86);
      canvas.drawLine(Offset(x, y + 2), top, post);
      canvas.drawLine(top.translate(-22, 8), top.translate(22, 8), post);
      canvas.drawCircle(top.translate(26, 14), 4, lamp);
      if (previousTop != null) {
        final path = Path()
          ..moveTo(previousTop.dx + 22, previousTop.dy + 9)
          ..quadraticBezierTo(
            (previousTop.dx + x) / 2,
            math.max(previousTop.dy, top.dy) + 38,
            x - 22,
            top.dy + 9,
          );
        canvas.drawPath(path, wire);
      }
      previousTop = top;
    }
  }

  void _drawRoadTextureMarks(Canvas canvas, List<Offset> points) {
    if (saveService.performanceModeEnabled || points.length < 3) {
      return;
    }
    final mark = Paint()
      ..color = const Color(0x553A2418)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 2; i < points.length - 2; i += 3) {
      final point = points[i];
      final next = points[i + 1];
      final slope = ((next.dy - point.dy) / (next.dx - point.dx))
          .clamp(-1.2, 1.2)
          .toDouble();
      final length = 18.0 + slope.abs() * 12.0;
      canvas.drawLine(
        Offset(point.dx - 4, point.dy + 12),
        Offset(point.dx + length, point.dy + 17 + slope * 5),
        mark,
      );
    }
  }

  void _drawSurfacePatches(Canvas canvas, double startX, double endX) {
    // Surface zone overlays removed — the terrain shape alone provides visual
    // and gameplay challenge, matching Hill Climb Racing's approach.
  }

  void _drawLowCeilings(Canvas canvas, double startX, double endX) {
    final roofPoints = <Offset>[];
    for (var x = startX - 80; x <= endX + 80; x += 42) {
      final ceilingY = terrain.ceilingHeightAt(x);
      if (ceilingY != null) {
        roofPoints.add(Offset(x, ceilingY));
      } else if (roofPoints.length > 1) {
        _paintCeiling(canvas, roofPoints);
        roofPoints.clear();
      } else {
        roofPoints.clear();
      }
    }
    if (roofPoints.length > 1) {
      _paintCeiling(canvas, roofPoints);
    }
  }

  void _paintCeiling(Canvas canvas, List<Offset> roofPoints) {
    final path = Path()
      ..moveTo(roofPoints.first.dx, roofPoints.first.dy - 190)
      ..lineTo(roofPoints.first.dx, roofPoints.first.dy);
    for (final point in roofPoints.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path
      ..lineTo(roofPoints.last.dx, roofPoints.last.dy - 190)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xDD231A18));
    final edge = Paint()
      ..color = const Color(0xFFE0B46C).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final edgePath = Path()..moveTo(roofPoints.first.dx, roofPoints.first.dy);
    for (final point in roofPoints.skip(1)) {
      edgePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(edgePath, edge);
    final spikePaint = Paint()..color = const Color(0xFF38251C);
    for (var i = 1; i < roofPoints.length; i += 2) {
      final p = roofPoints[i];
      final spike = Path()
        ..moveTo(p.dx - 10, p.dy - 2)
        ..lineTo(p.dx, p.dy + 34 + (i % 3) * 7)
        ..lineTo(p.dx + 10, p.dy - 2)
        ..close();
      canvas.drawPath(spike, spikePaint);
    }
  }

  void _drawBridgeObstacles(Canvas canvas, double startX, double endX) {
    var probeX = startX - 90;
    double? spanStart;
    double lastBridgeX = probeX;

    while (probeX <= endX + 90) {
      final onBridge = terrain.bridgeDeckHeightAt(probeX) != null;
      if (onBridge && spanStart == null) {
        spanStart = probeX;
      }
      if (!onBridge && spanStart != null) {
        _drawBridgeSpan(canvas, spanStart, lastBridgeX);
        spanStart = null;
      }
      if (onBridge) {
        lastBridgeX = probeX;
      }
      probeX += (saveService.performanceModeEnabled ? 34 : 22);
    }

    if (spanStart != null) {
      _drawBridgeSpan(canvas, spanStart, lastBridgeX);
    }
  }

  void _drawBridgeSpan(Canvas canvas, double startX, double endX) {
    if (endX <= startX + 60) {
      return;
    }

    final timber = Paint()
      ..color = const Color(0xFF5B3824)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final darkTimber = Paint()
      ..color = const Color(0xFF2F1F17)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final topEdge = Paint()
      ..color = const Color(0xFFE0B46C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final rope = Paint()
      ..color = const Color(0xFF1D1510)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final support = Paint()
      ..color = const Color(0xFF3A2418)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    final nail = Paint()
      ..color = const Color(0xFFE0B46C)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Sample the actual curved deck to render it faithfully (shows the sag)
    const step = 8.0;
    final deckYs = <double, double>{};
    for (var x = startX; x <= endX + step; x += step) {
      final y = terrain.bridgeDeckHeightAt(x);
      if (y != null) deckYs[x] = y;
    }
    if (deckYs.isEmpty) return;

    // Build a smooth path for the deck surface following the actual sag curve
    Offset? prev;
    for (final entry in deckYs.entries) {
      final cur = Offset(entry.key, entry.value);
      if (prev != null) {
        canvas.drawLine(
          Offset(prev.dx, prev.dy + 16),
          Offset(cur.dx, cur.dy + 16),
          shadow,
        );
        canvas.drawLine(
          Offset(prev.dx, prev.dy + 7),
          Offset(cur.dx, cur.dy + 7),
          timber,
        );
        canvas.drawLine(
          Offset(prev.dx, prev.dy - 3),
          Offset(cur.dx, cur.dy - 3),
          topEdge,
        );
        canvas.drawLine(
          Offset(prev.dx, prev.dy + 22),
          Offset(cur.dx, cur.dy + 22),
          rope,
        );
      }
      prev = cur;
    }

    // Main rope cables running from tower to tower, following the sag
    final ropeEntryY = terrain.bridgeDeckHeightAt(startX + 20) ?? 0;
    final ropeMidY =
        terrain.bridgeDeckHeightAt((startX + endX) / 2) ?? ropeEntryY;
    final ropeExitY = terrain.bridgeDeckHeightAt(endX - 20) ?? ropeEntryY;
    // Draw the hanging rope cables slightly above the deck
    canvas.drawLine(
      Offset(startX + 22, ropeEntryY - 12),
      Offset((startX + endX) / 2, ropeMidY - 8),
      rope,
    );
    canvas.drawLine(
      Offset((startX + endX) / 2, ropeMidY - 8),
      Offset(endX - 22, ropeExitY - 12),
      rope,
    );

    // Cross planks every 28px along the deck
    for (var x = startX + 20; x < endX; x += 28) {
      final y = terrain.bridgeDeckHeightAt(x) ?? ropeEntryY;
      canvas.drawLine(Offset(x, y - 9), Offset(x + 9, y + 22), darkTimber);
      canvas.drawLine(Offset(x + 14, y + 9), Offset(x + 18, y + 60), support);
      // Nail heads for the planks — matches HCR wooden bridge feel
      canvas.drawCircle(Offset(x + 4, y - 4), 2.5, nail);
    }

    // Tall towers at each end of the span
    for (final x in [startX + 34.0, endX - 34.0]) {
      final y = terrain.bridgeDeckHeightAt(x) ?? ropeEntryY;
      // Vertical tower posts
      canvas.drawLine(
        Offset(x - 8, y + 7),
        Offset(x - 8, y - 72),
        support..strokeWidth = 8,
      );
      canvas.drawLine(
        Offset(x + 8, y + 7),
        Offset(x + 8, y - 72),
        support..strokeWidth = 8,
      );
      // Cross-beam at top of tower
      canvas.drawLine(
        Offset(x - 26, y - 64),
        Offset(x + 26, y - 64),
        timber..strokeWidth = 10,
      );
      // Diagonal braces
      canvas.drawLine(
        Offset(x - 6, y + 7),
        Offset(x - 30, y + 88),
        support..strokeWidth = 6,
      );
      canvas.drawLine(
        Offset(x + 6, y + 7),
        Offset(x + 30, y + 88),
        support..strokeWidth = 6,
      );
      // Tower cap
      canvas.drawCircle(
        Offset(x - 8, y - 74),
        4,
        nail..color = const Color(0xFFE0B46C),
      );
      canvas.drawCircle(
        Offset(x + 8, y - 74),
        4,
        nail..color = const Color(0xFFE0B46C),
      );
    }
  }

  void _drawTrailObjects(Canvas canvas, double startX, double endX) {
    final goalX = _startX + stage.goalMeters * _pixelsPerMeter;

    if (_startX >= startX - 160 && _startX <= endX + 160) {
      _drawStartBanner(canvas, _startX + 36);
    }

    if (goalX >= startX - 260 && goalX <= endX + 300) {
      _drawFinishArch(canvas, goalX);
    }

    for (var i = 0; i < stage.levels.length; i += 1) {
      final level = stage.levels[i];
      final x = _startX + level.endMeters * _pixelsPerMeter;
      if (level.endMeters >= stage.goalMeters) {
        continue;
      }
      if (x >= startX - 140 && x <= endX + 140) {
        _drawCheckpointGate(canvas, x, i + 1);
      }
    }

    // Simple distance posts give progress feedback without turning the road
    // into a warning-sign UI layer. The real hazards are the hills, bridges,
    // surfaces, landings, and fuel/coin lines.
    for (var meters = 250; meters < stage.goalMeters; meters += 250) {
      final x = _startX + meters * _pixelsPerMeter;
      if (x >= startX - 80 && x <= endX + 80) {
        _drawDistancePost(canvas, x, meters);
      }
    }
  }

  void _drawDistancePost(Canvas canvas, double x, int meters) {
    final roadY = terrain.heightAt(x);
    final post = Paint()
      ..color = const Color(0xFF3A2418)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final face = Paint()..color = const Color(0xCCE0B46C);
    canvas.drawLine(Offset(x, roadY - 4), Offset(x, roadY - 42), post);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, roadY - 48), width: 54, height: 22),
        const Radius.circular(7),
      ),
      face,
    );
    _drawMiniText(
      canvas,
      '${meters}m',
      Offset(x, roadY - 50),
      9,
      const Color(0xFF1D1510),
    );
  }

  void _drawStartBanner(Canvas canvas, double x) {
    final roadY = terrain.heightAt(x);
    final post = Paint()
      ..color = const Color(0xFF3A2418)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final banner = Paint()..color = const Color(0xDD070B13);
    canvas.drawLine(
      Offset(x - 58, roadY - 2),
      Offset(x - 58, roadY - 104),
      post,
    );
    canvas.drawLine(
      Offset(x + 58, roadY - 2),
      Offset(x + 58, roadY - 104),
      post,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, roadY - 100), width: 112, height: 34),
        const Radius.circular(10),
      ),
      banner,
    );
    _drawMiniText(
      canvas,
      'START',
      Offset(x, roadY - 102),
      15,
      const Color(0xFFFFD166),
    );
  }

  void _drawCheckpointGate(Canvas canvas, double x, int index) {
    final roadY = terrain.heightAt(x);
    final post = Paint()
      ..color = const Color(0xFF3A2418)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final rope = Paint()
      ..color = const Color(0xFFE0B46C)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(x - 54, roadY - 4),
      Offset(x - 54, roadY - 118),
      post,
    );
    canvas.drawLine(
      Offset(x + 54, roadY - 4),
      Offset(x + 54, roadY - 118),
      post,
    );
    canvas.drawLine(
      Offset(x - 54, roadY - 108),
      Offset(x + 54, roadY - 108),
      rope,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, roadY - 108), width: 84, height: 32),
        const Radius.circular(9),
      ),
      Paint()..color = const Color(0xDD070B13),
    );
    _drawMiniText(
      canvas,
      'CP$index',
      Offset(x, roadY - 118),
      15,
      const Color(0xFFE7FDFF),
    );
  }

  void _drawFinishArch(Canvas canvas, double x) {
    final roadY = terrain.heightAt(x);
    final post = Paint()
      ..color = const Color(0xFF2F1F17)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    final gold = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final banner = Paint()..color = const Color(0xEE070B13);
    canvas.drawLine(
      Offset(x - 76, roadY - 2),
      Offset(x - 76, roadY - 154),
      post,
    );
    canvas.drawLine(
      Offset(x + 76, roadY - 2),
      Offset(x + 76, roadY - 154),
      post,
    );
    canvas.drawLine(
      Offset(x - 76, roadY - 148),
      Offset(x + 76, roadY - 148),
      gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, roadY - 148), width: 138, height: 42),
        const Radius.circular(13),
      ),
      banner,
    );
    _drawMiniText(
      canvas,
      'FINISH',
      Offset(x, roadY - 164),
      17,
      const Color(0xFFFFD166),
    );
    _drawMiniText(
      canvas,
      stage.name.toUpperCase(),
      Offset(x, roadY - 132),
      10,
      const Color(0xFFE7FDFF),
    );
    canvas.drawCircle(
      Offset(x - 76, roadY - 165),
      10,
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.drawCircle(
      Offset(x + 76, roadY - 165),
      10,
      Paint()..color = const Color(0xFFFFD166),
    );
  }

  void _drawMiniText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center.translate(-painter.width / 2, -painter.height / 2),
    );
  }

  void _drawRockMass(Canvas canvas, List<Offset> points, double bottomY) {
    final layers = saveService.performanceModeEnabled ? 1 : 2;
    for (var layer = 0; layer < layers; layer += 1) {
      final depth = 48.0 + layer * 58;
      final path = Path()
        ..moveTo(points.first.dx, bottomY)
        ..lineTo(points.first.dx, points.first.dy + depth);
      for (final point in points) {
        path.lineTo(
          point.dx,
          point.dy +
              depth +
              math.sin(point.dx * 0.008 + layer) * (10 + layer * 4),
        );
      }
      path
        ..lineTo(points.last.dx, bottomY)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xAA70442B),
            const Color(0x88533122),
            const Color(0x66291A15),
          ][layer],
      );
    }
  }

  void _drawMistAndOutpostLights(
    Canvas canvas,
    double cameraX,
    double cameraY,
  ) {
    for (var i = 0; i < 2; i += 1) {
      final y = cameraY + size.y * (0.66 + i * 0.045);
      canvas.drawRect(
        Rect.fromLTWH(cameraX - 40, y, size.x + 80, 26),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x00FFE2A1), Color(0x22FFE2A1), Color(0x00FFE2A1)],
          ).createShader(Rect.fromLTWH(cameraX, y, size.x, 26)),
      );
    }

    for (var i = 0; i < 8; i += 1) {
      final x = cameraX * 0.42 + i * 145 + math.sin(i * 1.3) * 36;
      final y = cameraY + size.y * 0.73 + math.sin(i * 2.1) * 18;
      final color = i.isEven
          ? const Color(0xFFE0B46C)
          : const Color(0xFFFFD166);
      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = color.withValues(alpha: 0.45),
      );
    }
  }

  void _drawMountainLayer(
    Canvas canvas, {
    required double cameraX,
    required double cameraY,
    required double parallax,
    required double baseY,
    required double height,
    required Color color,
    required Color rimColor,
    required double phase,
  }) {
    final startX = cameraX - 120;
    final endX = cameraX + size.x + 180;
    final path = Path()
      ..moveTo(startX, cameraY + size.y + 120)
      ..lineTo(startX, baseY);

    for (
      var x = startX;
      x <= endX;
      x += (saveService.performanceModeEnabled ? 128 : 88)
    ) {
      final px = x * parallax;
      final y =
          baseY -
          math.sin(px * 0.010 + phase).abs() * height -
          math.sin(px * 0.023 + phase * 0.7).abs() * height * 0.32;
      path.lineTo(x, y);
    }

    path
      ..lineTo(endX, cameraY + size.y + 120)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  static double _lerp(double a, double b, double t) {
    return a + (b - a) * t;
  }
}

class _SkyBody {
  const _SkyBody({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.glowRadius,
    required this.coreColor,
    required this.glowColor,
  });

  final double dx;
  final double dy;
  final double radius;
  final double glowRadius;
  final Color coreColor;
  final Color glowColor;
}
