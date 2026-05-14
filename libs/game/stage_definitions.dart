import 'package:flutter/material.dart';

class StageLevelDefinition {
  const StageLevelDefinition({
    required this.name,
    required this.startMeters,
    required this.endMeters,
    required this.description,
  });

  final String name;
  final int startMeters;
  final int endMeters;
  final String description;
}

class StageDefinition {
  const StageDefinition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
    required this.unlockCost,
    required this.accent,
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.hillBack,
    required this.hillMid,
    required this.hillFront,
    required this.soilTop,
    required this.soilBottom,
    required this.roadLip,
    required this.goalMeters,
    required this.levels,
    required this.difficultyLabel,
    required this.unlockHint,
  });

  final String id;
  final String name;
  final String shortName;
  final String description;
  final int unlockCost;
  final Color accent;
  final Color skyTop;
  final Color skyMid;
  final Color skyBottom;
  final Color hillBack;
  final Color hillMid;
  final Color hillFront;
  final Color soilTop;
  final Color soilBottom;
  final Color roadLip;
  final int goalMeters;
  final List<StageLevelDefinition> levels;
  final String difficultyLabel;
  final String unlockHint;

  int get levelNumber =>
      stageDefinitions.indexWhere((stage) => stage.id == id) + 1;

  List<int> get starGoals => [
    (goalMeters * 0.38).round(),
    (goalMeters * 0.72).round(),
    goalMeters,
  ];

  StageLevelDefinition levelForDistance(double meters) {
    for (final level in levels) {
      if (meters >= level.startMeters && meters < level.endMeters) {
        return level;
      }
    }
    return levels.isEmpty
        ? StageLevelDefinition(
            name: name,
            startMeters: 0,
            endMeters: goalMeters,
            description: description,
          )
        : levels.last;
  }

  int levelIndexForDistance(double meters) {
    for (var i = 0; i < levels.length; i += 1) {
      final level = levels[i];
      if (meters >= level.startMeters && meters < level.endMeters) {
        return i;
      }
    }
    return levels.isEmpty ? 0 : levels.length - 1;
  }
}

const defaultStage = StageDefinition(
  id: 'golden_mountain',
  name: 'Level 1: Rolling Canyon Road',
  shortName: 'Rolling Canyon',
  description:
      'Original canyon training stage with smooth rolling hills, small bumps, sharp crests, a rope bridge, fair fuel cans, and balance-based difficulty.',
  unlockCost: 0,
  accent: Color(0xFFFFB703),
  skyTop: Color(0xFFFFB15F),
  skyMid: Color(0xFFF1C27B),
  skyBottom: Color(0xFFC67D4D),
  hillBack: Color(0xFF9A714D),
  hillMid: Color(0xFF76513C),
  hillFront: Color(0xFF543B31),
  soilTop: Color(0xFF6A4128),
  soilBottom: Color(0xFF271B17),
  roadLip: Color(0xFFE0B46C),
  goalMeters: 1600,
  difficultyLabel: 'Starter road grammar',
  unlockHint: 'Unlocked from the start',
  levels: [
    StageLevelDefinition(
      name: 'Training Rollers',
      startMeters: 0,
      endMeters: 270,
      description:
          'Small bumps, shallow dips, and coin lines teach throttle rhythm.',
    ),
    StageLevelDefinition(
      name: 'First High Hill',
      startMeters: 270,
      endMeters: 620,
      description:
          'Build speed before a tall climb, sharp crest, and controlled drop.',
    ),
    StageLevelDefinition(
      name: 'Wood Bridge Valley',
      startMeters: 620,
      endMeters: 930,
      description:
          'Cross rope planks, land in a valley, and recover the nose angle.',
    ),
    StageLevelDefinition(
      name: 'Ridge Ramp',
      startMeters: 930,
      endMeters: 1260,
      description:
          'A short ramp and uneven landing test gas/brake air balance.',
    ),
    StageLevelDefinition(
      name: 'Canyon Gate Climb',
      startMeters: 1260,
      endMeters: 1600,
      description:
          'Final climb with enough fuel, but bad balance can still flip you.',
    ),
  ],
);

const stageDefinitions = <StageDefinition>[
  defaultStage,
  StageDefinition(
    id: 'broken_bridge',
    name: 'Level 2: Seasonal Bridge Valley',
    shortName: 'Seasonal Valley',
    description:
        '2400m route with spring pools, mud sections, winter ice, rope bridges, bowls, and balance-heavy fuel pickups.',
    unlockCost: 0,
    accent: Color(0xFF8CFBFF),
    skyTop: Color(0xFF102B4A),
    skyMid: Color(0xFF245D7A),
    skyBottom: Color(0xFF6BBFD6),
    hillBack: Color(0xFF386983),
    hillMid: Color(0xFF27536C),
    hillFront: Color(0xFF1F4055),
    soilTop: Color(0xFF3F5364),
    soilBottom: Color(0xFF1A2630),
    roadLip: Color(0xFF8CFBFF),
    goalMeters: 2400,
    difficultyLabel: 'Surface control',
    unlockHint: 'Reach the Level 1 finish arch',
    levels: [
      StageLevelDefinition(
        name: 'Fast Rollers',
        startMeters: 0,
        endMeters: 420,
        description: 'Faster rollers make the car pitch back and forward.',
      ),
      StageLevelDefinition(
        name: 'Rope Span',
        startMeters: 420,
        endMeters: 890,
        description: 'Rope bridge, sagging planks, and bowl landing recovery.',
      ),
      StageLevelDefinition(
        name: 'Winter Crests',
        startMeters: 890,
        endMeters: 1390,
        description: 'Slippery crests punish holding gas blindly.',
      ),
      StageLevelDefinition(
        name: 'Mud Rollers',
        startMeters: 1390,
        endMeters: 1900,
        description: 'Mud rollers force brake/gas control before a climb.',
      ),
      StageLevelDefinition(
        name: 'Camp Gate',
        startMeters: 1900,
        endMeters: 2400,
        description:
            'Long climb with fair fuel, but the can sits on a risky line.',
      ),
    ],
  ),
  StageDefinition(
    id: 'high_dunes',
    name: 'Level 3: Sun Dunes',
    shortName: 'Sun Dunes',
    description:
        '3300m desert stage with soft sand drag, smooth dune chains, long ramps, bowl landings, and high-air recovery.',
    unlockCost: 0,
    accent: Color(0xFFFFB703),
    skyTop: Color(0xFF65406A),
    skyMid: Color(0xFFC36A4B),
    skyBottom: Color(0xFFFFB15F),
    hillBack: Color(0xFFC1834C),
    hillMid: Color(0xFF9B6137),
    hillFront: Color(0xFF70442B),
    soilTop: Color(0xFF8A5732),
    soilBottom: Color(0xFF332017),
    roadLip: Color(0xFFFFD166),
    goalMeters: 3300,
    difficultyLabel: 'Long climb',
    unlockHint: 'Complete Seasonal Valley Valley',
    levels: [
      StageLevelDefinition(
        name: 'Sandy Warmup',
        startMeters: 0,
        endMeters: 570,
        description: 'Wide soft dunes need momentum without over-rotating.',
      ),
      StageLevelDefinition(
        name: 'Mud Bowl',
        startMeters: 570,
        endMeters: 1250,
        description: 'Soft sand bowl drains speed before a tall dune climb.',
      ),
      StageLevelDefinition(
        name: 'High Dune',
        startMeters: 1250,
        endMeters: 1940,
        description:
            'Momentum climb with coins in the jump path, not on flat ground.',
      ),
      StageLevelDefinition(
        name: 'Double Ramp',
        startMeters: 1940,
        endMeters: 2620,
        description: 'Double ramp chain with uneven landing zones.',
      ),
      StageLevelDefinition(
        name: 'Tower Finish',
        startMeters: 2620,
        endMeters: 3300,
        description:
            'Fuel is reachable, but the final dune tests balance and speed.',
      ),
    ],
  ),
  StageDefinition(
    id: 'rocky_peaks',
    name: 'Level 4: Frosted Mountain Pass',
    shortName: 'Frosted Pass',
    description:
        '4300m mountain route with slippery snow, bumpy rock sections, narrow bridges, and steep late climbs.',
    unlockCost: 0,
    accent: Color(0xFF75B843),
    skyTop: Color(0xFF536E8C),
    skyMid: Color(0xFFD09E65),
    skyBottom: Color(0xFFE3B66A),
    hillBack: Color(0xFF6B7350),
    hillMid: Color(0xFF56523C),
    hillFront: Color(0xFF3D342A),
    soilTop: Color(0xFF5E4731),
    soilBottom: Color(0xFF201813),
    roadLip: Color(0xFFD7B46A),
    goalMeters: 4300,
    difficultyLabel: 'Slippery climbs',
    unlockHint: 'Complete Sun Dunes',
    levels: [
      StageLevelDefinition(
        name: 'Rocky Warmup',
        startMeters: 0,
        endMeters: 760,
        description: 'Small rocks introduce suspension shake and grip loss.',
      ),
      StageLevelDefinition(
        name: 'Peak Climb',
        startMeters: 760,
        endMeters: 1630,
        description:
            'Long high climb plus a low roof punishes big uncontrolled jumps.',
      ),
      StageLevelDefinition(
        name: 'Step Garden',
        startMeters: 1630,
        endMeters: 2510,
        description:
            'Uneven rock steps shake the suspension and pitch the car.',
      ),
      StageLevelDefinition(
        name: 'Narrow Bridges',
        startMeters: 2510,
        endMeters: 3380,
        description: 'Narrow bridges, low cave roof, and recovery drops.',
      ),
      StageLevelDefinition(
        name: 'Summit Gate',
        startMeters: 3380,
        endMeters: 4300,
        description: 'Summit climb with rocks, fair fuel, and flip danger.',
      ),
    ],
  ),
  StageDefinition(
    id: 'storm_canyon',
    name: 'Level 5: Canyon Highway Trial',
    shortName: 'Canyon Highway',
    description:
        '5600m expert speed-and-control route with flatter early driving, widening distance pressure, late steep hills, bridges, mud, and demanding physics control.',
    unlockCost: 0,
    accent: Color(0xFF7FD9DF),
    skyTop: Color(0xFF1B263B),
    skyMid: Color(0xFF415A77),
    skyBottom: Color(0xFFB07D62),
    hillBack: Color(0xFF394D5F),
    hillMid: Color(0xFF2D3A4A),
    hillFront: Color(0xFF232A36),
    soilTop: Color(0xFF4A3A35),
    soilBottom: Color(0xFF14171D),
    roadLip: Color(0xFF9FE7ED),
    goalMeters: 5600,
    difficultyLabel: 'Speed endurance',
    unlockHint: 'Complete Rocky Mountain Pass',
    levels: [
      StageLevelDefinition(
        name: 'Storm Run',
        startMeters: 0,
        endMeters: 980,
        description: 'Fast rollers demand constant nose control.',
      ),
      StageLevelDefinition(
        name: 'Deep Cut',
        startMeters: 980,
        endMeters: 2120,
        description: 'Deep valley drop: land flat or lose all momentum.',
      ),
      StageLevelDefinition(
        name: 'Long Bridge Run',
        startMeters: 2120,
        endMeters: 3320,
        description: 'Long rope bridges with risky coin and gem arcs.',
      ),
      StageLevelDefinition(
        name: 'Rock Storm',
        startMeters: 3320,
        endMeters: 4460,
        description: 'Hard rock garden, mud, and high-speed landing control.',
      ),
      StageLevelDefinition(
        name: 'Final Overpass',
        startMeters: 4460,
        endMeters: 5600,
        description:
            'Hardest climb, tight tunnel section, and final destination gate.',
      ),
    ],
  ),
];

StageDefinition stageById(String id) {
  final normalizedId = switch (id) {
    'neon_ridge' => defaultStage.id,
    'crystal_canyon' => 'broken_bridge',
    'sunset_dunes' => 'high_dunes',
    _ => id,
  };
  return stageDefinitions.firstWhere(
    (stage) => stage.id == normalizedId,
    orElse: () => defaultStage,
  );
}
