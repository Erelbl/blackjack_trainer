enum ChallengeCategory { game, trainer, general }

enum ChallengeTrackingType {
  winHands,
  handsPlayed,
  trainerCorrect,
  trainerAnswered,
  testAccuracy70,
  testAccuracy85,
  testAccuracy95,
  anyActivity,
}

class ChallengeDefinition {
  final String id;
  final String title;
  final ChallengeCategory category;
  final int target;
  final int rewardCoins;
  final int rewardXp;
  final ChallengeTrackingType trackingType;

  const ChallengeDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.target,
    required this.rewardCoins,
    required this.rewardXp,
    required this.trackingType,
  });
}

class ChallengeDefinitions {
  ChallengeDefinitions._();

  // ignore: prefer_const_declarations
  static const List<ChallengeDefinition> all = [
    // ── Game challenges ───────────────────────────────────────────────────────
    ChallengeDefinition(id: 'play_5',      title: 'Play 5 hands',         category: ChallengeCategory.game,    target: 5,  rewardCoins: 40,  rewardXp: 10, trackingType: ChallengeTrackingType.handsPlayed),
    ChallengeDefinition(id: 'play_10',     title: 'Play 10 hands',        category: ChallengeCategory.game,    target: 10, rewardCoins: 60,  rewardXp: 15, trackingType: ChallengeTrackingType.handsPlayed),
    ChallengeDefinition(id: 'play_20',     title: 'Play 20 hands',        category: ChallengeCategory.game,    target: 20, rewardCoins: 100, rewardXp: 25, trackingType: ChallengeTrackingType.handsPlayed),
    ChallengeDefinition(id: 'play_30',     title: 'Play 30 hands',        category: ChallengeCategory.game,    target: 30, rewardCoins: 150, rewardXp: 40, trackingType: ChallengeTrackingType.handsPlayed),
    ChallengeDefinition(id: 'win_3',       title: 'Win 3 hands',          category: ChallengeCategory.game,    target: 3,  rewardCoins: 50,  rewardXp: 15, trackingType: ChallengeTrackingType.winHands),
    ChallengeDefinition(id: 'win_5',       title: 'Win 5 hands',          category: ChallengeCategory.game,    target: 5,  rewardCoins: 75,  rewardXp: 20, trackingType: ChallengeTrackingType.winHands),
    ChallengeDefinition(id: 'win_8',       title: 'Win 8 hands',          category: ChallengeCategory.game,    target: 8,  rewardCoins: 110, rewardXp: 28, trackingType: ChallengeTrackingType.winHands),
    ChallengeDefinition(id: 'win_12',      title: 'Win 12 hands',         category: ChallengeCategory.game,    target: 12, rewardCoins: 150, rewardXp: 38, trackingType: ChallengeTrackingType.winHands),
    ChallengeDefinition(id: 'win_15',      title: 'Win 15 hands',         category: ChallengeCategory.game,    target: 15, rewardCoins: 200, rewardXp: 50, trackingType: ChallengeTrackingType.winHands),
    // ── Trainer challenges ────────────────────────────────────────────────────
    ChallengeDefinition(id: 'trainer_5c',  title: 'Get 5 correct answers',  category: ChallengeCategory.trainer, target: 5,  rewardCoins: 40,  rewardXp: 12, trackingType: ChallengeTrackingType.trainerCorrect),
    ChallengeDefinition(id: 'trainer_10c', title: 'Get 10 correct answers', category: ChallengeCategory.trainer, target: 10, rewardCoins: 65,  rewardXp: 18, trackingType: ChallengeTrackingType.trainerCorrect),
    ChallengeDefinition(id: 'trainer_20c', title: 'Get 20 correct answers', category: ChallengeCategory.trainer, target: 20, rewardCoins: 100, rewardXp: 30, trackingType: ChallengeTrackingType.trainerCorrect),
    ChallengeDefinition(id: 'trainer_30c', title: 'Get 30 correct answers', category: ChallengeCategory.trainer, target: 30, rewardCoins: 150, rewardXp: 45, trackingType: ChallengeTrackingType.trainerCorrect),
    ChallengeDefinition(id: 'trainer_10a', title: 'Answer 10 questions',    category: ChallengeCategory.trainer, target: 10, rewardCoins: 50,  rewardXp: 12, trackingType: ChallengeTrackingType.trainerAnswered),
    ChallengeDefinition(id: 'trainer_25a', title: 'Answer 25 questions',    category: ChallengeCategory.trainer, target: 25, rewardCoins: 80,  rewardXp: 20, trackingType: ChallengeTrackingType.trainerAnswered),
    ChallengeDefinition(id: 'test_70',     title: 'Pass a test (70%+)',     category: ChallengeCategory.trainer, target: 1,  rewardCoins: 75,  rewardXp: 20, trackingType: ChallengeTrackingType.testAccuracy70),
    ChallengeDefinition(id: 'test_85',     title: 'Pass a test (85%+)',     category: ChallengeCategory.trainer, target: 1,  rewardCoins: 100, rewardXp: 30, trackingType: ChallengeTrackingType.testAccuracy85),
    ChallengeDefinition(id: 'test_95',     title: 'Pass a test (95%+)',     category: ChallengeCategory.trainer, target: 1,  rewardCoins: 150, rewardXp: 50, trackingType: ChallengeTrackingType.testAccuracy95),
    // ── General challenges ────────────────────────────────────────────────────
    ChallengeDefinition(id: 'any_5',        title: 'Do 5 actions',           category: ChallengeCategory.general, target: 5,  rewardCoins: 30,  rewardXp:  8, trackingType: ChallengeTrackingType.anyActivity),
    ChallengeDefinition(id: 'any_10',       title: 'Do 10 actions',          category: ChallengeCategory.general, target: 10, rewardCoins: 50,  rewardXp: 12, trackingType: ChallengeTrackingType.anyActivity),
    ChallengeDefinition(id: 'any_20',       title: 'Do 20 actions',          category: ChallengeCategory.general, target: 20, rewardCoins: 80,  rewardXp: 20, trackingType: ChallengeTrackingType.anyActivity),
    ChallengeDefinition(id: 'any_30',       title: 'Do 30 actions',          category: ChallengeCategory.general, target: 30, rewardCoins: 110, rewardXp: 28, trackingType: ChallengeTrackingType.anyActivity),
    ChallengeDefinition(id: 'any_50',       title: 'Do 50 actions',          category: ChallengeCategory.general, target: 50, rewardCoins: 160, rewardXp: 40, trackingType: ChallengeTrackingType.anyActivity),
    ChallengeDefinition(id: 'play_any',     title: 'Play 3 game hands',      category: ChallengeCategory.general, target: 3,  rewardCoins: 35,  rewardXp: 10, trackingType: ChallengeTrackingType.handsPlayed),
    ChallengeDefinition(id: 'train_any',    title: 'Answer 3 trainer Qs',    category: ChallengeCategory.general, target: 3,  rewardCoins: 35,  rewardXp: 10, trackingType: ChallengeTrackingType.trainerAnswered),
    ChallengeDefinition(id: 'mixed_15',     title: 'Mix 15 total actions',   category: ChallengeCategory.general, target: 15, rewardCoins: 75,  rewardXp: 18, trackingType: ChallengeTrackingType.anyActivity),
    ChallengeDefinition(id: 'long_session', title: 'Complete 40 actions',    category: ChallengeCategory.general, target: 40, rewardCoins: 130, rewardXp: 35, trackingType: ChallengeTrackingType.anyActivity),
  ];

  static List<ChallengeDefinition> get gameList =>
      all.where((c) => c.category == ChallengeCategory.game).toList();

  static List<ChallengeDefinition> get trainerList =>
      all.where((c) => c.category == ChallengeCategory.trainer).toList();

  static List<ChallengeDefinition> get generalList =>
      all.where((c) => c.category == ChallengeCategory.general).toList();

  static ChallengeDefinition? findById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
