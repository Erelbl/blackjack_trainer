import '../../../engine/models/card.dart';
import '../../../engine/game/game_state.dart';
import '../../../engine/simulation/win_rate_simulator.dart';
import '../../../engine/strategy/basic_strategy.dart';

enum TrainerMode { learn, test }

class TrainerStats {
  final int decisionsCount;
  final int correctCount;
  final int currentStreak;
  final int bestStreak;

  const TrainerStats({
    this.decisionsCount = 0,
    this.correctCount = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  double get accuracy =>
      decisionsCount == 0 ? 0.0 : correctCount / decisionsCount;

  TrainerStats copyWith({
    int? decisionsCount,
    int? correctCount,
    int? currentStreak,
    int? bestStreak,
  }) =>
      TrainerStats(
        decisionsCount: decisionsCount ?? this.decisionsCount,
        correctCount: correctCount ?? this.correctCount,
        currentStreak: currentStreak ?? this.currentStreak,
        bestStreak: bestStreak ?? this.bestStreak,
      );
}

class TrainerFeedback {
  final bool isCorrect;

  /// The ideal action from basic strategy (may be unavailable in the UI).
  final StrategyAction recommended;

  /// Non-null when [recommended] is not available in the current UI.
  /// The trainer scores the decision against this fallback action instead.
  final StrategyAction? fallbackAction;

  final StrategyAction chosen;

  /// Non-empty only when [isCorrect] is false.
  final String explanation;

  /// Whether the explanation text is currently visible in the UI.
  /// In Learn mode: true automatically on incorrect decisions.
  /// In Test mode: starts false; revealed by user tapping "Show explanation".
  final bool showExplanation;

  const TrainerFeedback({
    required this.isCorrect,
    required this.recommended,
    this.fallbackAction,
    required this.chosen,
    required this.explanation,
    this.showExplanation = true,
  });

  /// True when the ideal [recommended] action was not available in the UI.
  bool get isIdealUnavailable => fallbackAction != null;

  TrainerFeedback withExplanationVisible() => TrainerFeedback(
        isCorrect: isCorrect,
        recommended: recommended,
        fallbackAction: fallbackAction,
        chosen: chosen,
        explanation: explanation,
        showExplanation: true,
      );
}

class TrainerState {
  final List<Card> playerCards;
  final List<Card> dealerCards;
  final GameState gameState;
  final bool roundActive;
  final String? resultMessage;
  final bool isActionLocked;

  /// Current practice mode: Learn (Win% + auto-explanation on incorrect) or
  /// Test (hides Win%, hides explanation until user reveals it).
  final TrainerMode mode;

  /// Stats accumulated in Learn mode.
  final TrainerStats learnStats;

  /// Stats accumulated in Test mode (used for future leaderboard/challenges).
  final TrainerStats testStats;

  final TrainerFeedback? lastFeedback;

  /// Async win-rate estimate — null until simulation completes, non-playerTurn,
  /// or in Test mode (simulation is skipped entirely).
  final WinRateResult? winRates;

  // ── Split fields ──────────────────────────────────────────────────────
  final bool hasSplit;
  final int activeHandIndex;
  final List<List<Card>> allPlayerHands;
  final List<GameState>? handOutcomes;
  final bool canDouble;
  final bool canSplit;

  const TrainerState({
    required this.playerCards,
    required this.dealerCards,
    required this.gameState,
    required this.roundActive,
    this.resultMessage,
    this.isActionLocked = false,
    this.mode = TrainerMode.learn,
    this.learnStats = const TrainerStats(),
    this.testStats = const TrainerStats(),
    this.lastFeedback,
    this.winRates,
    this.hasSplit = false,
    this.activeHandIndex = 0,
    this.allPlayerHands = const [[]],
    this.handOutcomes,
    this.canDouble = false,
    this.canSplit = false,
  });

  factory TrainerState.initial() => const TrainerState(
        playerCards: [],
        dealerCards: [],
        gameState: GameState.idle,
        roundActive: false,
      );

  bool get isSplitRound => hasSplit;

  /// Stats for the currently active mode.
  TrainerStats get currentStats =>
      mode == TrainerMode.learn ? learnStats : testStats;

  // Convenience getters (delegate to currentStats) so existing widgets compile
  // without changes.
  int get decisionsCount => currentStats.decisionsCount;
  int get correctCount   => currentStats.correctCount;
  int get currentStreak  => currentStats.currentStreak;
  int get bestStreak     => currentStats.bestStreak;
  double get accuracy    => currentStats.accuracy;
}
