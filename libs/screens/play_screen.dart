import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/hill_rider_game.dart';
import '../game/stage_definitions.dart';
import '../services/save_service.dart';
import '../services/sfx_service.dart';
import '../widgets/game_button.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    required this.saveService,
    required this.sfxService,
    super.key,
  });

  final SaveService saveService;
  final SfxService sfxService;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final HillRiderGame _game;

  @override
  void initState() {
    super.initState();
    _game = HillRiderGame(
      saveService: widget.saveService,
      sfxService: widget.sfxService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget<HillRiderGame>(game: _game)),
          Positioned.fill(child: _Hud(game: _game)),
          Positioned.fill(child: _TouchControls(game: _game)),
          Positioned.fill(child: _GameOverOverlay(game: _game)),
        ],
      ),
    );
  }
}

Color _stageAccentForName(String stageName) {
  for (final stage in stageDefinitions) {
    if (stage.name == stageName) {
      return stage.accent;
    }
  }
  return defaultStage.accent;
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game});

  final HillRiderGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<GameSnapshot>(
        valueListenable: game.hud,
        builder: (context, snapshot, _) {
          final stageAccent = _stageAccentForName(snapshot.stageName);
          return Padding(
            padding: EdgeInsets.fromLTRB(
              MediaQuery.sizeOf(context).width >= 720 ? 22 : 12,
              10,
              MediaQuery.sizeOf(context).width >= 720 ? 22 : 12,
              0,
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HudPill(
                      icon: Icons.monetization_on_rounded,
                      text: '${snapshot.totalCoins}',
                      color: const Color(0xFFFFB703),
                      large: MediaQuery.sizeOf(context).width >= 720,
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 720 ? 12 : 8,
                    ),
                    _HudPill(
                      icon: Icons.diamond_rounded,
                      text: '${snapshot.totalGems}',
                      color: const Color(0xFF2EA7A0),
                      large: MediaQuery.sizeOf(context).width >= 720,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 720
                          ? 232
                          : MediaQuery.sizeOf(context).width < 480
                          ? 154
                          : 184,
                      child: _FuelBar(
                        value: snapshot.fuelFraction,
                        accent: stageAccent,
                        large: MediaQuery.sizeOf(context).width >= 720,
                        compact: MediaQuery.sizeOf(context).width < 480,
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width >= 720 ? 12 : 8,
                    ),
                    Tooltip(
                      message: 'Main Menu',
                      child: IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xCC070B13),
                          foregroundColor: const Color(0xFFFFD166),
                          side: const BorderSide(color: Color(0x66E0B46C)),
                        ),
                        onPressed: () async {
                          unawaited(game.sfxService.unlock());
                          game.sfxService.play(
                            SfxCue.buttonClick,
                            volume: 0.45,
                          );
                          await game.quitToMainMenu();
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.exit_to_app_rounded),
                      ),
                    ),
                  ],
                ),
                _DistanceProgressBar(
                  distanceMeters: snapshot.distanceMeters,
                  bestDistanceMeters: snapshot.bestDistanceMeters,
                  goalMeters: snapshot.stageGoalMeters,
                  stageName: snapshot.stageName,
                  destinationName: snapshot.destinationName,
                  nextCheckpointMeters: snapshot.nextCheckpointMeters,
                  levelName: snapshot.levelName,
                  levelDescription: snapshot.levelDescription,
                  levelIndex: snapshot.levelIndex,
                  totalLevels: snapshot.totalLevels,
                  levelStartMeters: snapshot.levelStartMeters,
                  levelEndMeters: snapshot.levelEndMeters,
                  performanceText: snapshot.performanceText,
                  accent: stageAccent,
                  large: MediaQuery.sizeOf(context).width >= 720,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.large,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC070B13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.62), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 15 : 9,
          vertical: large ? 12 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: large ? 27 : 21),
            SizedBox(width: large ? 8 : 5),
            Text(
              text,
              style: TextStyle(
                color: const Color(0xFFE7FDFF),
                fontSize: large ? 21 : 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistanceProgressBar extends StatelessWidget {
  const _DistanceProgressBar({
    required this.distanceMeters,
    required this.bestDistanceMeters,
    required this.goalMeters,
    required this.stageName,
    required this.destinationName,
    required this.nextCheckpointMeters,
    required this.levelName,
    required this.levelDescription,
    required this.levelIndex,
    required this.totalLevels,
    required this.levelStartMeters,
    required this.levelEndMeters,
    required this.performanceText,
    required this.accent,
    required this.large,
  });

  final double distanceMeters;
  final double bestDistanceMeters;
  final int goalMeters;
  final String stageName;
  final String destinationName;
  final int nextCheckpointMeters;
  final String levelName;
  final String levelDescription;
  final int levelIndex;
  final int totalLevels;
  final int levelStartMeters;
  final int levelEndMeters;
  final String performanceText;
  final Color accent;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final goal = goalMeters <= 0 ? 1.0 : goalMeters.toDouble();
    final progress = (distanceMeters / goal).clamp(0, 1).toDouble();
    final bestProgress = (bestDistanceMeters / goal).clamp(0, 1).toDouble();
    final levelWidth = (levelEndMeters - levelStartMeters)
        .clamp(1, 9999)
        .toDouble();
    final levelProgress = ((distanceMeters - levelStartMeters) / levelWidth)
        .clamp(0, 1)
        .toDouble();
    final width = MediaQuery.sizeOf(context).width >= 720
        ? 540.0
        : MediaQuery.sizeOf(context).width < 420
        ? 260.0
        : 340.0;
    final tooltip = [
      stageName,
      if (levelName.isNotEmpty) levelName,
      if (levelDescription.isNotEmpty) levelDescription,
      'Next ${nextCheckpointMeters}m',
      'Goal $destinationName',
      if (performanceText.isNotEmpty) performanceText,
      'Section ${levelIndex + 1}/$totalLevels',
    ].join(' - ');

    return Tooltip(
      message: tooltip,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          height: large ? 68 : 54,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: large ? 22 : 18,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final markerX = (progress * constraints.maxWidth).clamp(
                      0.0,
                      constraints.maxWidth,
                    );
                    final bestX = (bestProgress * constraints.maxWidth).clamp(
                      0.0,
                      constraints.maxWidth,
                    );
                    final sectionX = (levelProgress * constraints.maxWidth)
                        .clamp(0.0, constraints.maxWidth);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          top: large ? 7 : 6,
                          bottom: large ? 7 : 6,
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i += 1) ...[
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0x99151923),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.72),
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                if (i < 3) const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: large ? 8 : 7,
                          height: large ? 6 : 4,
                          width: markerX,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7FDFF),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.55),
                                  blurRadius: 6,
                                ),
                              ],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          left: sectionX - 2,
                          top: 1,
                          child: Icon(
                            Icons.arrow_drop_up_rounded,
                            color: accent,
                            size: large ? 18 : 14,
                          ),
                        ),
                        Positioned(
                          left: bestX - 5,
                          top: large ? 2 : 1,
                          child: Icon(
                            Icons.star_rounded,
                            color: const Color(0xFFFFD166),
                            size: large ? 14 : 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Text(
                '${distanceMeters.floor()}m',
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFFE7FDFF),
                  fontSize: large ? 30 : 23,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(
                      color: Color(0xFF151923),
                      offset: Offset(2, 2),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FuelBar extends StatelessWidget {
  const _FuelBar({
    required this.value,
    required this.accent,
    required this.large,
    required this.compact,
  });

  final double value;
  final Color accent;
  final bool large;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 1).toDouble();
    final fillColor = safeValue <= 0.16
        ? const Color(0xFFFF3D3D)
        : safeValue <= 0.42
        ? const Color(0xFFFFB703)
        : const Color(0xFF47D16C);
    final iconColor = safeValue <= 0.16
        ? const Color(0xFFFFD166)
        : const Color(0xFFE3362F);
    final percent = (safeValue * 100).round().clamp(0, 100);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD070B13),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent.withValues(alpha: 0.72), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: fillColor.withValues(alpha: safeValue < 0.18 ? 0.34 : 0.14),
            blurRadius: safeValue < 0.18 ? 15 : 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 9 : 7,
          vertical: large ? 7 : 5,
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_gas_station_rounded,
              size: large ? 24 : 18,
              color: iconColor,
            ),
            SizedBox(width: large ? 8 : 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: large ? 20 : 15,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xFFE7FDFF)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: safeValue, end: safeValue),
                        duration: const Duration(milliseconds: 120),
                        builder: (context, animatedValue, _) {
                          return FractionallySizedBox(
                            widthFactor: animatedValue,
                            child: ColoredBox(color: fillColor),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: compact ? 5 : 7),
            SizedBox(
              width: compact
                  ? 32
                  : large
                  ? 48
                  : 40,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: TextStyle(
                  color: fillColor,
                  fontSize: compact
                      ? 10
                      : large
                      ? 16
                      : 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalogGaugeCluster extends StatelessWidget {
  const _AnalogGaugeCluster({
    required this.rpm,
    required this.boost,
    required this.accent,
    required this.large,
    required this.compact,
  });

  final double rpm;
  final double boost;
  final Color accent;
  final bool large;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final gaugeSize = compact
        ? 82.0
        : large
        ? 132.0
        : 108.0;
    return IgnorePointer(
      child: SizedBox(
        width: gaugeSize * 2 + (compact ? 18 : 28),
        height: gaugeSize * 0.92,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _AnalogGauge(
              label: 'RPM',
              value: rpm,
              size: gaugeSize,
              accent: accent,
            ),
            SizedBox(width: compact ? 18 : 28),
            _AnalogGauge(
              label: 'BOOST',
              value: boost,
              size: gaugeSize,
              accent: accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalogGauge extends StatelessWidget {
  const _AnalogGauge({
    required this.label,
    required this.value,
    required this.size,
    required this.accent,
  });

  final String label;
  final double value;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(0, 1).toDouble();
    return SizedBox(
      width: size,
      height: size * 0.92,
      child: CustomPaint(
        painter: _AnalogGaugePainter(value: safeValue, accent: accent),
        child: Align(
          alignment: const Alignment(0, 0.70),
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: const Color(0xFFE7FDFF),
              fontSize: size * 0.18,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(
                  color: Color(0xFF151923),
                  offset: Offset(1.6, 1.6),
                  blurRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalogGaugePainter extends CustomPainter {
  const _AnalogGaugePainter({required this.value, required this.accent});

  final double value;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.80);
    final radius = size.width * 0.42;
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = math.pi * 1.13;
    const sweepAngle = math.pi * 1.74;
    final track = Paint()
      ..color = const Color(0xFFE7FDFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = const Color(0xAA151923)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    final danger = Paint()
      ..color = accent.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.050
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, shadow);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, track);
    canvas.drawArc(
      arcRect,
      startAngle + sweepAngle * 0.78,
      sweepAngle * 0.18,
      false,
      danger,
    );

    final tickPaint = Paint()
      ..color = const Color(0xFFE7FDFF)
      ..strokeWidth = size.width * 0.022
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 5; i += 1) {
      final t = i / 5;
      final angle = startAngle + sweepAngle * t;
      final outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - size.width * 0.09),
        center.dy + math.sin(angle) * (radius - size.width * 0.09),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    final needleAngle = startAngle + sweepAngle * value.clamp(0, 1).toDouble();
    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * (radius - size.width * 0.11),
      center.dy + math.sin(needleAngle) * (radius - size.width * 0.11),
    );
    final needle = Paint()
      ..color = const Color(0xFFE7FDFF)
      ..strokeWidth = size.width * 0.040
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, needleEnd, needle);
    canvas.drawCircle(
      center,
      size.width * 0.075,
      Paint()..color = const Color(0xFFE7FDFF),
    );
    canvas.drawCircle(
      center,
      size.width * 0.045,
      Paint()..color = const Color(0xFF151923),
    );
  }

  @override
  bool shouldRepaint(covariant _AnalogGaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.accent != accent;
  }
}

class _TouchControls extends StatelessWidget {
  const _TouchControls({required this.game});

  final HillRiderGame game;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final desktop = MediaQuery.sizeOf(context).width >= 720;
    final mainSize = shortestSide < 600
        ? 88.0
        : desktop
        ? 122.0
        : 102.0;

    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 34 : 18,
            0,
            desktop ? 34 : 18,
            desktop ? 28 : 18,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HoldButton(
                tooltip: 'Brake',
                icon: Icons.keyboard_double_arrow_left_rounded,
                size: mainSize,
                color: const Color(0xFFFF3D81),
                onChanged: (pressed) =>
                    _setControl(RiderControl.brake, pressed),
              ),
              const Spacer(),
              ValueListenableBuilder<GameSnapshot>(
                valueListenable: game.hud,
                builder: (context, snapshot, _) {
                  return _AnalogGaugeCluster(
                    rpm: snapshot.rpmFraction,
                    boost: snapshot.boostFraction,
                    accent: _stageAccentForName(snapshot.stageName),
                    large: desktop,
                    compact: MediaQuery.sizeOf(context).width < 520,
                  );
                },
              ),
              const Spacer(),
              _HoldButton(
                tooltip: 'Gas',
                icon: Icons.keyboard_double_arrow_right_rounded,
                size: mainSize,
                color: const Color(0xFF75B843),
                onChanged: (pressed) => _setControl(RiderControl.gas, pressed),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setControl(RiderControl control, bool pressed) {
    unawaited(game.sfxService.unlock());
    game.setControl(control, pressed);
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.tooltip,
    required this.icon,
    required this.size,
    required this.color,
    required this.onChanged,
  });

  final String tooltip;
  final IconData icon;
  final double size;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final isPedal = widget.tooltip == 'Gas' || widget.tooltip == 'Brake';
    final width = isPedal ? widget.size * 1.46 : widget.size;

    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: _pressed ? 0.94 : 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(const Color(0xFF1B2332), widget.color, 0.28)!,
                    const Color(0xFF101827),
                    const Color(0xFF03050A),
                  ],
                ),
                borderRadius: BorderRadius.circular(
                  isPedal ? 18 : widget.size * 0.5,
                ),
                border: Border.all(
                  color: widget.color.withValues(alpha: _pressed ? 0.95 : 0.68),
                  width: _pressed ? 2.4 : 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(
                      alpha: _pressed ? 0.18 : 0.34,
                    ),
                    offset: Offset(0, _pressed ? 2 : 8),
                    blurRadius: _pressed ? 10 : 20,
                  ),
                  const BoxShadow(
                    color: Color(0x99000000),
                    offset: Offset(0, 8),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: SizedBox(
                width: width,
                height: widget.size,
                child: isPedal
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0x55E7FDFF),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.icon,
                                color: widget.color,
                                size: widget.size * 0.34,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                widget.tooltip.toUpperCase(),
                                style: TextStyle(
                                  color: const Color(0xFFE7FDFF),
                                  fontSize: widget.size >= 100 ? 17 : 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 14,
                            right: 16,
                            child: Row(
                              children: [
                                for (var i = 0; i < 3; i += 1)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 5),
                                    decoration: BoxDecoration(
                                      color: _pressed
                                          ? widget.color
                                          : const Color(0xFF3A465A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Icon(
                        widget.icon,
                        color: widget.color,
                        size: widget.size * 0.44,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game});

  final HillRiderGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: game.hud,
      builder: (context, snapshot, _) {
        if (snapshot.phase == RiderPhase.running) {
          return const SizedBox.shrink();
        }

        final desktop = MediaQuery.sizeOf(context).width >= 720;
        final currentStageIndex = stageDefinitions.indexWhere(
          (stage) => stage.id == game.stage.id,
        );
        final hasNextStage =
            currentStageIndex >= 0 &&
            currentStageIndex + 1 < stageDefinitions.length;

        return ColoredBox(
          color: const Color(0x99000000),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: desktop ? 560 : 420),
              child: Card(
                elevation: 12,
                color: const Color(0xEE070B13),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: Color(0x66E0B46C), width: 1.4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.all(desktop ? 32 : 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        snapshot.gameOverReason,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD166),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.phase == RiderPhase.stageComplete
                            ? 'Stage Complete!'
                            : 'Run Finished',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: desktop ? 44 : 34,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE7FDFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RunMedal(
                        distance: snapshot.distanceMeters,
                        completed: snapshot.phase == RiderPhase.stageComplete,
                      ),
                      const SizedBox(height: 18),
                      _ResultRow(
                        icon: Icons.flag_rounded,
                        label: snapshot.phase == RiderPhase.stageComplete
                            ? 'Destination'
                            : 'Distance',
                        value: snapshot.phase == RiderPhase.stageComplete
                            ? snapshot.destinationName
                            : '${snapshot.distanceMeters.floor()}m',
                      ),
                      const SizedBox(height: 8),
                      _ResultRow(
                        icon: Icons.emoji_events_rounded,
                        label: 'Best',
                        value: '${snapshot.bestDistanceMeters.floor()}m',
                      ),
                      const SizedBox(height: 8),
                      _ResultRow(
                        icon: Icons.monetization_on_rounded,
                        label: 'Coins earned',
                        value: '${snapshot.coinsThisRun}',
                      ),
                      const SizedBox(height: 8),
                      _ResultRow(
                        icon: Icons.diamond_rounded,
                        label: 'Gems earned',
                        value: '${snapshot.gemsThisRun}',
                      ),
                      const SizedBox(height: 8),
                      _ResultRow(
                        icon: Icons.star_rounded,
                        label: snapshot.stageName,
                        value: '${snapshot.stageStars}/3 stars',
                      ),
                      const SizedBox(height: 20),
                      if (snapshot.canContinueWithGem) ...[
                        GameButton(
                          label: 'Revive  -1 Gem',
                          icon: Icons.diamond_rounded,
                          color: const Color(0xFF7FD9DF),
                          primary: true,
                          onPressed: () async {
                            unawaited(game.sfxService.unlock());
                            game.sfxService.play(
                              SfxCue.fuelCollect,
                              volume: 0.5,
                            );
                            await game.continueWithGem();
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (snapshot.phase == RiderPhase.stageComplete &&
                          hasNextStage) ...[
                        GameButton(
                          label: 'Next Level',
                          icon: Icons.arrow_forward_rounded,
                          color: const Color(0xFFFFB703),
                          primary: true,
                          onPressed: () async {
                            unawaited(game.sfxService.unlock());
                            game.sfxService.play(
                              SfxCue.buttonClick,
                              volume: 0.45,
                            );
                            await game.quitToMainMenu();
                            final currentIndex = stageDefinitions.indexWhere(
                              (stage) => stage.id == game.stage.id,
                            );
                            if (currentIndex >= 0 &&
                                currentIndex + 1 < stageDefinitions.length) {
                              await game.saveService.selectStage(
                                stageDefinitions[currentIndex + 1].id,
                              );
                            }
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.of(context).pushReplacementNamed('/play');
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: GameButton(
                              label: snapshot.phase == RiderPhase.stageComplete
                                  ? 'Replay'
                                  : 'Retry',
                              icon: Icons.refresh_rounded,
                              color: const Color(0xFF75B843),
                              onPressed: () async {
                                unawaited(game.sfxService.unlock());
                                game.sfxService.play(
                                  SfxCue.buttonClick,
                                  volume: 0.45,
                                );
                                await game.retryRun();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GameButton(
                              label: 'Garage',
                              icon: Icons.garage_rounded,
                              color: const Color(0xFFE0B46C),
                              onPressed: () async {
                                unawaited(game.sfxService.unlock());
                                game.sfxService.play(
                                  SfxCue.buttonClick,
                                  volume: 0.45,
                                );
                                await game.quitToMainMenu();
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/garage');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GameButton(
                              label: 'Menu',
                              icon: Icons.home_rounded,
                              color: const Color(0xFF2EA7A0),
                              onPressed: () async {
                                unawaited(game.sfxService.unlock());
                                game.sfxService.play(
                                  SfxCue.buttonClick,
                                  volume: 0.45,
                                );
                                await game.quitToMainMenu();
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RunMedal extends StatelessWidget {
  const _RunMedal({required this.distance, required this.completed});

  final double distance;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final label = completed
        ? 'Destination Cleared'
        : distance >= 900
        ? 'Mountain Legend'
        : distance >= 450
        ? 'Summit Chaser'
        : distance >= 180
        ? 'Trail Runner'
        : 'Rookie Run';
    return Align(
      alignment: Alignment.center,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x22E0B46C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x66E0B46C)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD166),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFB703)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF92A6C5),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE7FDFF),
          ),
        ),
      ],
    );
  }
}
