import 'package:flutter/material.dart';

import '../game/stage_definitions.dart';
import '../game/vehicle_definitions.dart';
import '../services/save_service.dart';
import '../services/sfx_service.dart';
import '../widgets/buggy_preview.dart';
import '../widgets/cartoon_background.dart';
import '../widgets/game_button.dart';

class GarageScreen extends StatefulWidget {
  const GarageScreen({
    required this.saveService,
    required this.sfxService,
    super.key,
  });

  final SaveService saveService;
  final SfxService sfxService;

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  String? _lastUpgradeId;
  String? _lastVehicleId;
  String? _lastStageId;

  Future<void> _buy(UpgradeDefinition upgrade) async {
    await widget.sfxService.unlock();
    final purchased = await widget.saveService.purchaseUpgrade(upgrade);
    if (purchased) {
      widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
      _lastUpgradeId = upgrade.id;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _useVehicle(VehicleDefinition vehicle) async {
    await widget.sfxService.unlock();
    final changed = widget.saveService.isVehicleUnlocked(vehicle.id)
        ? await widget.saveService.selectVehicle(vehicle.id)
        : await widget.saveService.unlockVehicle(vehicle);
    if (changed) {
      widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
      _lastVehicleId = vehicle.id;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _buyGemTune() async {
    await widget.sfxService.unlock();
    final purchased = await widget.saveService.purchaseGemTune();
    widget.sfxService.play(
      purchased ? SfxCue.fuelCollect : SfxCue.crash,
      volume: purchased ? 0.45 : 0.18,
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _useStage(StageDefinition stage) async {
    await widget.sfxService.unlock();
    final changed = widget.saveService.isStageUnlocked(stage.id)
        ? await widget.saveService.selectStage(stage.id)
        : await widget.saveService.unlockStage(stage);
    if (changed) {
      widget.sfxService.play(SfxCue.buttonClick, volume: 0.45);
      _lastStageId = stage.id;
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CartoonBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 760;
              final width = constraints.maxWidth
                  .clamp(340, desktop ? 1100 : 560)
                  .toDouble();

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text('Garage'),
                    backgroundColor: Colors.transparent,
                    foregroundColor: const Color(0xFFE7FDFF),
                    elevation: 0,
                    pinned: true,
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
                              _GarageHeader(
                                coins: widget.saveService.totalCoins,
                                gems: widget.saveService.totalGems,
                                unlockedVehicles: vehicleDefinitions
                                    .where(
                                      (vehicle) => widget.saveService
                                          .isVehicleUnlocked(vehicle.id),
                                    )
                                    .length,
                                totalVehicles: vehicleDefinitions.length,
                                desktop: desktop,
                              ),
                              SizedBox(height: desktop ? 14 : 10),
                              _GemUsePanel(
                                saveService: widget.saveService,
                                desktop: desktop,
                                onPressed: _buyGemTune,
                              ),
                              SizedBox(height: desktop ? 20 : 14),
                              _ShowroomPanel(
                                saveService: widget.saveService,
                                desktop: desktop,
                              ),
                              SizedBox(height: desktop ? 22 : 16),
                              _StageGrid(
                                saveService: widget.saveService,
                                desktop: desktop,
                                highlightedStageId: _lastStageId,
                                onPressed: _useStage,
                              ),
                              SizedBox(height: desktop ? 22 : 16),
                              _VehicleGrid(
                                saveService: widget.saveService,
                                desktop: desktop,
                                highlightedVehicleId: _lastVehicleId,
                                onPressed: _useVehicle,
                              ),
                              SizedBox(height: desktop ? 22 : 16),
                              _UpgradeGrid(
                                saveService: widget.saveService,
                                lastUpgradeId: _lastUpgradeId,
                                desktop: desktop,
                                onBuy: _buy,
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

class _GarageHeader extends StatelessWidget {
  const _GarageHeader({
    required this.coins,
    required this.gems,
    required this.unlockedVehicles,
    required this.totalVehicles,
    required this.desktop,
  });

  final int coins;
  final int gems;
  final int unlockedVehicles;
  final int totalVehicles;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GOLDEN GARAGE',
                style: TextStyle(
                  color: const Color(0xFFE7FDFF),
                  fontSize: desktop ? 36 : 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$unlockedVehicles / $totalVehicles vehicles unlocked',
                style: TextStyle(
                  color: const Color(0xFF92A6C5),
                  fontSize: desktop ? 15 : 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xD9070B13),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66FFD166), width: 1.4),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: desktop ? 18 : 12,
              vertical: desktop ? 12 : 9,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  color: const Color(0xFFFFB703),
                  size: desktop ? 30 : 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '$coins',
                  style: TextStyle(
                    color: const Color(0xFFE7FDFF),
                    fontSize: desktop ? 24 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  Icons.diamond_rounded,
                  color: const Color(0xFF2EA7A0),
                  size: desktop ? 28 : 22,
                ),
                const SizedBox(width: 7),
                Text(
                  '$gems',
                  style: TextStyle(
                    color: const Color(0xFFE7FDFF),
                    fontSize: desktop ? 24 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GemUsePanel extends StatelessWidget {
  const _GemUsePanel({
    required this.saveService,
    required this.desktop,
    required this.onPressed,
  });

  final SaveService saveService;
  final bool desktop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canUse =
        saveService.totalGems >= 2 &&
        upgradeDefinitions.any(
          (upgrade) =>
              saveService.upgradeLevel(upgrade.id) <
              SaveService.maxUpgradeLevel,
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD9070B13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x887FD9DF), width: 1.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(desktop ? 16 : 12),
        child: Row(
          children: [
            const Icon(
              Icons.diamond_rounded,
              color: Color(0xFF7FD9DF),
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GEM USE: EMERGENCY TUNE',
                    style: TextStyle(
                      color: const Color(0xFFE7FDFF),
                      fontSize: desktop ? 16 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Spend 2 gems to upgrade your lowest vehicle part. Gems also revive you once during a run.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF92A6C5),
                      fontSize: desktop ? 12 : 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: desktop ? 150 : 118,
              child: GameButton(
                compact: true,
                label: 'Use 2 Gems',
                icon: Icons.auto_fix_high_rounded,
                color: const Color(0xFF7FD9DF),
                onPressed: canUse ? onPressed : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageGrid extends StatelessWidget {
  const _StageGrid({
    required this.saveService,
    required this.desktop,
    required this.highlightedStageId,
    required this.onPressed,
  });

  final SaveService saveService;
  final bool desktop;
  final String? highlightedStageId;
  final ValueChanged<StageDefinition> onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LEVELS',
          style: TextStyle(
            color: const Color(0xFFE7FDFF),
            fontSize: desktop ? 24 : 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: desktop ? 170 : 156,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stageDefinitions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final stage = stageDefinitions[index];
              return SizedBox(
                width: desktop ? 320 : 260,
                child: _StageCard(
                  stage: stage,
                  coins: saveService.totalCoins,
                  unlocked: saveService.isStageUnlocked(stage.id),
                  selected: saveService.selectedStageId == stage.id,
                  highlighted: highlightedStageId == stage.id,
                  stars: saveService.stageStars(stage.id),
                  onPressed: () => onPressed(stage),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.stage,
    required this.coins,
    required this.unlocked,
    required this.selected,
    required this.highlighted,
    required this.stars,
    required this.onPressed,
  });

  final StageDefinition stage;
  final int coins;
  final bool unlocked;
  final bool selected;
  final bool highlighted;
  final int stars;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canUnlock =
        !unlocked && stage.unlockCost > 0 && coins >= stage.unlockCost;
    final enabled = !selected && (unlocked || canUnlock);
    final label = selected
        ? 'Selected'
        : unlocked
        ? 'Select'
        : canUnlock
        ? 'Unlock ${stage.unlockCost}'
        : stage.unlockCost <= 0
        ? 'Finish previous'
        : 'Locked ${stage.unlockCost}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [stage.skyTop, stage.skyMid, stage.soilBottom],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected || highlighted
              ? const Color(0xFFE7FDFF)
              : stage.accent.withValues(alpha: unlocked ? 0.75 : 0.38),
          width: selected ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: stage.accent.withValues(alpha: selected ? 0.25 : 0.12),
            blurRadius: selected ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stage.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE7FDFF),
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  unlocked ? Icons.map_rounded : Icons.lock_rounded,
                  color: unlocked ? stage.accent : const Color(0xFF7D8798),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              stage.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE7FDFF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                for (var i = 0; i < 3; i += 1)
                  Icon(
                    i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFFFD166),
                    size: 21,
                  ),
                const Spacer(),
                SizedBox(
                  width: 122,
                  child: GameButton(
                    compact: true,
                    label: label,
                    icon: selected
                        ? Icons.done_rounded
                        : unlocked || canUnlock
                        ? Icons.map_rounded
                        : Icons.monetization_on_rounded,
                    color: stage.accent,
                    onPressed: enabled ? onPressed : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowroomPanel extends StatelessWidget {
  const _ShowroomPanel({required this.saveService, required this.desktop});

  final SaveService saveService;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: desktop
          ? Row(
              children: [
                Expanded(
                  flex: 6,
                  child: BuggyPreview(
                    height: 270,
                    vehicle: saveService.selectedVehicle,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _SelectedVehicleBrief(
                        vehicle: saveService.selectedVehicle,
                      ),
                      const SizedBox(height: 12),
                      _StatStack(saveService: saveService),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                BuggyPreview(height: 178, vehicle: saveService.selectedVehicle),
                const SizedBox(height: 12),
                _SelectedVehicleBrief(vehicle: saveService.selectedVehicle),
                const SizedBox(height: 12),
                _StatStack(saveService: saveService),
              ],
            ),
    );
  }
}

class _SelectedVehicleBrief extends StatelessWidget {
  const _SelectedVehicleBrief({required this.vehicle});

  final VehicleDefinition vehicle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xAA101827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: vehicle.accent.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_vehicleIconFor(vehicle), color: vehicle.accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    vehicle.name,
                    style: const TextStyle(
                      color: Color(0xFFE7FDFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              vehicle.description,
              style: const TextStyle(
                color: Color(0xFF92A6C5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _recommendedUse(vehicle),
              style: TextStyle(
                color: vehicle.accent,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _vehicleIconFor(VehicleDefinition vehicle) {
    return switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => Icons.two_wheeler_rounded,
      VehicleSilhouette.atv => Icons.sports_motorsports_rounded,
      VehicleSilhouette.cargoTruck => Icons.local_shipping_rounded,
      VehicleSilhouette.monsterTruck => Icons.fire_truck_rounded,
      _ => Icons.directions_car_filled_rounded,
    };
  }

  static String _recommendedUse(VehicleDefinition vehicle) {
    return switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => 'Best for risky jumps, weak on stability.',
      VehicleSilhouette.monsterTruck =>
        'Best for rocks, logs, and rough landings.',
      VehicleSilhouette.cargoTruck => 'Best for steady rough-road momentum.',
      VehicleSilhouette.jeep => 'Best for steady climbing and bridges.',
      VehicleSilhouette.rover => 'Best for bouncy rock gardens.',
      VehicleSilhouette.desertRacer => 'Best for speed sections and jumps.',
      _ => 'Balanced starter for learning all levels.',
    };
  }
}

class _StatStack extends StatelessWidget {
  const _StatStack({required this.saveService});

  final SaveService saveService;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatBar(
          label: 'Speed',
          value: saveService.upgradeLevel('engine'),
          color: const Color(0xFF75B843),
        ),
        const SizedBox(height: 10),
        _StatBar(
          label: 'Grip',
          value: saveService.upgradeLevel('tires'),
          color: const Color(0xFFFFD166),
        ),
        const SizedBox(height: 10),
        _StatBar(
          label: 'Shocks',
          value: saveService.upgradeLevel('suspension'),
          color: const Color(0xFFE0B46C),
        ),
        const SizedBox(height: 10),
        _StatBar(
          label: 'Fuel',
          value: saveService.upgradeLevel('fuel_tank'),
          color: const Color(0xFF2EA7A0),
        ),
        const SizedBox(height: 10),
        _StatBar(
          label: 'Stability',
          value: saveService.upgradeLevel('stability'),
          color: const Color(0xFF7FD9DF),
        ),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFE7FDFF),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 16,
              child: ColoredBox(
                color: const Color(0xFF172033),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value / SaveService.maxUpgradeLevel,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, const Color(0xFFE7FDFF)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VehicleGrid extends StatelessWidget {
  const _VehicleGrid({
    required this.saveService,
    required this.desktop,
    required this.highlightedVehicleId,
    required this.onPressed,
  });

  final SaveService saveService;
  final bool desktop;
  final String? highlightedVehicleId;
  final ValueChanged<VehicleDefinition> onPressed;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(340.0, 1100.0);
    final cardWidth = desktop ? (width - 82) / 2 : double.infinity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'VEHICLES',
          style: TextStyle(
            color: const Color(0xFFE7FDFF),
            fontSize: desktop ? 24 : 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: desktop ? 16 : 0,
          runSpacing: 14,
          children: [
            for (final vehicle in vehicleDefinitions)
              SizedBox(
                width: cardWidth,
                child: _VehicleCard(
                  vehicle: vehicle,
                  coins: saveService.totalCoins,
                  unlocked: saveService.isVehicleUnlocked(vehicle.id),
                  selected: saveService.selectedVehicleId == vehicle.id,
                  highlighted: highlightedVehicleId == vehicle.id,
                  onPressed: () => onPressed(vehicle),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.coins,
    required this.unlocked,
    required this.selected,
    required this.highlighted,
    required this.onPressed,
  });

  final VehicleDefinition vehicle;
  final int coins;
  final bool unlocked;
  final bool selected;
  final bool highlighted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canUnlock = !unlocked && coins >= vehicle.unlockCost;
    final enabled = !selected && (unlocked || canUnlock);
    final label = selected
        ? 'Selected'
        : unlocked
        ? 'Select'
        : canUnlock
        ? 'Unlock  ${vehicle.unlockCost}'
        : 'Locked  ${vehicle.unlockCost}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [
                  vehicle.accent.withValues(alpha: 0.34),
                  const Color(0xF2070B13),
                  const Color(0xE6070B13),
                ]
              : const [Color(0xEE101827), Color(0xE6070B13), Color(0xDD05070C)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected || highlighted
              ? const Color(0xFFE7FDFF)
              : vehicle.accent.withValues(alpha: unlocked ? 0.68 : 0.32),
          width: selected ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: vehicle.accent.withValues(alpha: selected ? 0.25 : 0.12),
            blurRadius: selected ? 24 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                BuggyPreview(height: 132, vehicle: vehicle, animated: selected),
                Positioned(
                  left: 0,
                  top: 0,
                  child: _VehicleTag(
                    text: selected
                        ? 'ACTIVE'
                        : unlocked
                        ? 'READY'
                        : 'LOCKED',
                    color: selected
                        ? const Color(0xFFE7FDFF)
                        : unlocked
                        ? vehicle.accent
                        : const Color(0xFF7D8798),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    vehicle.name,
                    style: const TextStyle(
                      color: Color(0xFFE7FDFF),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                  color: unlocked ? vehicle.accent : const Color(0xFF7D8798),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              vehicle.description,
              style: const TextStyle(
                color: Color(0xFF92A6C5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (!unlocked)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(
                  value: vehicle.unlockCost == 0
                      ? 1
                      : (coins / vehicle.unlockCost).clamp(0, 1).toDouble(),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: const Color(0xFF101827),
                  color: canUnlock ? vehicle.accent : const Color(0xFF495A73),
                ),
              ),
            _VehicleStats(vehicle: vehicle),
            const SizedBox(height: 14),
            GameButton(
              compact: true,
              label: label,
              icon: selected
                  ? Icons.done_rounded
                  : unlocked || canUnlock
                  ? _vehicleIcon(vehicle)
                  : Icons.monetization_on_rounded,
              color: vehicle.accent,
              onPressed: enabled ? onPressed : null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _vehicleIcon(VehicleDefinition vehicle) {
    return switch (vehicle.silhouette) {
      VehicleSilhouette.motorbike => Icons.two_wheeler_rounded,
      VehicleSilhouette.atv => Icons.sports_motorsports_rounded,
      VehicleSilhouette.cargoTruck => Icons.local_shipping_rounded,
      VehicleSilhouette.monsterTruck => Icons.fire_truck_rounded,
      _ => Icons.directions_car_filled_rounded,
    };
  }
}

class _VehicleTag extends StatelessWidget {
  const _VehicleTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD070B13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.75)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _VehicleStats extends StatelessWidget {
  const _VehicleStats({required this.vehicle});

  final VehicleDefinition vehicle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(label: 'SPD', value: vehicle.speed),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(label: 'GRIP', value: vehicle.grip),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniStat(label: 'STAB', value: vehicle.stability),
        ),
        const SizedBox(width: 8),
        Expanded(child: _MiniStat(label: 'FUEL', value: 1.0)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x3349D9FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF92A6C5),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '${(value * 100).round()}',
              style: const TextStyle(
                color: Color(0xFFE7FDFF),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeGrid extends StatelessWidget {
  const _UpgradeGrid({
    required this.saveService,
    required this.lastUpgradeId,
    required this.desktop,
    required this.onBuy,
  });

  final SaveService saveService;
  final String? lastUpgradeId;
  final bool desktop;
  final ValueChanged<UpgradeDefinition> onBuy;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(
      context,
    ).width.clamp(340.0, 1100.0).toDouble();
    final cardWidth = desktop ? (availableWidth - 72) / 2 : double.infinity;

    return Wrap(
      spacing: desktop ? 16 : 0,
      runSpacing: 14,
      children: [
        for (final upgrade in upgradeDefinitions)
          SizedBox(
            width: cardWidth,
            child: _UpgradeCard(
              upgrade: upgrade,
              level: saveService.upgradeLevel(upgrade.id),
              cost: saveService.upgradeCost(upgrade),
              coins: saveService.totalCoins,
              highlighted: lastUpgradeId == upgrade.id,
              onBuy: () => onBuy(upgrade),
            ),
          ),
      ],
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgrade,
    required this.level,
    required this.cost,
    required this.coins,
    required this.highlighted,
    required this.onBuy,
  });

  final UpgradeDefinition upgrade;
  final int level;
  final int cost;
  final int coins;
  final bool highlighted;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final isMaxed = level >= SaveService.maxUpgradeLevel;
    final canBuy = !isMaxed && coins >= cost;
    final accent = _accentFor(upgrade.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isMaxed
            ? const Color(0xEE0B2B32)
            : canBuy
            ? const Color(0xEE070B13)
            : const Color(0xDD101827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: highlighted
              ? const Color(0xFFE7FDFF)
              : canBuy
              ? accent.withValues(alpha: 0.65)
              : const Color(0x33495A73),
          width: highlighted ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: highlighted ? 0.28 : 0.12),
            blurRadius: highlighted ? 28 : 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _UpgradeIcon(id: upgrade.id, color: accent),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upgrade.title,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE7FDFF),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        upgrade.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF92A6C5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LevelBar(level: level, color: accent),
            const SizedBox(height: 14),
            GameButton(
              compact: true,
              label: isMaxed
                  ? 'Maxed'
                  : canBuy
                  ? 'Upgrade  $cost'
                  : 'Need  $cost',
              icon: isMaxed
                  ? Icons.check_circle_rounded
                  : canBuy
                  ? Icons.arrow_upward_rounded
                  : Icons.lock_rounded,
              color: isMaxed ? const Color(0xFF75B843) : accent,
              onPressed: canBuy ? onBuy : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _accentFor(String id) {
    return switch (id) {
      'engine' => const Color(0xFF75B843),
      'tires' => const Color(0xFFFFD166),
      'suspension' => const Color(0xFFE0B46C),
      'stability' => const Color(0xFF7FD9DF),
      _ => const Color(0xFF2EA7A0),
    };
  }
}

class _UpgradeIcon extends StatelessWidget {
  const _UpgradeIcon({required this.id, required this.color});

  final String id;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (id) {
      'engine' => Icons.bolt_rounded,
      'tires' => Icons.album_rounded,
      'suspension' => Icons.vertical_align_center_rounded,
      'stability' => Icons.balance_rounded,
      _ => Icons.local_gas_station_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= SaveService.maxUpgradeLevel; i += 1)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == SaveService.maxUpgradeLevel ? 0 : 5,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i <= level ? color : const Color(0xFF2D394E),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: i <= level
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: const SizedBox(height: 13),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xDD070B13),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x66E0B46C), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0B46C).withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }
}
