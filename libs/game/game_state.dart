enum RiderPhase { running, stageComplete, gameOver }

enum RiderControl { gas, brake, leanBack, leanForward }

class ControlInput {
  const ControlInput({
    this.gas = false,
    this.brake = false,
    this.leanBack = false,
    this.leanForward = false,
  });

  final bool gas;
  final bool brake;
  final bool leanBack;
  final bool leanForward;

  bool get anyPressed => gas || brake || leanBack || leanForward;

  ControlInput copyWith({
    bool? gas,
    bool? brake,
    bool? leanBack,
    bool? leanForward,
  }) {
    return ControlInput(
      gas: gas ?? this.gas,
      brake: brake ?? this.brake,
      leanBack: leanBack ?? this.leanBack,
      leanForward: leanForward ?? this.leanForward,
    );
  }
}

class GameSnapshot {
  const GameSnapshot({
    required this.phase,
    required this.distanceMeters,
    required this.bestDistanceMeters,
    required this.coinsThisRun,
    required this.gemsThisRun,
    required this.totalCoins,
    required this.totalGems,
    required this.fuelFraction,
    required this.speedFraction,
    required this.rpmFraction,
    required this.boostFraction,
    required this.stageName,
    required this.stageGoalMeters,
    required this.stageStars,
    required this.canContinueWithGem,
    this.warningText = '',
    this.dangerFraction = 0,
    this.performanceText = '',
    this.destinationName = '',
    this.nextCheckpointMeters = 0,
    this.levelName = '',
    this.levelDescription = '',
    this.levelIndex = 0,
    this.totalLevels = 1,
    this.levelStartMeters = 0,
    this.levelEndMeters = 1,
    this.gameOverReason = '',
  });

  factory GameSnapshot.initial({
    required int totalCoins,
    required int totalGems,
    required double bestDistanceMeters,
  }) {
    return GameSnapshot(
      phase: RiderPhase.running,
      distanceMeters: 0,
      bestDistanceMeters: bestDistanceMeters,
      coinsThisRun: 0,
      gemsThisRun: 0,
      totalCoins: totalCoins,
      totalGems: totalGems,
      fuelFraction: 1,
      speedFraction: 0,
      rpmFraction: 0,
      boostFraction: 0,
      stageName: '',
      stageGoalMeters: 1,
      stageStars: 0,
      canContinueWithGem: false,
      warningText: '',
      dangerFraction: 0,
      performanceText: '',
      destinationName: '',
      nextCheckpointMeters: 0,
      levelName: '',
      levelDescription: '',
      levelIndex: 0,
      totalLevels: 1,
      levelStartMeters: 0,
      levelEndMeters: 1,
    );
  }

  final RiderPhase phase;
  final double distanceMeters;
  final double bestDistanceMeters;
  final int coinsThisRun;
  final int gemsThisRun;
  final int totalCoins;
  final int totalGems;
  final double fuelFraction;
  final double speedFraction;
  final double rpmFraction;
  final double boostFraction;
  final String stageName;
  final int stageGoalMeters;
  final int stageStars;
  final bool canContinueWithGem;
  final String warningText;
  final double dangerFraction;
  final String performanceText;
  final String destinationName;
  final int nextCheckpointMeters;
  final String levelName;
  final String levelDescription;
  final int levelIndex;
  final int totalLevels;
  final int levelStartMeters;
  final int levelEndMeters;
  final String gameOverReason;
}
