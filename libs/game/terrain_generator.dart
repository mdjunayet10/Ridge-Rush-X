import 'dart:math' as math;
import 'dart:ui';

import 'stage_definitions.dart';

/// Deterministic distance-indexed terrain for Hill Rider.
///
/// The road should be the main obstacle. This file intentionally avoids
/// warning-text hazards and random block traps. Difficulty comes from a small
/// set of repeatable systems: continuous road profile, stage material,
/// pickup cadence, bridge spans, and distance-gated escalation.
class TerrainGenerator {
  TerrainGenerator({this.stage = defaultStage});

  static const double _startX = 140;
  static const double _pixelsPerMeter = 10;

  final StageDefinition stage;
  final Map<int, double> _heightCache = <int, double>{};
  final Map<int, double?> _bridgeCache = <int, double?>{};
  final Map<int, double?> _ceilingCache = <int, double?>{};

  late final List<_BridgeSpan> _bridgeSpans = _buildBridgeSpans();

  double heightAt(double x) {
    final cacheKey = (x / 4).round();
    final cached = _heightCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final sampleX = cacheKey * 4.0;
    final naturalRoad = _naturalHeightAt(sampleX);
    final bridgeY = bridgeDeckHeightAt(sampleX);
    final roadY = bridgeY == null
        ? naturalRoad
        : math.min(naturalRoad, bridgeY);

    if (_heightCache.length > 22000) {
      _heightCache.clear();
    }
    _heightCache[cacheKey] = roadY;
    return roadY;
  }

  double slopeAt(double x) {
    const sample = 12.0;
    return (heightAt(x + sample) - heightAt(x - sample)) / (sample * 2);
  }

  double difficultyAtMeters(double meters) {
    final progress = (meters / math.max(1, stage.goalMeters))
        .clamp(0, 1)
        .toDouble();
    return (0.18 + progress * 0.55 + _stageDifficulty * 0.18)
        .clamp(0, 1)
        .toDouble();
  }

  bool isRampZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    return _windowM(m, goal * 0.26, 100) > 0 ||
        _windowM(m, goal * 0.47, 130) > 0 ||
        _windowM(m, goal * 0.73, 150) > 0 ||
        _windowM(m, goal * 0.90, 120) > 0;
  }

  bool isMudZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    if (stage.id == 'broken_bridge') {
      return _plateauM(m, goal * 0.22, goal * 0.31, 18, 18) > 0.08 ||
          _plateauM(m, goal * 0.54, goal * 0.62, 18, 18) > 0.08;
    }
    if (stage.id == 'storm_canyon') {
      return _plateauM(m, goal * 0.38, goal * 0.47, 18, 18) > 0.08;
    }
    return false;
  }

  bool isWaterZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    if (stage.id == 'broken_bridge') {
      return _plateauM(m, goal * 0.10, goal * 0.18, 16, 16) > 0.08 ||
          _plateauM(m, goal * 0.34, goal * 0.42, 16, 16) > 0.08;
    }
    return false;
  }

  bool isSnowZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    return stage.id == 'rocky_peaks' &&
        (_plateauM(m, goal * 0.08, goal * 0.92, 34, 34) > 0.08);
  }

  bool isSandZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    return stage.id == 'high_dunes' &&
        _plateauM(m, goal * 0.04, goal * 0.96, 30, 30) > 0.08;
  }

  bool isIceZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    if (stage.id == 'rocky_peaks') {
      return _plateauM(m, goal * 0.14, goal * 0.36, 20, 20) > 0.08 ||
          _plateauM(m, goal * 0.62, goal * 0.82, 20, 20) > 0.08;
    }
    if (stage.id == 'broken_bridge') {
      return _plateauM(m, goal * 0.74, goal * 0.90, 20, 20) > 0.08;
    }
    return false;
  }

  bool isRockGardenZone(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    return (stage.id == 'rocky_peaks' || stage.id == 'storm_canyon') &&
        (_plateauM(m, goal * 0.42, goal * 0.55, 14, 14) > 0.1 ||
            _plateauM(m, goal * 0.78, goal * 0.88, 14, 14) > 0.1);
  }

  bool isLogZone(double x) => false;

  bool isBridgeZone(double x) => bridgeDeckHeightAt(x) != null;

  /// No invisible canyon traps. Bridge danger should be readable from the deck
  /// and the vehicle physics, not a hidden death rectangle.
  bool isDangerPit(double x) => false;

  bool hasDangerPitAhead(double x, {double lookAhead = 360}) => false;

  bool isBridgeGap(double x) => false;

  double? bridgeDeckHeightAt(double x) {
    final cacheKey = (x / 10).round();
    if (_bridgeCache.containsKey(cacheKey)) {
      return _bridgeCache[cacheKey];
    }
    final deckY = _computeBridgeDeckHeightAt(cacheKey * 10.0);
    if (_bridgeCache.length > 7000) {
      _bridgeCache.clear();
    }
    _bridgeCache[cacheKey] = deckY;
    return deckY;
  }

  double? ceilingHeightAt(double x) {
    final cacheKey = (x / 10).round();
    if (_ceilingCache.containsKey(cacheKey)) {
      return _ceilingCache[cacheKey];
    }
    final ceilingY = _computeCeilingHeightAt(cacheKey * 10.0);
    if (_ceilingCache.length > 7000) {
      _ceilingCache.clear();
    }
    _ceilingCache[cacheKey] = ceilingY;
    return ceilingY;
  }

  bool isLowCeilingZone(double x) => ceilingHeightAt(x) != null;

  bool hasLowCeilingAhead(double x, {double lookAhead = 410}) {
    for (var probe = x + 70; probe <= x + lookAhead; probe += 42) {
      if (ceilingHeightAt(probe) != null) {
        return true;
      }
    }
    return false;
  }

  bool hasJumpApproachBefore(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    return _windowM(m, goal * 0.26, 160) > 0 ||
        _windowM(m, goal * 0.47, 190) > 0 ||
        _windowM(m, goal * 0.73, 200) > 0 ||
        isBridgeZone(x - 100);
  }

  double gripMultiplierAt(double x) {
    if (isBridgeZone(x)) {
      return 0.94;
    }
    if (isRockGardenZone(x)) {
      return 0.92;
    }
    return 1.0;
  }

  double rollingDragAt(double x) {
    if (isRockGardenZone(x)) {
      return 0.984;
    }
    if (isBridgeZone(x)) {
      return 0.990;
    }
    return 0.995;
  }

  double pitchKickAt(double x) {
    var kick = 0.0;
    if (isRockGardenZone(x)) {
      final m = _metersAt(x);
      kick += math.sin(m * 1.35).sign * 0.12;
    }
    if (isBridgeZone(x)) {
      kick += math.sin(x / 30.0) * 0.045;
    }
    return kick.clamp(-0.20, 0.20).toDouble();
  }

  List<Offset> sample(double startX, double endX, {double step = 26}) {
    final points = <Offset>[];
    final safeStep = step.clamp(18, 120).toDouble();
    final safeStart = (startX / safeStep).floor() * safeStep;
    for (var x = safeStart; x <= endX + safeStep; x += safeStep) {
      points.add(Offset(x, heightAt(x)));
    }
    return points;
  }

  double? _computeBridgeDeckHeightAt(double x) {
    for (final span in _bridgeSpans) {
      final start = span.start;
      final end = start + span.length;
      if (x < start || x > end) {
        continue;
      }

      final local = x - start;
      final t = (local / span.length).clamp(0, 1).toDouble();
      // Sample terrain well outside the chasm so we get the ground-level Y
      // (not the depressed valley). The bridge deck sits lift px above that.
      final entryY = _naturalHeightAtNoChasm(start - 120);
      final exitY = _naturalHeightAtNoChasm(end + 120);
      final sag = math.sin(t * math.pi) * span.sag;
      final plankWave = math.sin(local / 26.0) * 1.4;
      return _lerp(entryY - span.lift, exitY - span.lift * 0.92, t) +
          sag +
          plankWave;
    }
    return null;
  }

  /// Same as [_naturalHeightAt] but without the bridge chasm contribution.
  /// Used to compute the deck reference height without circular dependency.
  double _naturalHeightAtNoChasm(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    final progress = (m / math.max(1, goal)).clamp(0, 1).toDouble();
    final difficulty = (0.18 + progress * 0.62 + _stageDifficulty * 0.25)
        .clamp(0, 1)
        .toDouble();
    final intro = _smoothStep(((m - 8) / 92).clamp(0, 1).toDouble());
    final calmStart = 438 + math.sin(x / 480.0) * 2.0;
    var road = 438.0;
    road += _baseRoadGrammar(m, goal, difficulty);
    road += _stageRoadGrammar(m, goal, difficulty);
    road += _distanceGatedEscalation(m, goal, difficulty);
    road += _finalApproach(m, goal, difficulty);
    return _lerp(calmStart, road, intro).clamp(160, 820).toDouble();
  }

  double? _computeCeilingHeightAt(double x) {
    // Low roofs are reserved for late technical levels. They are drawn as
    // actual cave geometry and are not announced by text banners.
    if (stage.id != 'storm_canyon') {
      return null;
    }
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    final gate =
        _plateauM(m, goal * 0.58, goal * 0.68, 18, 18) +
        _plateauM(m, goal * 0.84, goal * 0.91, 18, 18);
    if (gate <= 0) {
      return null;
    }
    final clearance = 170 - _stageDifficulty * 22;
    final roof =
        heightAt(x) -
        clearance -
        math.sin(m / 18.0) * 9 -
        math.sin(m / 6.5).abs() * 6;
    return _lerp(heightAt(x) - 260, roof, gate.clamp(0, 1).toDouble());
  }

  double _naturalHeightAt(double x) {
    final m = _metersAt(x);
    final goal = stage.goalMeters.toDouble();
    final progress = (m / math.max(1, goal)).clamp(0, 1).toDouble();
    final difficulty = (0.18 + progress * 0.62 + _stageDifficulty * 0.25)
        .clamp(0, 1)
        .toDouble();
    final intro = _smoothStep(((m - 8) / 92).clamp(0, 1).toDouble());
    final calmStart = 438 + math.sin(x / 480.0) * 2.0;

    var road = 438.0;
    road += _baseRoadGrammar(m, goal, difficulty);
    road += _stageRoadGrammar(m, goal, difficulty);
    road += _distanceGatedEscalation(m, goal, difficulty);
    road += _finalApproach(m, goal, difficulty);

    // ── Bridge chasms ────────────────────────────────────────────────────
    // Each bridge span sits over a real valley. The terrain dips under the
    // bridge so the planks are visibly elevated above solid ground.
    for (final span in _bridgeSpans) {
      final end = span.start + span.length;
      // Extend chasm slightly beyond the span edges for natural ramps
      final chasmStart = span.start - 60;
      final chasmEnd = end + 60;
      final local = x - chasmStart;
      final chasmWidth = chasmEnd - chasmStart;
      if (local > 0 && local < chasmWidth) {
        final t = local / chasmWidth;
        // Sine arch = deepest in the middle, zero at edges
        road += math.sin(t * math.pi) * 145;
      }
    }

    return _lerp(calmStart, road, intro).clamp(160, 820).toDouble();
  }

  double _baseRoadGrammar(double m, double goal, double difficulty) {
    // Deterministic hill-climb road grammar. The road itself is the enemy:
    // readable rollers, crest traps, valleys, ramps, and uneven landings.
    final longRollers =
        math.sin(m / 63.0 + 0.4) * (68 + difficulty * 44) +
        math.sin(m / 29.0 + 1.3) * (36 + difficulty * 24);
    final microBumps =
        math.sin(m / 7.2) * (9.5 + difficulty * 8) +
        math.sin(m / 3.9 + 0.5) * (4.2 + difficulty * 5) +
        math.sin(m / 18.0 + 2.1) * (22 + difficulty * 18);

    var features = 0.0;
    // HCR-style: steeper hills (shorter climbWidth), deeper valleys, more amplitude
    features += _smallBumpChain(m, 90, 185, 16 + difficulty * 10);
    features += _crestTrap(m, 245, 52, 32, 110 + difficulty * 28);
    features += _dipTrap(m, 365, 48, 44, 88 + difficulty * 32);
    features += _crestTrap(m, goal * 0.25, 62, 36, 138 + difficulty * 50);
    features += _dipTrap(m, goal * 0.34, 52, 44, 102 + difficulty * 42);
    features += _crestTrap(m, goal * 0.43, 50, 30, 148 + difficulty * 60);
    features += _rampAndBowl(m, goal * 0.53, 130 + difficulty * 62);
    features += _smallBumpChain(
      m,
      goal * 0.61,
      goal * 0.69,
      20 + difficulty * 12,
    );
    features += _crestTrap(m, goal * 0.76, 56, 32, 165 + difficulty * 74);
    features += _dipTrap(m, goal * 0.84, 48, 40, 118 + difficulty * 50);
    // Consecutive short bumps — the signature HCR feel
    features += _hcrBumpChain(m, goal * 0.18, 6, 26, 48 + difficulty * 20);
    features += _hcrBumpChain(m, goal * 0.56, 8, 20, 58 + difficulty * 28);
    features += _hcrBumpChain(m, goal * 0.80, 10, 18, 72 + difficulty * 36);

    return longRollers + microBumps + features;
  }

  double _stageRoadGrammar(double m, double goal, double difficulty) {
    switch (stage.id) {
      case 'broken_bridge':
        // Seasons-style: same hill grammar, but water/mud/ice sections alter
        // grip. Road is still readable and continuous.
        return _seasonalWetlands(m, goal, difficulty);
      case 'high_dunes':
        return _desertDunes(m, goal, difficulty);
      case 'rocky_peaks':
        return _frostedMountain(m, goal, difficulty);
      case 'storm_canyon':
        return _speedCanyon(m, goal, difficulty);
      default:
        return _countrysideCanyon(m, goal, difficulty);
    }
  }

  double _countrysideCanyon(double m, double goal, double difficulty) {
    // Level 1: big readable hills, not text-warned obstacles.
    return _crestTrap(m, goal * 0.18, 50, 30, 110) +
        _dipTrap(m, goal * 0.29, 46, 40, 88) +
        _momentumClimb(m, goal * 0.49, 110, 62, 175) +
        _rampAndBowl(m, goal * 0.63, 152) +
        _smallBumpChain(m, goal * 0.69, goal * 0.77, 18) +
        _crestTrap(m, goal * 0.88, 58, 34, 180) +
        _hcrBumpChain(m, goal * 0.36, 5, 24, 60);
  }

  double _seasonalWetlands(double m, double goal, double difficulty) {
    final springPools = _plateauM(m, goal * 0.08, goal * 0.19, 20, 20);
    final mud = _plateauM(m, goal * 0.23, goal * 0.33, 20, 20);
    final winter = _plateauM(m, goal * 0.72, goal * 0.90, 24, 24);
    return springPools * math.sin(m / 11.0) * 8 +
        mud * (math.sin(m / 17.0) * 10 + 16) +
        winter * math.sin(m / 14.0) * 8 +
        _dipTrap(m, goal * 0.32, 96, 82, 58) +
        _crestTrap(m, goal * 0.48, 112, 58, 96 + difficulty * 20) +
        _momentumClimb(m, goal * 0.66, 220, 110, 104 + difficulty * 22) +
        _smallBumpChain(m, goal * 0.76, goal * 0.86, 9 + difficulty * 4);
  }

  double _desertDunes(double m, double goal, double difficulty) {
    final dunes = math.sin(m / 82.0) * 110 + math.sin(m / 36.0 + 0.8) * 60;
    return dunes +
        _momentumClimb(m, goal * 0.25, 130, 72, 185 + difficulty * 65) +
        _dipTrap(m, goal * 0.42, 60, 48, 130) +
        _crestTrap(m, goal * 0.56, 62, 34, 200 + difficulty * 72) +
        _momentumClimb(m, goal * 0.72, 155, 86, 240 + difficulty * 90) +
        _crestTrap(m, goal * 0.86, 58, 30, 200 + difficulty * 72) +
        _hcrBumpChain(m, goal * 0.35, 7, 22, 70 + difficulty * 30);
  }

  double _frostedMountain(double m, double goal, double difficulty) {
    final slickRollers =
        math.sin(m / 52.0 + 0.4) * 58 + math.sin(m / 20.0 + 1.7) * 26;
    return slickRollers +
        _crestTrap(m, goal * 0.20, 52, 30, 158 + difficulty * 52) +
        _dipTrap(m, goal * 0.36, 54, 44, 130) +
        _momentumClimb(m, goal * 0.52, 130, 76, 220 + difficulty * 88) +
        _rockStepChain(m, goal * 0.44, goal * 0.57, difficulty) +
        _rockStepChain(m, goal * 0.73, goal * 0.88, difficulty) +
        _crestTrap(m, goal * 0.82, 52, 28, 210 + difficulty * 72) +
        _hcrBumpChain(m, goal * 0.60, 9, 18, 80 + difficulty * 38);
  }

  double _speedCanyon(double m, double goal, double difficulty) {
    // High-speed stage: fast approach, then brutal crests and ramps
    final flatSpeed = math.sin(m / 136.0) * 24 + math.sin(m / 36.0) * 10;
    final earlyGate = _smoothStep(
      ((m - goal * 0.22) / 220).clamp(0, 1).toDouble(),
    );
    final lateGrammar =
        _crestTrap(m, goal * 0.34, 68, 38, 165) +
        _momentumClimb(m, goal * 0.52, 160, 82, 220 + difficulty * 62) +
        _dipTrap(m, goal * 0.65, 58, 46, 155) +
        _crestTrap(m, goal * 0.74, 52, 24, 185) +
        _momentumClimb(m, goal * 0.88, 185, 96, 265 + difficulty * 90) +
        _hcrBumpChain(m, goal * 0.44, 8, 20, 75 + difficulty * 35);
    return flatSpeed + lateGrammar * earlyGate;
  }

  double _distanceGatedEscalation(double m, double goal, double difficulty) {
    final late = _smoothStep(
      ((m - goal * 0.38) / (goal * 0.48)).clamp(0, 1).toDouble(),
    );
    // Aggressive bumps that build across the second half of the stage
    final bumpChain = math.sin(m / 7.8).abs() * (10 + difficulty * 9) * late;
    final crestChain =
        _crestTrap(m, goal * 0.55, 42, 26, (65 + difficulty * 90) * late) +
        _crestTrap(m, goal * 0.70, 38, 24, (80 + difficulty * 105) * late);
    final lateClimb = _momentumClimb(
      m,
      goal * 0.87,
      145,
      80,
      (120 + difficulty * 140) * late,
    );
    return bumpChain + crestChain + lateClimb;
  }

  double _finalApproach(double m, double goal, double difficulty) {
    return _valley(m, goal - 300, 170, 36 + difficulty * 18) +
        _hill(m, goal - 145, 250, 82 + difficulty * 42) -
        _plateauM(m, goal - 38, goal + 80, 18, 36) * 22;
  }

  double _rockStepChain(double m, double start, double end, double difficulty) {
    final gate = _plateauM(m, start, end, 14, 14);
    if (gate <= 0) {
      return 0;
    }
    return gate *
        (math.sin(m / 10.2) * (10 + difficulty * 6) +
            math.sin(m / 4.8).sign * (3 + difficulty * 2.4));
  }

  double _crestTrap(
    double m,
    double center,
    double climbWidth,
    double dropWidth,
    double height,
  ) {
    final up = _smoothStep(
      ((m - (center - climbWidth)) / climbWidth).clamp(0, 1).toDouble(),
    );
    final down = _smoothStep(((m - center) / dropWidth).clamp(0, 1).toDouble());
    return -height * up + height * down;
  }

  double _dipTrap(
    double m,
    double center,
    double entryWidth,
    double exitWidth,
    double depth,
  ) {
    final down = _smoothStep(
      ((m - (center - entryWidth)) / entryWidth).clamp(0, 1).toDouble(),
    );
    final up = _smoothStep(((m - center) / exitWidth).clamp(0, 1).toDouble());
    return depth * down - depth * up;
  }

  double _momentumClimb(
    double m,
    double center,
    double climbWidth,
    double plateauWidth,
    double height,
  ) {
    final rise = _smoothStep(
      ((m - (center - climbWidth)) / climbWidth).clamp(0, 1).toDouble(),
    );
    final fall = _smoothStep(
      ((m - (center + plateauWidth)) / (climbWidth * 0.58))
          .clamp(0, 1)
          .toDouble(),
    );
    final summitRipples =
        math.sin(m / 12.5) *
        5 *
        _plateauM(m, center - 20, center + plateauWidth, 16, 20);
    return -height * rise + height * fall + summitRipples;
  }

  double _smallBumpChain(double m, double start, double end, double height) {
    final gate = _plateauM(m, start, end, 12, 12);
    return gate *
        (math.sin(m / 8.0).abs() * height +
            math.sin(m / 4.2).abs() * height * 0.38);
  }

  double _hill(double m, double center, double width, double height) {
    return -_windowM(m, center, width) * height;
  }

  double _valley(double m, double center, double width, double depth) {
    return _windowM(m, center, width) * depth;
  }

  /// Consecutive short steep bumps — the signature Hill Climb Racing feel.
  /// [count] bumps, [spacing] meters apart, each [height] pixels tall.
  double _hcrBumpChain(
    double m,
    double start,
    int count,
    double spacing,
    double height,
  ) {
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      final center = start + i * spacing;
      // Sharp asymmetric crest: fast climb, fast drop
      total += _crestTrap(m, center, spacing * 0.42, spacing * 0.38, height);
    }
    return total;
  }

  double _rampAndBowl(double m, double center, double height) {
    final kicker = -_plateauM(m, center - 36, center + 16, 32, 12) * height;
    final drop = _windowM(m, center + 86, 110) * height * 0.58;
    return kicker + drop;
  }

  List<_BridgeSpan> _buildBridgeSpans() {
    final goal = stage.goalMeters.toDouble();
    final hard = _stageDifficulty;
    final spans = <_BridgeSpan>[];

    void addSpan(double meters, double length, double lift, double sag) {
      spans.add(
        _BridgeSpan(
          start: _xAtMeters(meters),
          length: _pixels(length),
          lift: lift,
          sag: sag,
        ),
      );
    }

    // Bridges span real chasms — lift clears the 145px valley depth.
    // Sag is significantly increased to match HCR's drooping rope bridges.
    addSpan(goal * 0.22, 80 + hard * 12, 120 + hard * 22, 52 + hard * 14);
    addSpan(goal * 0.45, 88 + hard * 14, 130 + hard * 24, 60 + hard * 16);

    switch (stage.id) {
      case 'broken_bridge':
        addSpan(goal * 0.12, 90 + hard * 14, 115 + hard * 18, 48 + hard * 12);
        addSpan(goal * 0.35, 100 + hard * 16, 128 + hard * 24, 56 + hard * 14);
        addSpan(goal * 0.60, 110 + hard * 18, 135 + hard * 26, 62 + hard * 16);
        addSpan(goal * 0.80, 118 + hard * 20, 142 + hard * 28, 68 + hard * 18);
        break;
      case 'high_dunes':
        addSpan(goal * 0.38, 84 + hard * 12, 118 + hard * 20, 50 + hard * 12);
        addSpan(goal * 0.65, 92 + hard * 14, 126 + hard * 22, 58 + hard * 14);
        break;
      case 'rocky_peaks':
        addSpan(goal * 0.32, 88 + hard * 14, 122 + hard * 22, 52 + hard * 12);
        addSpan(goal * 0.58, 96 + hard * 16, 130 + hard * 24, 60 + hard * 14);
        addSpan(goal * 0.76, 104 + hard * 18, 138 + hard * 26, 65 + hard * 16);
        break;
      case 'storm_canyon':
        addSpan(goal * 0.20, 92 + hard * 14, 120 + hard * 20, 52 + hard * 12);
        addSpan(goal * 0.42, 100 + hard * 16, 128 + hard * 24, 60 + hard * 14);
        addSpan(goal * 0.65, 110 + hard * 18, 138 + hard * 26, 68 + hard * 16);
        addSpan(goal * 0.85, 120 + hard * 20, 148 + hard * 30, 74 + hard * 18);
        break;
      default:
        addSpan(goal * 0.65, 76 + hard * 10, 118 + hard * 18, 48 + hard * 12);
        break;
    }

    return spans;
  }

  double get _stageDifficulty {
    final index = stageDefinitions.indexWhere((item) => item.id == stage.id);
    return index < 0
        ? 0.0
        : (index / math.max(1, stageDefinitions.length - 1))
              .clamp(0, 1)
              .toDouble();
  }

  double _metersAt(double x) => math.max(0.0, (x - _startX) / _pixelsPerMeter);

  double _xAtMeters(double meters) => _startX + meters * _pixelsPerMeter;

  double _pixels(double meters) => meters * _pixelsPerMeter;

  static double _windowM(double m, double center, double width) {
    final start = center - width / 2;
    final t = ((m - start) / width).clamp(0, 1).toDouble();
    if (t <= 0 || t >= 1) {
      return 0;
    }
    return math.sin(t * math.pi);
  }

  static double _plateauM(
    double m,
    double start,
    double end,
    double fadeIn,
    double fadeOut,
  ) {
    final enter = _smoothStep(((m - start) / fadeIn).clamp(0, 1).toDouble());
    final leave = _smoothStep(((m - end) / fadeOut).clamp(0, 1).toDouble());
    return (enter - leave).clamp(0, 1).toDouble();
  }

  static double _smoothStep(double t) => t * t * (3 - 2 * t);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _BridgeSpan {
  const _BridgeSpan({
    required this.start,
    required this.length,
    required this.lift,
    required this.sag,
  });

  final double start;
  final double length;
  final double lift;
  final double sag;
}
