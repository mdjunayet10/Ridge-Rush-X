import 'package:flutter/material.dart';

enum VehicleSilhouette {
  buggy,
  jeep,
  motorbike,
  atv,
  monsterTruck,
  cargoTruck,
  desertRacer,
  rover,
}

class VehicleDefinition {
  const VehicleDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.silhouette,
    required this.unlockCost,
    required this.accent,
    required this.speed,
    required this.grip,
    required this.suspension,
    required this.stability,
    required this.mass,
    required this.wheelScale,
  });

  final String id;
  final String name;
  final String description;
  final VehicleSilhouette silhouette;
  final int unlockCost;
  final Color accent;
  final double speed;
  final double grip;
  final double suspension;
  final double stability;
  final double mass;
  final double wheelScale;
}

const starterBuggy = VehicleDefinition(
  id: 'starter_buggy',
  name: 'Starter Buggy',
  description: 'Simple open buggy with big tires and clean hill control.',
  silhouette: VehicleSilhouette.buggy,
  unlockCost: 0,
  accent: Color(0xFFE83F2F),
  speed: 1,
  grip: 1,
  suspension: 1,
  stability: 1,
  mass: 1,
  wheelScale: 1,
);

const vehicleDefinitions = <VehicleDefinition>[
  starterBuggy,
  VehicleDefinition(
    id: 'trail_jeep',
    name: 'Trail Jeep',
    description: 'Boxy jeep with steady grip and a calm climbing stance.',
    silhouette: VehicleSilhouette.jeep,
    unlockCost: 650,
    accent: Color(0xFF2E8B57),
    speed: 0.92,
    grip: 1.16,
    suspension: 1.04,
    stability: 1.16,
    mass: 1.12,
    wheelScale: 1.05,
  ),
  VehicleDefinition(
    id: 'motorbike',
    name: 'Motorbike',
    description: 'Thin frame, fast response, and a brave visible rider.',
    silhouette: VehicleSilhouette.motorbike,
    unlockCost: 900,
    accent: Color(0xFF2EA7A0),
    speed: 1.23,
    grip: 0.95,
    suspension: 1.02,
    stability: 0.78,
    mass: 0.78,
    wheelScale: 0.94,
  ),
  VehicleDefinition(
    id: 'atv_quad',
    name: 'ATV / Quad Bike',
    description: 'Compact four-wheel stance with nimble trail control.',
    silhouette: VehicleSilhouette.atv,
    unlockCost: 1400,
    accent: Color(0xFF7FAF38),
    speed: 1.04,
    grip: 1.15,
    suspension: 1.08,
    stability: 1.18,
    mass: 0.95,
    wheelScale: 0.9,
  ),
  VehicleDefinition(
    id: 'monster_truck',
    name: 'Monster Truck',
    description: 'Huge tires, lifted frame, and planted rough-road landings.',
    silhouette: VehicleSilhouette.monsterTruck,
    unlockCost: 2400,
    accent: Color(0xFFB35A32),
    speed: 0.92,
    grip: 1.3,
    suspension: 1.16,
    stability: 1.25,
    mass: 1.25,
    wheelScale: 1.26,
  ),
  VehicleDefinition(
    id: 'cargo_truck',
    name: 'Cargo Truck',
    description:
        'Long cargo bed, steady weight, and planted rough-road travel.',
    silhouette: VehicleSilhouette.cargoTruck,
    unlockCost: 3200,
    accent: Color(0xFFD17A2E),
    speed: 0.84,
    grip: 1.18,
    suspension: 1.05,
    stability: 1.3,
    mass: 1.35,
    wheelScale: 1.08,
  ),
  VehicleDefinition(
    id: 'desert_racer',
    name: 'Desert Racer',
    description: 'Long low racer with strong speed and lively balance.',
    silhouette: VehicleSilhouette.desertRacer,
    unlockCost: 4100,
    accent: Color(0xFFFFC928),
    speed: 1.18,
    grip: 0.96,
    suspension: 0.96,
    stability: 0.9,
    mass: 0.95,
    wheelScale: 0.96,
  ),
  VehicleDefinition(
    id: 'moon_rover',
    name: 'Moon Rover',
    description: 'Long suspension arms and a bouncy rough-terrain ride.',
    silhouette: VehicleSilhouette.rover,
    unlockCost: 5200,
    accent: Color(0xFF6FA8B8),
    speed: 0.98,
    grip: 1.06,
    suspension: 1.28,
    stability: 1.12,
    mass: 1.04,
    wheelScale: 1.08,
  ),
];

VehicleDefinition vehicleById(String id) {
  final normalizedId = switch (id) {
    'starter_rover' => starterBuggy.id,
    'switchback_jeep' => 'trail_jeep',
    'canyon_buggy' => starterBuggy.id,
    'neon_racer' => 'desert_racer',
    'monster_climber' => 'monster_truck',
    'quad_bike' => 'atv_quad',
    _ => id,
  };
  return vehicleDefinitions.firstWhere(
    (vehicle) => vehicle.id == normalizedId,
    orElse: () => starterBuggy,
  );
}
