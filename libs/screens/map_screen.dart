import 'package:flutter/material.dart';

import '../game/stage_definitions.dart';
import '../services/save_service.dart';
import '../services/sfx_service.dart';
import '../widgets/cartoon_background.dart';
import '../widgets/game_button.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.saveService,
    required this.sfxService,
    super.key,
  });

  final SaveService saveService;
  final SfxService sfxService;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Future<void> _selectStage(StageDefinition stage, {bool play = false}) async {
    await widget.sfxService.unlock();
    final selected = await widget.saveService.selectStage(stage.id);
    widget.sfxService.play(
      selected ? SfxCue.buttonClick : SfxCue.crash,
      volume: selected ? 0.45 : 0.16,
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    if (selected && play) {
      Navigator.of(context).pushReplacementNamed('/play');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CartoonBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 820;
              final width = constraints.maxWidth
                  .clamp(340, desktop ? 1180 : 560)
                  .toDouble();
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text('Map / Levels'),
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFFE7FDFF),
                    elevation: 0,
                    pinned: true,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Center(
                          child: _CurrencyPill(
                            coins: widget.saveService.totalCoins,
                            gems: widget.saveService.totalGems,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Center(
                      child: SizedBox(
                        width: width,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            desktop ? 28 : 18,
                            8,
                            desktop ? 28 : 18,
                            30,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MapHero(
                                saveService: widget.saveService,
                                desktop: desktop,
                              ),
                              SizedBox(height: desktop ? 20 : 14),
                              if (desktop)
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: [
                                    for (final stage in stageDefinitions)
                                      SizedBox(
                                        width: (width - 16) / 2,
                                        child: _StageCard(
                                          stage: stage,
                                          saveService: widget.saveService,
                                          desktop: desktop,
                                          onSelect: () => _selectStage(stage),
                                          onPlay: () =>
                                              _selectStage(stage, play: true),
                                        ),
                                      ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    for (final stage in stageDefinitions) ...[
                                      _StageCard(
                                        stage: stage,
                                        saveService: widget.saveService,
                                        desktop: desktop,
                                        onSelect: () => _selectStage(stage),
                                        onPlay: () =>
                                            _selectStage(stage, play: true),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({required this.saveService, required this.desktop});

  final SaveService saveService;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final selected = saveService.selectedStage;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6070B13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected.accent.withValues(alpha: 0.70),
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x77000000),
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(desktop ? 24 : 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHOOSE YOUR ROUTE',
                    style: TextStyle(
                      color: const Color(0xFFE7FDFF),
                      fontSize: desktop ? 34 : 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Finish a level to unlock the next one. Each level is longer and rougher than the last.',
                    style: TextStyle(
                      color: const Color(0xFF92A6C5),
                      fontSize: desktop ? 15 : 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Current: ${selected.name} - ${selected.goalMeters}m',
                    style: TextStyle(
                      color: selected.accent,
                      fontSize: desktop ? 18 : 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (desktop) ...[
              const SizedBox(width: 20),
              SizedBox(
                width: 190,
                child: GameButton(
                  label: 'Start',
                  icon: Icons.play_arrow_rounded,
                  color: const Color(0xFFFFB703),
                  primary: true,
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/play'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.saveService,
    required this.desktop,
    required this.onSelect,
    required this.onPlay,
  });

  final StageDefinition stage;
  final SaveService saveService;
  final bool desktop;
  final VoidCallback onSelect;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final unlocked = saveService.isStageUnlocked(stage.id);
    final selected = saveService.selectedStageId == stage.id;
    final stars = saveService.stageStars(stage.id);
    final best = saveService
        .stageBestDistance(stage.id)
        .clamp(0, stage.goalMeters)
        .toDouble();
    final progress = stage.goalMeters <= 0
        ? 0.0
        : (best / stage.goalMeters).clamp(0, 1).toDouble();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? [
                  stage.skyTop.withValues(alpha: 0.92),
                  stage.soilBottom.withValues(alpha: 0.95),
                ]
              : [const Color(0xFF1C2330), const Color(0xFF080B12)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: selected
              ? const Color(0xFFFFD166)
              : unlocked
              ? stage.accent.withValues(alpha: 0.72)
              : const Color(0x665A6476),
          width: selected ? 2.4 : 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(desktop ? 18 : 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: desktop ? 64 : 52,
                  height: desktop ? 64 : 52,
                  decoration: BoxDecoration(
                    color: const Color(0xDD070B13),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: stage.accent.withValues(alpha: 0.72),
                    ),
                  ),
                  child: Icon(
                    unlocked ? Icons.terrain_rounded : Icons.lock_rounded,
                    color: unlocked ? stage.accent : const Color(0xFF7D8798),
                    size: desktop ? 34 : 29,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stage.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFFE7FDFF),
                          fontSize: desktop ? 19 : 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        unlocked
                            ? '${stage.goalMeters}m - ${stage.difficultyLabel}'
                            : stage.unlockHint,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unlocked
                              ? const Color(0xFFC8D4E8)
                              : const Color(0xFF8A95A8),
                          fontSize: desktop ? 13 : 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              stage.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFD6E1F4),
                fontSize: desktop ? 13 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFF172033)),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [stage.accent, const Color(0xFFFFD166)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Best ${best.floor()}m',
                  style: const TextStyle(
                    color: Color(0xFFE7FDFF),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                for (var i = 0; i < 3; i += 1)
                  Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFD166),
                    size: desktop ? 22 : 19,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (unlocked)
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      label: selected ? 'Selected' : 'Select',
                      icon: selected ? Icons.check_rounded : Icons.flag_rounded,
                      color: selected ? const Color(0xFF75B843) : stage.accent,
                      onPressed: onSelect,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GameButton(
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFFFFB703),
                      primary: selected,
                      onPressed: onPlay,
                    ),
                  ),
                ],
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x99070B13),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x555A6476)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                  child: Text(
                    'LOCKED - finish the previous level',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9AA7BA),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill({required this.coins, required this.gems});

  final int coins;
  final int gems;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD070B13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x66FFD166)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xFFFFB703),
              size: 20,
            ),
            const SizedBox(width: 5),
            Text(
              '$coins',
              style: const TextStyle(
                color: Color(0xFFE7FDFF),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.diamond_rounded,
              color: Color(0xFF7FD9DF),
              size: 19,
            ),
            const SizedBox(width: 5),
            Text(
              '$gems',
              style: const TextStyle(
                color: Color(0xFFE7FDFF),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
