enum AchievementCategory { mastery, game, trainer, challenges }

enum AchievementConditionType {
  handsPlayed,
  handsWon,
  trainerAnswered,
  trainerCorrect,
  testsPassed,
  testsAtAccuracy85,
  testsAtAccuracy95,
  dailiesClaimed,
  anyTotal,
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final AchievementConditionType conditionType;
  final int threshold;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.conditionType,
    required this.threshold,
  });
}

class AchievementDefinitions {
  AchievementDefinitions._();

  static const List<AchievementDefinition> all = [
    // ── Mastery ───────────────────────────────────────────────────────────────
    AchievementDefinition(id: 'first_play',      title: 'First Step',          description: 'Play your first hand',              category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsPlayed,       threshold: 1),
    AchievementDefinition(id: 'century',         title: 'Century Club',        description: 'Play 100 hands',                    category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsPlayed,       threshold: 100),
    AchievementDefinition(id: 'veteran',         title: 'Veteran',             description: 'Play 500 hands',                    category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsPlayed,       threshold: 500),
    AchievementDefinition(id: 'legend',          title: 'Legend',              description: 'Play 1000 hands',                   category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsPlayed,       threshold: 1000),
    AchievementDefinition(id: 'first_win',       title: 'Winner',              description: 'Win your first hand',               category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsWon,          threshold: 1),
    AchievementDefinition(id: 'hot_hands',       title: 'Hot Hands',           description: 'Win 50 hands',                      category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsWon,          threshold: 50),
    AchievementDefinition(id: 'winning_ways',    title: 'Winning Ways',        description: 'Win 200 hands',                     category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsWon,          threshold: 200),
    AchievementDefinition(id: 'win_machine',     title: 'Win Machine',         description: 'Win 500 hands',                     category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsWon,          threshold: 500),
    AchievementDefinition(id: 'dealer_crusher',  title: 'Dealer Crusher',      description: 'Win 1000 hands',                    category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsWon,          threshold: 1000),
    AchievementDefinition(id: 'marathon_runner', title: 'Marathon',            description: 'Play 2000 hands',                   category: AchievementCategory.mastery,    conditionType: AchievementConditionType.handsPlayed,       threshold: 2000),
    // ── Game ─────────────────────────────────────────────────────────────────
    AchievementDefinition(id: 'quick_learner',   title: 'Quick Learner',       description: 'Play 10 hands',                     category: AchievementCategory.game,       conditionType: AchievementConditionType.handsPlayed,       threshold: 10),
    AchievementDefinition(id: 'getting_started', title: 'Getting Started',     description: 'Play 25 hands',                     category: AchievementCategory.game,       conditionType: AchievementConditionType.handsPlayed,       threshold: 25),
    AchievementDefinition(id: 'regular',         title: 'Regular',             description: 'Play 50 hands',                     category: AchievementCategory.game,       conditionType: AchievementConditionType.handsPlayed,       threshold: 50),
    AchievementDefinition(id: 'keen_player',     title: 'Keen Player',         description: 'Play 200 hands',                    category: AchievementCategory.game,       conditionType: AchievementConditionType.handsPlayed,       threshold: 200),
    AchievementDefinition(id: 'obsessed',        title: 'Obsessed',            description: 'Play 750 hands',                    category: AchievementCategory.game,       conditionType: AchievementConditionType.handsPlayed,       threshold: 750),
    AchievementDefinition(id: 'three_peat',      title: 'Three-Peat',          description: 'Win 3 hands',                       category: AchievementCategory.game,       conditionType: AchievementConditionType.handsWon,          threshold: 3),
    AchievementDefinition(id: 'on_a_roll',       title: 'On a Roll',           description: 'Win 10 hands',                      category: AchievementCategory.game,       conditionType: AchievementConditionType.handsWon,          threshold: 10),
    AchievementDefinition(id: 'big_winner',      title: 'Big Winner',          description: 'Win 25 hands',                      category: AchievementCategory.game,       conditionType: AchievementConditionType.handsWon,          threshold: 25),
    AchievementDefinition(id: 'champion',        title: 'Champion',            description: 'Win 100 hands',                     category: AchievementCategory.game,       conditionType: AchievementConditionType.handsWon,          threshold: 100),
    AchievementDefinition(id: 'unstoppable',     title: 'Unstoppable',         description: 'Win 750 hands',                     category: AchievementCategory.game,       conditionType: AchievementConditionType.handsWon,          threshold: 750),
    // ── Trainer ───────────────────────────────────────────────────────────────
    AchievementDefinition(id: 'first_lesson',    title: 'First Lesson',        description: 'Answer your first trainer question', category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerAnswered,   threshold: 1),
    AchievementDefinition(id: 'eager_student',   title: 'Eager Student',       description: 'Answer 10 trainer questions',        category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerAnswered,   threshold: 10),
    AchievementDefinition(id: 'diligent',        title: 'Diligent',            description: 'Answer 50 trainer questions',        category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerAnswered,   threshold: 50),
    AchievementDefinition(id: 'dedicated',       title: 'Dedicated',           description: 'Answer 200 trainer questions',       category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerAnswered,   threshold: 200),
    AchievementDefinition(id: 'expert_student',  title: 'Expert Student',      description: 'Answer 500 trainer questions',       category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerAnswered,   threshold: 500),
    AchievementDefinition(id: 'first_correct',   title: 'Getting It Right',    description: 'Get your first correct answer',      category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerCorrect,    threshold: 1),
    AchievementDefinition(id: 'sharp_mind',      title: 'Sharp Mind',          description: 'Get 25 correct answers',             category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerCorrect,    threshold: 25),
    AchievementDefinition(id: 'ace_student',     title: 'Ace Student',         description: 'Get 100 correct answers',            category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerCorrect,    threshold: 100),
    AchievementDefinition(id: 'strategy_master', title: 'Strategy Master',     description: 'Get 250 correct answers',            category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerCorrect,    threshold: 250),
    AchievementDefinition(id: 'perfect_recall',  title: 'Perfect Recall',      description: 'Get 500 correct answers',            category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerCorrect,    threshold: 500),
    AchievementDefinition(id: 'truth_seeker',    title: 'Truth Seeker',        description: 'Get 50 correct answers',             category: AchievementCategory.trainer,   conditionType: AchievementConditionType.trainerCorrect,    threshold: 50),
    AchievementDefinition(id: 'first_test',      title: 'Test Taker',          description: 'Complete your first test',           category: AchievementCategory.trainer,   conditionType: AchievementConditionType.testsPassed,       threshold: 1),
    AchievementDefinition(id: 'test_scholar',    title: 'Test Scholar',        description: 'Complete 10 tests',                  category: AchievementCategory.trainer,   conditionType: AchievementConditionType.testsPassed,       threshold: 10),
    AchievementDefinition(id: 'test_veteran',    title: 'Test Veteran',        description: 'Complete 5 tests',                   category: AchievementCategory.trainer,   conditionType: AchievementConditionType.testsPassed,       threshold: 5),
    AchievementDefinition(id: 'test_legend',     title: 'Test Legend',         description: 'Complete 20 tests',                  category: AchievementCategory.trainer,   conditionType: AchievementConditionType.testsPassed,       threshold: 20),
    AchievementDefinition(id: 'high_scorer',     title: 'High Scorer',         description: 'Pass a test with 85%+ accuracy',     category: AchievementCategory.trainer,   conditionType: AchievementConditionType.testsAtAccuracy85, threshold: 1),
    AchievementDefinition(id: 'elite_student',   title: 'Elite Student',       description: 'Pass 5 tests with 85%+ accuracy',    category: AchievementCategory.trainer,   conditionType: AchievementConditionType.testsAtAccuracy85, threshold: 5),
    // ── Challenges ────────────────────────────────────────────────────────────
    AchievementDefinition(id: 'first_challenge',  title: 'Daily Warrior',      description: 'Claim your first daily challenge',   category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 1),
    AchievementDefinition(id: 'streak_seeker',    title: 'Streak Seeker',      description: 'Claim 10 daily challenges',           category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 10),
    AchievementDefinition(id: 'challenge_regular',title: 'Challenge Regular',  description: 'Claim 5 daily challenges',            category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 5),
    AchievementDefinition(id: 'consistent',       title: 'Consistent',         description: 'Claim 20 daily challenges',           category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 20),
    AchievementDefinition(id: 'challenge_vet',    title: 'Challenge Veteran',  description: 'Claim 15 daily challenges',           category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 15),
    AchievementDefinition(id: 'challenge_seeker', title: 'Challenge Seeker',   description: 'Claim 30 daily challenges',           category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 30),
    AchievementDefinition(id: 'weekend_warrior',  title: 'Weekend Warrior',    description: 'Claim 50 daily challenges',           category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 50),
    AchievementDefinition(id: 'challenge_master', title: 'Challenge Master',   description: 'Claim 60 daily challenges',           category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 60),
    AchievementDefinition(id: 'challenge_legend', title: 'Challenge Legend',   description: 'Claim 100 daily challenges',          category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 100),
    AchievementDefinition(id: 'dedication',       title: 'Daily Dedication',   description: 'Claim 200 daily challenges',          category: AchievementCategory.challenges, conditionType: AchievementConditionType.dailiesClaimed,    threshold: 200),
    AchievementDefinition(id: 'perfect_score',    title: 'Perfect Score',      description: 'Pass a test with 95%+ accuracy',      category: AchievementCategory.challenges, conditionType: AchievementConditionType.testsAtAccuracy95, threshold: 1),
    AchievementDefinition(id: 'flawless',         title: 'Flawless',           description: 'Pass 3 tests with 95%+ accuracy',     category: AchievementCategory.challenges, conditionType: AchievementConditionType.testsAtAccuracy95, threshold: 3),
    AchievementDefinition(id: 'ace_tester',       title: 'Ace Tester',         description: 'Pass 10 tests with 95%+ accuracy',    category: AchievementCategory.challenges, conditionType: AchievementConditionType.testsAtAccuracy95, threshold: 10),
    AchievementDefinition(id: 'beginner',         title: 'Just Getting Started', description: 'Complete 10 total actions',         category: AchievementCategory.challenges, conditionType: AchievementConditionType.anyTotal,          threshold: 10),
    AchievementDefinition(id: 'active_learner',   title: 'Active Learner',     description: 'Complete 100 total actions',          category: AchievementCategory.challenges, conditionType: AchievementConditionType.anyTotal,          threshold: 100),
    AchievementDefinition(id: 'all_rounder',      title: 'All-Rounder',        description: 'Complete 500 total actions',          category: AchievementCategory.challenges, conditionType: AchievementConditionType.anyTotal,          threshold: 500),
    AchievementDefinition(id: 'grand_master',     title: 'Grand Master',       description: 'Complete 1000 total actions',         category: AchievementCategory.challenges, conditionType: AchievementConditionType.anyTotal,          threshold: 1000),
  ];
}
