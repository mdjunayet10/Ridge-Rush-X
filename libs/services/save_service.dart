import 'package:shared_preferences/shared_preferences.dart';

import '../game/stage_definitions.dart';
import '../game/vehicle_definitions.dart';

class UpgradeDefinition {
  const UpgradeDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.baseCost,
  });

  final String id;
  final String title;
  final String description;
  final int baseCost;
}

const upgradeDefinitions = <UpgradeDefinition>[
  UpgradeDefinition(
    id: 'engine',
    title: 'Engine Core',
    description: 'More torque for steep canyon climbs.',
    baseCost: 35,
  ),
  UpgradeDefinition(
    id: 'tires',
    title: 'Grip Tires',
    description: 'Chunkier bite on dusty mountain rock.',
    baseCost: 30,
  ),
  UpgradeDefinition(
    id: 'suspension',
    title: 'Shock System',
    description: 'Softer bounce and cleaner landings.',
    baseCost: 30,
  ),
  UpgradeDefinition(
    id: 'fuel_tank',
    title: 'Fuel Tank',
    description: 'Longer runs between fuel cans.',
    baseCost: 40,
  ),
  UpgradeDefinition(
    id: 'stability',
    title: 'Stability Link',
    description: 'Less backward flip and cleaner air recovery.',
    baseCost: 45,
  ),
];

class SaveService {
  static const int maxUpgradeLevel = 5;

  static const _coinsKey = 'total_coins';
  static const _gemsKey = 'total_gems';
  static const _bestDistanceKey = 'best_distance_meters';
  static const _soundEffectsEnabledKey = 'sound_effects_enabled';
  static const _legacySoundEnabledKey = 'sound_enabled';
  static const _leanControlsKey = 'lean_controls_enabled';
  static const _performanceModeKey = 'performance_mode_enabled';
  static const _performanceModeRebalancedKey = 'performance_mode_rebalanced_v2';
  static const _completedRunsKey = 'completed_runs';
  static const _selectedVehicleKey = 'selected_vehicle';
  static const _unlockedVehiclesKey = 'unlocked_vehicles';
  static const _selectedStageKey = 'selected_stage';
  static const _unlockedStagesKey = 'unlocked_stages';
  static const _accountSignedInKey = 'account_signed_in';
  static const _accountNameKey = 'account_name';
  static const _accountEmailKey = 'account_email';
  static const _accountPasswordKey = 'account_password';

  late final SharedPreferences _prefs;

  int _totalCoins = 0;
  int _totalGems = 0;
  double _bestDistanceMeters = 0;
  bool _soundEffectsEnabled = true;
  bool _leanControlsEnabled = true;
  bool _performanceModeEnabled = false;
  int _completedRuns = 0;
  String _selectedVehicleId = starterBuggy.id;
  String _selectedStageId = defaultStage.id;
  bool _accountSignedIn = false;
  String _accountName = '';
  String _accountEmail = '';
  final Set<String> _unlockedVehicleIds = {starterBuggy.id};
  final Set<String> _unlockedStageIds = {defaultStage.id};
  final Map<String, int> _upgradeLevels = {
    for (final upgrade in upgradeDefinitions) upgrade.id: 1,
  };

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _totalCoins = _prefs.getInt(_coinsKey) ?? 0;
    _totalGems = _prefs.getInt(_gemsKey) ?? 0;
    _bestDistanceMeters = _prefs.getDouble(_bestDistanceKey) ?? 0;
    _soundEffectsEnabled =
        _prefs.getBool(_soundEffectsEnabledKey) ??
        _prefs.getBool(_legacySoundEnabledKey) ??
        true;
    _leanControlsEnabled = _prefs.getBool(_leanControlsKey) ?? true;
    final performanceModeMigrated =
        _prefs.getBool(_performanceModeRebalancedKey) ?? false;
    if (!performanceModeMigrated) {
      _performanceModeEnabled = false;
      await _prefs.setBool(_performanceModeKey, false);
      await _prefs.setBool(_performanceModeRebalancedKey, true);
    } else {
      _performanceModeEnabled = _prefs.getBool(_performanceModeKey) ?? false;
    }
    _completedRuns = _prefs.getInt(_completedRunsKey) ?? 0;
    _accountSignedIn = _prefs.getBool(_accountSignedInKey) ?? false;
    _accountName = _prefs.getString(_accountNameKey) ?? '';
    _accountEmail = _prefs.getString(_accountEmailKey) ?? '';

    _selectedVehicleId = _normalizeVehicleId(
      _prefs.getString(_selectedVehicleKey) ?? starterBuggy.id,
    );
    _unlockedVehicleIds
      ..clear()
      ..addAll(
        (_prefs.getStringList(_unlockedVehiclesKey) ?? const []).map(
          _normalizeVehicleId,
        ),
      )
      ..add(starterBuggy.id);
    if (!_unlockedVehicleIds.contains(_selectedVehicleId)) {
      _selectedVehicleId = starterBuggy.id;
    }

    _selectedStageId = _normalizeStageId(
      _prefs.getString(_selectedStageKey) ?? defaultStage.id,
    );
    _unlockedStageIds
      ..clear()
      ..addAll(
        (_prefs.getStringList(_unlockedStagesKey) ?? const []).map(
          _normalizeStageId,
        ),
      )
      ..add(defaultStage.id);
    _restoreSequentialUnlocksFromCompletedStages();
    if (!_unlockedStageIds.contains(_selectedStageId)) {
      _selectedStageId = _highestUnlockedStage.id;
    }

    for (final upgrade in upgradeDefinitions) {
      _upgradeLevels[upgrade.id] = (_prefs.getInt(_upgradeKey(upgrade.id)) ?? 1)
          .clamp(1, maxUpgradeLevel)
          .toInt();
    }
  }

  int get totalCoins => _totalCoins;
  int get totalGems => _totalGems;
  double get bestDistanceMeters => _bestDistanceMeters;
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  bool get leanControlsEnabled => _leanControlsEnabled;
  bool get performanceModeEnabled => _performanceModeEnabled;
  int get completedRuns => _completedRuns;
  bool get isSignedIn => _accountSignedIn && _accountEmail.isNotEmpty;

  String get accountDisplayName {
    if (!isSignedIn) {
      return '';
    }
    if (_accountName.trim().isNotEmpty) {
      return _accountName.trim();
    }
    return _accountEmail.split('@').first;
  }

  String get accountEmail => isSignedIn ? _accountEmail : '';
  String get selectedVehicleId => _selectedVehicleId;
  VehicleDefinition get selectedVehicle => vehicleById(_selectedVehicleId);
  String get selectedStageId => _selectedStageId;
  StageDefinition get selectedStage => stageById(_selectedStageId);

  StageDefinition get _highestUnlockedStage {
    var highest = defaultStage;
    for (final stage in stageDefinitions) {
      if (isStageUnlocked(stage.id)) {
        highest = stage;
      }
    }
    return highest;
  }

  int get highestUnlockedStageNumber => _highestUnlockedStage.levelNumber;

  double stageBestDistance(String id) =>
      _prefs.getDouble(_stageBestDistanceKey(_normalizeStageId(id))) ?? 0;

  bool isVehicleUnlocked(String id) =>
      _unlockedVehicleIds.contains(_normalizeVehicleId(id));

  bool isStageUnlocked(String id) =>
      _unlockedStageIds.contains(_normalizeStageId(id));

  int stageStars(String id) =>
      _prefs.getInt(_stageStarsKey(_normalizeStageId(id))) ?? 0;

  bool isStageComplete(String id) => stageStars(id) >= 3;

  int upgradeLevel(String id) => _upgradeLevels[id] ?? 1;

  int upgradeCost(UpgradeDefinition upgrade) {
    final level = upgradeLevel(upgrade.id);
    if (level >= maxUpgradeLevel) {
      return 0;
    }
    return upgrade.baseCost * level;
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) {
      return;
    }
    _totalCoins += amount;
    await _prefs.setInt(_coinsKey, _totalCoins);
  }

  Future<void> addGems(int amount) async {
    if (amount <= 0) {
      return;
    }
    _totalGems += amount;
    await _prefs.setInt(_gemsKey, _totalGems);
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    if (cleanName.length < 2 ||
        !cleanEmail.contains('@') ||
        cleanPassword.length < 4) {
      return false;
    }

    _accountName = cleanName;
    _accountEmail = cleanEmail;
    _accountSignedIn = true;
    await Future.wait([
      _prefs.setString(_accountNameKey, _accountName),
      _prefs.setString(_accountEmailKey, _accountEmail),
      _prefs.setString(_accountPasswordKey, cleanPassword),
      _prefs.setBool(_accountSignedInKey, true),
    ]);
    return true;
  }

  Future<bool> signIn({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final savedEmail = (_prefs.getString(_accountEmailKey) ?? '')
        .trim()
        .toLowerCase();
    final savedPassword = _prefs.getString(_accountPasswordKey) ?? '';
    if (savedEmail.isEmpty ||
        cleanEmail != savedEmail ||
        cleanPassword != savedPassword) {
      return false;
    }

    _accountEmail = savedEmail;
    _accountName =
        _prefs.getString(_accountNameKey) ?? savedEmail.split('@').first;
    _accountSignedIn = true;
    await _prefs.setBool(_accountSignedInKey, true);
    return true;
  }

  Future<void> signOut() async {
    _accountSignedIn = false;
    await _prefs.setBool(_accountSignedInKey, false);
  }

  Future<bool> spendGems(int amount) async {
    if (amount <= 0 || _totalGems < amount) {
      return false;
    }
    _totalGems -= amount;
    await _prefs.setInt(_gemsKey, _totalGems);
    return true;
  }

  Future<void> completeRun({
    required double distanceMeters,
    required int coinsEarned,
    required int gemsEarned,
    required String stageId,
    required int stars,
  }) async {
    _completedRuns += 1;
    if (coinsEarned > 0) {
      _totalCoins += coinsEarned;
    }
    if (gemsEarned > 0) {
      _totalGems += gemsEarned;
    }
    if (distanceMeters > _bestDistanceMeters) {
      _bestDistanceMeters = distanceMeters;
    }

    final normalizedStageId = _normalizeStageId(stageId);
    final oldStageBest = stageBestDistance(normalizedStageId);
    final clampedStars = stars.clamp(0, 3).toInt();
    final writes = <Future<bool>>[
      _prefs.setInt(_completedRunsKey, _completedRuns),
      _prefs.setInt(_coinsKey, _totalCoins),
      _prefs.setInt(_gemsKey, _totalGems),
      _prefs.setDouble(_bestDistanceKey, _bestDistanceMeters),
    ];

    if (distanceMeters > oldStageBest) {
      writes.add(
        _prefs.setDouble(
          _stageBestDistanceKey(normalizedStageId),
          distanceMeters,
        ),
      );
    }
    if (clampedStars > stageStars(normalizedStageId)) {
      writes.add(
        _prefs.setInt(_stageStarsKey(normalizedStageId), clampedStars),
      );
    }

    if (clampedStars >= 3) {
      final stageIndex = stageDefinitions.indexWhere(
        (stage) => stage.id == normalizedStageId,
      );
      if (stageIndex >= 0 && stageIndex + 1 < stageDefinitions.length) {
        final nextStageId = stageDefinitions[stageIndex + 1].id;
        _unlockedStageIds.add(nextStageId);
        _selectedStageId = nextStageId;
        writes.add(_prefs.setString(_selectedStageKey, _selectedStageId));
        writes.add(
          _prefs.setStringList(_unlockedStagesKey, _unlockedStageIds.toList()),
        );
      }
    }

    await Future.wait(writes);
  }

  Future<void> saveBestDistance(double distanceMeters) async {
    if (distanceMeters <= _bestDistanceMeters) {
      return;
    }
    _bestDistanceMeters = distanceMeters;
    await _prefs.setDouble(_bestDistanceKey, _bestDistanceMeters);
  }

  Future<bool> purchaseGemTune() async {
    if (_totalGems < 2) {
      return false;
    }

    UpgradeDefinition? target;
    for (final upgrade in upgradeDefinitions) {
      if (upgradeLevel(upgrade.id) >= maxUpgradeLevel) {
        continue;
      }
      if (target == null ||
          upgradeLevel(upgrade.id) < upgradeLevel(target.id)) {
        target = upgrade;
      }
    }

    if (target == null) {
      return false;
    }

    _totalGems -= 2;
    final nextLevel = upgradeLevel(target.id) + 1;
    _upgradeLevels[target.id] = nextLevel;
    await Future.wait([
      _prefs.setInt(_gemsKey, _totalGems),
      _prefs.setInt(_upgradeKey(target.id), nextLevel),
    ]);
    return true;
  }

  Future<bool> purchaseUpgrade(UpgradeDefinition upgrade) async {
    final level = upgradeLevel(upgrade.id);
    if (level >= maxUpgradeLevel) {
      return false;
    }

    final cost = upgradeCost(upgrade);
    if (_totalCoins < cost) {
      return false;
    }

    _totalCoins -= cost;
    _upgradeLevels[upgrade.id] = level + 1;
    await Future.wait([
      _prefs.setInt(_coinsKey, _totalCoins),
      _prefs.setInt(_upgradeKey(upgrade.id), level + 1),
    ]);
    return true;
  }

  Future<bool> unlockVehicle(VehicleDefinition vehicle) async {
    if (isVehicleUnlocked(vehicle.id)) {
      return selectVehicle(vehicle.id);
    }
    if (_totalCoins < vehicle.unlockCost) {
      return false;
    }

    _totalCoins -= vehicle.unlockCost;
    _unlockedVehicleIds.add(_normalizeVehicleId(vehicle.id));
    _selectedVehicleId = _normalizeVehicleId(vehicle.id);
    await Future.wait([
      _prefs.setInt(_coinsKey, _totalCoins),
      _prefs.setStringList(_unlockedVehiclesKey, _unlockedVehicleIds.toList()),
      _prefs.setString(_selectedVehicleKey, _selectedVehicleId),
    ]);
    return true;
  }

  Future<bool> selectVehicle(String id) async {
    final normalizedId = _normalizeVehicleId(id);
    if (!isVehicleUnlocked(normalizedId)) {
      return false;
    }
    _selectedVehicleId = normalizedId;
    await _prefs.setString(_selectedVehicleKey, _selectedVehicleId);
    return true;
  }

  Future<bool> unlockStage(StageDefinition stage) async {
    if (isStageUnlocked(stage.id)) {
      return selectStage(stage.id);
    }
    if (stage.unlockCost <= 0 || _totalCoins < stage.unlockCost) {
      return false;
    }

    _totalCoins -= stage.unlockCost;
    _unlockedStageIds.add(_normalizeStageId(stage.id));
    _selectedStageId = _normalizeStageId(stage.id);
    await Future.wait([
      _prefs.setInt(_coinsKey, _totalCoins),
      _prefs.setStringList(_unlockedStagesKey, _unlockedStageIds.toList()),
      _prefs.setString(_selectedStageKey, _selectedStageId),
    ]);
    return true;
  }

  Future<bool> selectStage(String id) async {
    final normalizedId = _normalizeStageId(id);
    if (!isStageUnlocked(normalizedId)) {
      return false;
    }
    _selectedStageId = normalizedId;
    await _prefs.setString(_selectedStageKey, _selectedStageId);
    return true;
  }

  Future<void> saveStageStars(String id, int stars) async {
    final clampedStars = stars.clamp(0, 3).toInt();
    final normalizedId = _normalizeStageId(id);
    if (clampedStars <= stageStars(normalizedId)) {
      return;
    }
    await _prefs.setInt(_stageStarsKey(normalizedId), clampedStars);
  }

  Future<void> setSoundEffectsEnabled(bool enabled) async {
    _soundEffectsEnabled = enabled;
    await _prefs.setBool(_soundEffectsEnabledKey, enabled);
  }

  Future<void> setLeanControlsEnabled(bool enabled) async {
    _leanControlsEnabled = enabled;
    await _prefs.setBool(_leanControlsKey, enabled);
  }

  Future<void> setPerformanceModeEnabled(bool enabled) async {
    _performanceModeEnabled = enabled;
    await _prefs.setBool(_performanceModeKey, enabled);
  }

  Future<void> resetProgress() async {
    _totalCoins = 0;
    _totalGems = 0;
    _bestDistanceMeters = 0;
    _completedRuns = 0;
    _performanceModeEnabled = false;
    for (final upgrade in upgradeDefinitions) {
      _upgradeLevels[upgrade.id] = 1;
    }
    _selectedVehicleId = starterBuggy.id;
    _selectedStageId = defaultStage.id;
    _unlockedVehicleIds
      ..clear()
      ..add(starterBuggy.id);
    _unlockedStageIds
      ..clear()
      ..add(defaultStage.id);
    await Future.wait([
      _prefs.setInt(_coinsKey, _totalCoins),
      _prefs.setInt(_gemsKey, _totalGems),
      _prefs.setDouble(_bestDistanceKey, _bestDistanceMeters),
      _prefs.setInt(_completedRunsKey, _completedRuns),
      _prefs.setBool(_performanceModeKey, _performanceModeEnabled),
      _prefs.setBool(_performanceModeRebalancedKey, true),
      _prefs.setString(_selectedVehicleKey, _selectedVehicleId),
      _prefs.setStringList(_unlockedVehiclesKey, _unlockedVehicleIds.toList()),
      _prefs.setString(_selectedStageKey, _selectedStageId),
      _prefs.setStringList(_unlockedStagesKey, _unlockedStageIds.toList()),
      _prefs.setBool(_accountSignedInKey, _accountSignedIn),
      for (final stage in stageDefinitions)
        _prefs.setInt(_stageStarsKey(stage.id), 0),
      for (final stage in stageDefinitions)
        _prefs.setDouble(_stageBestDistanceKey(stage.id), 0),
      for (final upgrade in upgradeDefinitions)
        _prefs.setInt(_upgradeKey(upgrade.id), 1),
    ]);
  }

  void _restoreSequentialUnlocksFromCompletedStages() {
    for (var i = 0; i < stageDefinitions.length - 1; i += 1) {
      final current = stageDefinitions[i];
      if (stageStars(current.id) >= 3) {
        _unlockedStageIds.add(stageDefinitions[i + 1].id);
      }
    }
  }

  static String _upgradeKey(String id) => 'upgrade_$id';
  static String _stageStarsKey(String id) => 'stage_stars_$id';
  static String _stageBestDistanceKey(String id) => 'stage_best_distance_$id';

  static String _normalizeVehicleId(String id) {
    return switch (id) {
      'starter_rover' => starterBuggy.id,
      'switchback_jeep' => 'trail_jeep',
      'canyon_buggy' => starterBuggy.id,
      'neon_racer' => 'desert_racer',
      'monster_climber' => 'monster_truck',
      'quad_bike' => 'atv_quad',
      _ => id,
    };
  }

  static String _normalizeStageId(String id) {
    return switch (id) {
      'neon_ridge' => defaultStage.id,
      'crystal_canyon' => 'broken_bridge',
      'sunset_dunes' => 'high_dunes',
      _ => id,
    };
  }
}
