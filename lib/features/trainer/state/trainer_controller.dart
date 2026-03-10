import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../engine/config/blackjack_rules.dart';
import '../../../engine/game/blackjack_game.dart';
import '../../../engine/game/game_state.dart';
import '../../../engine/models/card.dart';
import '../../../engine/models/rank.dart';
import '../../../engine/simulation/win_rate_simulator.dart';
import '../../../engine/strategy/basic_strategy.dart';
import '../../../engine/utils/hand_evaluator.dart';
import '../../../services/audio_service.dart';
import '../../../engine/progression/progression_manager.dart';
import 'trainer_state.dart';

class TrainerController extends StateNotifier<TrainerState> {
  late BlackjackGame _game;
  bool _busy = false;
  int _simGeneration = 0;
  bool _previousRoundActive = false;
  final Ref _ref;

  TrainerController(this._ref) : super(TrainerState.initial()) {
    _game = BlackjackGame(rules: const BlackjackRules());
  }

  // ---------------------------------------------------------------------------
  // Mode management
  // ---------------------------------------------------------------------------

  /// Resets game state to idle while preserving accumulated stats.
  /// Called when [TrainerGameTab] is disposed so returning to the trainer
  /// always starts with a fresh table.
  void resetSession() {
    _game = BlackjackGame(rules: const BlackjackRules());
    _simGeneration++; // discard any in-flight simulation
    state = TrainerState(
      playerCards: const [],
      dealerCards: const [],
      gameState: GameState.idle,
      roundActive: false,
      mode: state.mode,
      learnStats: state.learnStats,
      testStats: state.testStats,
    );
  }

  /// Switches between Learn and Test modes. Clears winRates since Test mode
  /// never computes them.
  void setMode(TrainerMode mode) {
    if (state.mode == mode) return;

    // Report test accuracy when the user leaves test mode.
    if (state.mode == TrainerMode.test && mode == TrainerMode.learn) {
      final ts = state.testStats;
      if (ts.decisionsCount > 0) {
        ProgressionManager.instance.onTrainerTestCompleted(
          accuracy: ts.correctCount / ts.decisionsCount,
        );
      }
    }
    state = TrainerState(
      playerCards: state.playerCards,
      dealerCards: state.dealerCards,
      gameState: state.gameState,
      roundActive: state.roundActive,
      resultMessage: state.resultMessage,
      isActionLocked: state.isActionLocked,
      mode: mode,
      learnStats: state.learnStats,
      testStats: state.testStats,
      lastFeedback: state.lastFeedback,
      winRates: null, // test mode never fills winRates
      hasSplit: state.hasSplit,
      activeHandIndex: state.activeHandIndex,
      allPlayerHands: state.allPlayerHands,
      handOutcomes: state.handOutcomes,
      canDouble: state.canDouble,
      canSplit: state.canSplit,
    );
  }

  /// Reveals the explanation in Test mode after the user taps "Show explanation".
  void revealExplanation() {
    final fb = state.lastFeedback;
    if (fb == null || fb.showExplanation) return;
    state = TrainerState(
      playerCards: state.playerCards,
      dealerCards: state.dealerCards,
      gameState: state.gameState,
      roundActive: state.roundActive,
      resultMessage: state.resultMessage,
      isActionLocked: state.isActionLocked,
      mode: state.mode,
      learnStats: state.learnStats,
      testStats: state.testStats,
      lastFeedback: fb.withExplanationVisible(),
      winRates: state.winRates,
      hasSplit: state.hasSplit,
      activeHandIndex: state.activeHandIndex,
      allPlayerHands: state.allPlayerHands,
      handOutcomes: state.handOutcomes,
      canDouble: state.canDouble,
      canSplit: state.canSplit,
    );
  }

  // ---------------------------------------------------------------------------
  // Game actions
  // ---------------------------------------------------------------------------

  void startNewRound() {
    if (_busy) return;
    final canStart = _game.state == GameState.idle || _game.isGameOver;
    if (!canStart) return;

    _busy = true;
    // Lock UI and clear last-round feedback immediately.
    state = TrainerState(
      playerCards: state.playerCards,
      dealerCards: state.dealerCards,
      gameState: state.gameState,
      roundActive: state.roundActive,
      isActionLocked: true,
      lastFeedback: null, // clear between rounds
      mode: state.mode,
      learnStats: state.learnStats,
      testStats: state.testStats,
    );

    try {
      _game.startNewRound();
      _syncState(); // unlock FIRST — audio is non-critical
      try {
        _ref.read(audioServiceProvider.notifier).playSfx(SfxType.deal);
      } catch (_) {} // audio plugin may be unavailable (test / cold start)
    } finally {
      _busy = false;
    }
  }

  void hit() {
    if (_busy || !_game.canPlayerHit) return;
    _recordFeedback(StrategyAction.hit);
    _busy = true;
    try {
      _game.playerHit();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  void stand() {
    if (_busy || !_game.canPlayerStand) return;
    _recordFeedback(StrategyAction.stand);
    _busy = true;
    try {
      _game.playerStand();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  void doubleDown() {
    if (_busy || !_game.canPlayerDouble) return;
    _recordFeedback(StrategyAction.doubleDown);
    _busy = true;
    try {
      _game.playerDouble();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  void split() {
    if (_busy || !_game.canPlayerSplit) return;
    _recordFeedback(StrategyAction.split);
    _busy = true;
    try {
      _game.playerSplit();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Returns the set of actions currently available in the trainer.
  Set<StrategyAction> _availableActions() {
    return {
      if (_game.canPlayerHit) StrategyAction.hit,
      if (_game.canPlayerStand) StrategyAction.stand,
      if (_game.canPlayerDouble) StrategyAction.doubleDown,
      if (_game.canPlayerSplit) StrategyAction.split,
    };
  }

  /// Evaluates the current decision against basic strategy and updates feedback
  /// + session stats for the active mode. Called BEFORE mutating the game engine
  /// so we capture the hand state at the moment of decision.
  void _recordFeedback(StrategyAction chosen) {
    final dealerUpcard = _game.dealerHand.cards.first.rank;
    final playerCards = _game.playerHand.cards.toList();
    final available = _availableActions();

    final recommended = BasicStrategy.recommend(
      playerCards: playerCards,
      dealerUpcard: dealerUpcard,
    );

    final isIdealUnavailable = !available.contains(recommended);

    final StrategyAction? fallback = isIdealUnavailable
        ? BasicStrategy.recommendFallback(
            playerCards: playerCards,
            dealerUpcard: dealerUpcard,
            availableActions: available,
          )
        : null;

    // Score the decision against the best available action.
    final actionToScore = fallback ?? recommended;
    final isCorrect = chosen == actionToScore;

    // Progression hook — fire-and-forget, safe if not initialized.
    ProgressionManager.instance.onTrainerAnswer(correct: isCorrect);

    // Update stats for the current mode only.
    final stats = state.currentStats;
    final newDecisions = stats.decisionsCount + 1;
    final newCorrect = stats.correctCount + (isCorrect ? 1 : 0);
    final newStreak = isCorrect ? stats.currentStreak + 1 : 0;
    final newBest = newStreak > stats.bestStreak ? newStreak : stats.bestStreak;
    final newStats = stats.copyWith(
      decisionsCount: newDecisions,
      correctCount: newCorrect,
      currentStreak: newStreak,
      bestStreak: newBest,
    );

    final explanation = isCorrect
        ? ''
        : _buildExplanation(recommended, fallback, playerCards, dealerUpcard);

    // Learn mode: auto-reveal explanation on incorrect decisions.
    // Test mode: keep hidden until user taps "Show explanation".
    final showExplanation = state.mode == TrainerMode.learn;

    state = TrainerState(
      playerCards: state.playerCards,
      dealerCards: state.dealerCards,
      gameState: state.gameState,
      roundActive: state.roundActive,
      resultMessage: state.resultMessage,
      isActionLocked: state.isActionLocked,
      mode: state.mode,
      learnStats: state.mode == TrainerMode.learn ? newStats : state.learnStats,
      testStats: state.mode == TrainerMode.test ? newStats : state.testStats,
      lastFeedback: TrainerFeedback(
        isCorrect: isCorrect,
        recommended: recommended,
        fallbackAction: fallback,
        chosen: chosen,
        explanation: explanation,
        showExplanation: showExplanation,
      ),
      winRates: state.winRates, // preserve until next sync
      hasSplit: state.hasSplit,
      activeHandIndex: state.activeHandIndex,
      allPlayerHands: state.allPlayerHands,
      handOutcomes: state.handOutcomes,
      canDouble: state.canDouble,
      canSplit: state.canSplit,
    );
  }

  String _buildExplanation(
    StrategyAction recommended,
    StrategyAction? fallback,
    List<Card> playerCards,
    Rank dealerUpcard,
  ) {
    final eval = HandEvaluator.evaluate(playerCards);
    final dealerLabel =
        dealerUpcard == Rank.ace ? 'Ace' : '${dealerUpcard.blackjackValue}';
    final handLabel =
        eval.isSoft ? 'Soft ${eval.total}' : 'Hard ${eval.total}';

    if (fallback != null) {
      // Ideal was unavailable; explain both the ideal and the fallback.
      final idealName = recommended.displayName;
      final fallbackName = fallback.displayName;
      return switch (recommended) {
        StrategyAction.split =>
          'Pair vs $dealerLabel: $idealName is ideal (not available) — $fallbackName is best available.',
        StrategyAction.doubleDown =>
          '$handLabel vs $dealerLabel: $idealName is ideal (not available) — $fallbackName is best available.',
        _ =>
          '$handLabel vs $dealerLabel: $fallbackName is best available.',
      };
    }

    return switch (recommended) {
      StrategyAction.hit =>
        '$handLabel vs $dealerLabel: Hit — standing here loses more often against this upcard.',
      StrategyAction.stand =>
        '$handLabel vs $dealerLabel: Stand — let the dealer risk busting.',
      StrategyAction.doubleDown =>
        '$handLabel vs $dealerLabel: Double — maximize your bet on this strong position.',
      StrategyAction.split =>
        'Pair vs $dealerLabel: Split — splitting improves your expected value here.',
    };
  }

  /// Rebuilds [TrainerState] from the current [BlackjackGame], preserving all
  /// trainer-specific stats and the last feedback. Clears winRates (they are
  /// re-computed asynchronously only in Learn mode during playerTurn).
  void _syncState() {
    final isActive = _game.canPlayerHit || _game.canPlayerStand;
    final wasActive = _previousRoundActive;

    // Snapshot all player hands.
    final allHands = _game.playerHands.map((h) => h.cards.toList()).toList();
    final activeCards = _game.isGameOver
        ? allHands[0]
        : allHands[_game.activeHandIndex];

    state = TrainerState(
      playerCards: activeCards,
      dealerCards: _game.dealerHand.cards.toList(),
      gameState: _game.state,
      roundActive: isActive,
      resultMessage: _resultMessage(_game),
      isActionLocked: false,
      mode: state.mode,
      learnStats: state.learnStats,
      testStats: state.testStats,
      lastFeedback: state.lastFeedback,
      winRates: null, // cleared; re-computed below if learn mode + playerTurn
      hasSplit: _game.hasSplit,
      activeHandIndex: _game.activeHandIndex,
      allPlayerHands: allHands,
      handOutcomes: _game.handOutcomes.isNotEmpty ? List.of(_game.handOutcomes) : null,
      canDouble: _game.canPlayerDouble,
      canSplit: _game.canPlayerSplit,
    );

    // Play win/lose SFX when a round ends.
    if (wasActive && !isActive) {
      final representativeState = _game.hasSplit
          ? _representativeOutcome(_game.handOutcomes)
          : _game.state;
      final sfx = _sfxForOutcome(representativeState);
      if (sfx != null) {
        try {
          _ref.read(audioServiceProvider.notifier).playSfx(sfx);
        } catch (_) {} // audio plugin may be unavailable (test / cold start)
      }
    }

    _previousRoundActive = isActive;

    // Monte Carlo simulation only runs in Learn mode.
    if (_game.state == GameState.playerTurn && state.mode == TrainerMode.learn) {
      _triggerWinRateSimulation();
    }
  }

  GameState _representativeOutcome(List<GameState> outcomes) {
    final anyWin = outcomes.any((o) =>
        o == GameState.playerWin ||
        o == GameState.dealerBust ||
        o == GameState.playerBlackjack);
    if (anyWin) return GameState.playerWin;
    final anyPush = outcomes.any((o) => o == GameState.push);
    if (anyPush) return GameState.push;
    return GameState.playerBust;
  }

  SfxType? _sfxForOutcome(GameState gameState) => switch (gameState) {
    GameState.playerWin ||
    GameState.dealerBust ||
    GameState.playerBlackjack => SfxType.win,
    GameState.dealerWin ||
    GameState.playerBust      => SfxType.lose,
    _                         => null,
  };

  /// Launches an async Monte Carlo simulation. On completion the result is
  /// applied only if the game is still in playerTurn and the generation
  /// counter hasn't been superseded by a newer simulation.
  void _triggerWinRateSimulation() {
    final gen = ++_simGeneration;
    final remaining = _game.shoe.remainingCards;
    final player = _game.playerHand.cards.toList();
    final dealer = _game.dealerHand.cards.toList();

    WinRateSimulator.simulate(
      remainingCards: remaining,
      playerCards: player,
      dealerCards: dealer,
    ).then((result) {
      if (_simGeneration != gen) return; // superseded
      if (!mounted) return;
      if (state.gameState != GameState.playerTurn) return;
      state = TrainerState(
        playerCards: state.playerCards,
        dealerCards: state.dealerCards,
        gameState: state.gameState,
        roundActive: state.roundActive,
        resultMessage: state.resultMessage,
        isActionLocked: state.isActionLocked,
        mode: state.mode,
        learnStats: state.learnStats,
        testStats: state.testStats,
        lastFeedback: state.lastFeedback,
        winRates: result,
        hasSplit: state.hasSplit,
        activeHandIndex: state.activeHandIndex,
        allPlayerHands: state.allPlayerHands,
        handOutcomes: state.handOutcomes,
        canDouble: state.canDouble,
        canSplit: state.canSplit,
      );
    });
  }

  String? _resultMessage(BlackjackGame game) {
    if (!game.isGameOver) return null;

    if (game.hasSplit && game.handOutcomes.length == 2) {
      String label(GameState gs) => switch (gs) {
        GameState.playerWin || GameState.dealerBust => 'Win',
        GameState.dealerWin                         => 'Lose',
        GameState.playerBust                        => 'Bust',
        GameState.push                              => 'Push',
        _                                           => '',
      };
      return '${label(game.handOutcomes[0])}  |  ${label(game.handOutcomes[1])}';
    }

    return switch (game.state) {
      GameState.idle            => null,
      GameState.playerTurn      => null,
      GameState.dealerTurn      => null,
      GameState.playerBlackjack => 'Blackjack!',
      GameState.playerWin       => 'You win!',
      GameState.dealerWin       => 'Dealer wins',
      GameState.playerBust      => 'Bust!',
      GameState.dealerBust      => 'Dealer busts – You win!',
      GameState.push            => 'Push!',
    };
  }
}

final trainerControllerProvider =
    StateNotifierProvider<TrainerController, TrainerState>((ref) {
  return TrainerController(ref);
});
