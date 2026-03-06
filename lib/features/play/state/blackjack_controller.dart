import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../engine/game/blackjack_game.dart';
import '../../../engine/game/game_state.dart';
import '../../../engine/models/card.dart';
import '../../../engine/simulation/win_rate_simulator.dart';
import '../../../engine/strategy/basic_strategy.dart';
import '../../../engine/utils/bet_utils.dart';
import '../../../engine/utils/xp_utils.dart';
import '../../../data/providers/stats_providers.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../data/providers/progression_providers.dart';
import '../../../data/providers/weekly_goal_providers.dart';
import '../../../engine/config/blackjack_rules.dart';
import '../../../services/audio_service.dart';
import '../../../services/rules_storage.dart';
import '../debug/rebuild_counter.dart';
import 'blackjack_state.dart';
import 'counting_session_controller.dart';
import 'session_stats.dart';
import '../../../engine/progression/progression_manager.dart';

/// Computes the net coin change for a completed round given [gameState] and [bet].
///
/// Exposed as a top-level function so it can be unit-tested independently of
/// the full controller/provider graph.
///
/// Payouts:
///   playerWin / dealerBust  → +bet
///   dealerWin / playerBust  → -bet
///   playerBlackjack         → +round(blackjackPayout × bet)  default 1.5 (3:2)
///   push                    → 0
int computeBetPayout(GameState gameState, int bet,
    {double blackjackPayout = 1.5}) {
  return switch (gameState) {
    GameState.playerWin || GameState.dealerBust => bet,
    GameState.dealerWin || GameState.playerBust => -bet,
    GameState.playerBlackjack                  => (bet * blackjackPayout).round(),
    GameState.push                             => 0,
    _                                          => 0,
  };
}

class BlackjackController extends StateNotifier<BlackjackState> {
  late BlackjackGame _game;
  /// Tracks the engine's GameState after each _syncState() call so that
  /// non-terminal → terminal transitions are detected reliably, including
  /// immediate blackjack (where roundActive is never true).
  GameState _previousGameState = GameState.idle;
  final Ref _ref;

  /// Single-flight guard: prevents re-entrant or concurrent action calls.
  bool _busy = false;

  /// Generation counter for async simulation — incremented on each trigger so
  /// stale callbacks from superseded positions are discarded.
  int _simGeneration = 0;

  /// Auto-reset timer: fires 3 seconds after a round ends to clear the table.
  Timer? _autoResetTimer;

  // ── Counting session card-reveal tracking ────────────────────────────────
  /// How many cards from each player hand have already been reported to the
  /// counting session.  Indexed by hand position.
  List<int> _reportedPerHand = [];
  /// How many dealer cards have been reported (1 = upcard only).
  int _reportedDealerCards = 0;
  /// True once a split has been detected for the current round.
  bool _wasSplit = false;

  BlackjackController(this._ref) : super(BlackjackState.initial()) {
    _game = BlackjackGame(rules: state.rules);
    FramePerfMonitor.start();
    _initRules();
  }

  /// Loads persisted rules asynchronously and applies them if the game is
  /// still idle (i.e. the user hasn't dealt before storage returned).
  Future<void> _initRules() async {
    final saved = await RulesStorage.loadRules();
    if (saved == null) return;
    if (!mounted) return;
    if (state.roundActive) return; // don't interrupt an in-progress round
    final bet = state.currentBet;
    final showAssist = state.showDecisionAssist;
    _game = BlackjackGame(rules: saved);
    state = BlackjackState(
      rules: saved,
      playerCards: const [],
      dealerCards: const [],
      gameState: GameState.idle,
      roundActive: false,
      resultMessage: null,
      isActionLocked: false,
      currentBet: bet,
      showDecisionAssist: showAssist,
      perfectPlay: true,
      lastXpResult: null,
      lastRoundPayout: null,
      winRates: null,
    );
  }

  /// Persists [rules], resets the table, and applies the new rules immediately.
  /// Safe to call at any time — cancels any in-flight timer/simulation first.
  void setRules(BlackjackRules rules) {
    RulesStorage.saveRules(rules); // fire-and-forget
    _autoResetTimer?.cancel();
    _autoResetTimer = null;
    _simGeneration++;
    _busy = false;
    _previousGameState = GameState.idle;
    final bet = state.currentBet;
    final showAssist = state.showDecisionAssist;
    _game = BlackjackGame(rules: rules);
    state = BlackjackState(
      rules: rules,
      playerCards: const [],
      dealerCards: const [],
      gameState: GameState.idle,
      roundActive: false,
      resultMessage: null,
      isActionLocked: false,
      currentBet: bet,
      showDecisionAssist: showAssist,
      perfectPlay: true,
      lastXpResult: null,
      lastRoundPayout: null,
      winRates: null,
    );
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    super.dispose();
  }

  void startNewRound() {
    // Cancel any pending auto-reset before dealing — user acted first.
    _autoResetTimer?.cancel();
    _autoResetTimer = null;

    // Single-flight guard: drop duplicate calls while already processing.
    if (_busy) {
      assert(false, '[BlackjackController] startNewRound called while busy – ignored');
      return;
    }

    // Phase validation: only allowed from idle or any terminal state.
    final canStart = _game.state == GameState.idle || _game.isGameOver;
    if (!canStart) {
      debugPrint('[BlackjackController] Cannot start new round from state: ${_game.state}');
      return;
    }

    _busy = true;

    // Reshuffle check: if a counting session is active and the shoe is low,
    // create a fresh game (new shuffled shoe) and notify the session.
    final countingActive =
        _ref.read(countingSessionProvider).sessionActive;
    if (countingActive &&
        _game.shoe.cardsRemaining <= kCountingReshuffleCards) {
      final rules = state.rules;
      _game = BlackjackGame(rules: rules);
      _ref
          .read(countingSessionProvider.notifier)
          .onReshuffle(_game.shoe.cardsRemaining);
    }

    // Reset per-round card-reveal tracking.
    _reportedPerHand = [];
    _reportedDealerCards = 0;
    _wasSplit = false;

    // Reset per-round tracking fields and lock the UI.
    // Uses explicit construction to clear lastXpResult (not in copyWith).
    state = BlackjackState(
      rules: state.rules,
      playerCards: state.playerCards,
      dealerCards: state.dealerCards,
      gameState: state.gameState,
      roundActive: state.roundActive,
      resultMessage: state.resultMessage,
      isActionLocked: true,
      currentBet: state.currentBet,
      showDecisionAssist: state.showDecisionAssist,
      perfectPlay: true,       // reset for new round
      lastXpResult: null,      // clear previous round's XP display
      lastRoundPayout: null,   // clear previous round's payout
      winRates: null,
    );

    try {
      debugPrint('[BlackjackController] Starting new round (state: ${_game.state})');
      // Reset so _syncState() sees non-terminal → terminal for immediate BJ/push.
      _previousGameState = GameState.idle;
      _game.startNewRound();
      // _syncState() MUST precede playSfx: it sets isActionLocked: false.
      _syncState();
      debugPrint('[BlackjackController] Round started – new state: ${_game.state}');
      try {
        _ref.read(audioServiceProvider.notifier).playSfx(SfxType.deal);
      } catch (_) {}
    } finally {
      _busy = false;
    }
  }

  void hit() {
    if (_busy) return;
    if (!_game.canPlayerHit) return;

    _busy = true;
    try {
      _checkPerfectPlay(StrategyAction.hit);
      _game.playerHit();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  void stand() {
    if (_busy || !_game.canPlayerStand) return;

    _busy = true;
    try {
      _checkPerfectPlay(StrategyAction.stand);
      _game.playerStand();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  void doubleDown() {
    if (_busy || !_game.canPlayerDouble) return;
    // Guard: coins must cover ALL bets placed so far PLUS the new doubled bet,
    // because a loss settles every wager at once (no pre-deductions during play).
    final coins = _ref.read(economyControllerProvider).valueOrNull?.coins ?? 0;
    final requiredCoins = (_totalBetsInRound() + 1) * state.currentBet;
    if (coins < requiredCoins) return;

    if (kDebugMode) {
      debugPrint('[Economy] doubleDown: bet=${state.currentBet} '
          'existingBets=${_totalBetsInRound()} coins=$coins required=$requiredCoins');
    }

    _busy = true;
    try {
      _checkPerfectPlay(StrategyAction.doubleDown);
      // No pre-deduction: the full doubled wager is settled at round end via
      // effectiveBet in _computeRoundPayout().
      _game.playerDouble();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  void split() {
    if (_busy || !_game.canPlayerSplit) return;
    // Guard: same logic — player must be able to cover both hands losing.
    final coins = _ref.read(economyControllerProvider).valueOrNull?.coins ?? 0;
    final requiredCoins = (_totalBetsInRound() + 1) * state.currentBet;
    if (coins < requiredCoins) return;

    if (kDebugMode) {
      debugPrint('[Economy] split: bet=${state.currentBet} '
          'existingBets=${_totalBetsInRound()} coins=$coins required=$requiredCoins');
    }

    _busy = true;
    try {
      _checkPerfectPlay(StrategyAction.split);
      // No pre-deduction: both hand bets are settled at round end.
      _game.playerSplit();
      _syncState();
    } finally {
      _busy = false;
    }
  }

  /// Toggles the Decision Assist (Win%) feature on/off.
  /// When turned off, Monte Carlo computation is not run. When turned on during
  /// playerTurn, simulation is triggered immediately.
  void toggleDecisionAssist() {
    final next = !state.showDecisionAssist;
    state = BlackjackState(
      rules: state.rules,
      playerCards: state.playerCards,
      dealerCards: state.dealerCards,
      gameState: state.gameState,
      roundActive: state.roundActive,
      resultMessage: state.resultMessage,
      isActionLocked: state.isActionLocked,
      currentBet: state.currentBet,
      showDecisionAssist: next,
      perfectPlay: state.perfectPlay,
      lastXpResult: state.lastXpResult,
      lastRoundPayout: state.lastRoundPayout,
      winRates: null, // clear either way; sim will refill if needed
      hasSplit: state.hasSplit,
      activeHandIndex: state.activeHandIndex,
      allPlayerHands: state.allPlayerHands,
      handsDoubled: state.handsDoubled,
      handOutcomes: state.handOutcomes,
      canDouble: state.canDouble,
      canSplit: state.canSplit,
    );
    if (next && state.gameState == GameState.playerTurn) {
      _triggerWinRateSimulation();
    }
  }

  // ── Counting session controls ─────────────────────────────────────────────

  /// Starts a Hi-Lo counting session, resetting RC to 0.
  void startCountingSession() {
    _ref
        .read(countingSessionProvider.notifier)
        .startSession(_game.shoe.cardsRemaining);
  }

  /// Stops the counting session (toggle off or screen disposed).
  void stopCountingSession() {
    _ref.read(countingSessionProvider.notifier).stopSession();
  }

  /// After every [_syncState] call: compute which cards became face-up since
  /// the last sync and report them to the counting session.
  ///
  /// Tracking strategy:
  ///  - [_reportedPerHand] holds how many cards of each player hand have
  ///    already been counted.  On split detection it is reset to [1, 1] so
  ///    only the newly-dealt second cards of each new hand are counted.
  ///  - [_reportedDealerCards] tracks dealer cards; during playerTurn only the
  ///    upcard (index 0) is visible — the hole card is revealed later.
  void _notifyCountingSession() {
    final session = _ref.read(countingSessionProvider);
    if (!session.sessionActive) return;

    final newCards = <Card>[];

    // ── Player hands ────────────────────────────────────────────────────────
    // Detect split: if the game just split, reset per-hand tracking so only
    // the freshly-dealt second cards of each new hand are counted.
    if (_game.hasSplit && !_wasSplit) {
      _wasSplit = true;
      _reportedPerHand = [1, 1]; // one original card per hand already counted
    }

    // Expand tracking list to cover any new hands.
    while (_reportedPerHand.length < _game.playerHands.length) {
      _reportedPerHand.add(0);
    }

    for (int i = 0; i < _game.playerHands.length; i++) {
      final cards = _game.playerHands[i].cards;
      final reported = _reportedPerHand[i];
      if (cards.length > reported) {
        newCards.addAll(cards.sublist(reported));
        _reportedPerHand[i] = cards.length;
      }
    }

    // ── Dealer cards ────────────────────────────────────────────────────────
    // Upcard is visible from the start; hole card + hit cards become visible
    // once playerTurn ends.
    final dealerCards = _game.dealerHand.cards;
    final dealerVisibleNow = (_game.state == GameState.playerTurn)
        ? (dealerCards.isEmpty ? 0 : 1)
        : dealerCards.length;

    if (dealerVisibleNow > _reportedDealerCards) {
      newCards.addAll(
          dealerCards.sublist(_reportedDealerCards, dealerVisibleNow));
      _reportedDealerCards = dealerVisibleNow;
    }

    _ref
        .read(countingSessionProvider.notifier)
        .notifyCards(newCards, _game.shoe.cardsRemaining);
  }

  /// Updates the player's bet. No-op during active play.
  void setBet(int bet) {
    if (state.gameState == GameState.playerTurn ||
        state.gameState == GameState.dealerTurn) {
      return;
    }
    state = state.copyWith(currentBet: bet);
  }

  void reset() {
    _autoResetTimer?.cancel();
    _autoResetTimer = null;
    _simGeneration++;   // discard any in-flight simulation
    _previousGameState = GameState.idle;
    // Preserve bet, decision assist, and rules across navigation.
    final bet = state.currentBet;
    final showAssist = state.showDecisionAssist;
    final rules = state.rules;
    _game = BlackjackGame(rules: rules);
    state = BlackjackState(
      rules: rules,
      playerCards: const [],
      dealerCards: const [],
      gameState: GameState.idle,
      roundActive: false,
      resultMessage: null,
      isActionLocked: false,
      currentBet: bet,
      showDecisionAssist: showAssist,
      perfectPlay: true,
      lastXpResult: null,
      lastRoundPayout: null,
      winRates: null,
    );
  }

  void _syncState() {
    final currentRoundActive = _game.canPlayerHit || _game.canPlayerStand;
    // Capture user preferences and per-round tracking before overwriting state.
    final bet = state.currentBet;
    final showAssist = state.showDecisionAssist;
    final perfectPlay = state.perfectPlay;
    final lastXpResult = state.lastXpResult;
    final lastRoundPayout = state.lastRoundPayout;
    final rules = state.rules;
    final previousGameState = _previousGameState;

    // Snapshot all player hands.
    final allHands = _game.playerHands.map((h) => h.cards.toList()).toList();
    final activeCards = _game.isGameOver
        ? allHands[0]
        : allHands[_game.activeHandIndex];

    // Coin check for double/split: player must be able to cover all current bets
    // PLUS one more.  Uses the same formula as the action guards so UI and engine
    // are always consistent (Part 4 requirement).
    final currentCoins =
        _ref.read(economyControllerProvider).valueOrNull?.coins ?? 0;
    final existingBets = _totalBetsInRound();
    final canAffordNextBet = currentCoins >= (existingBets + 1) * bet;

    state = BlackjackState(
      rules: rules,
      playerCards: activeCards,
      dealerCards: _game.dealerHand.cards.toList(),
      gameState: _game.state,
      roundActive: currentRoundActive,
      resultMessage: _getResultMessage(_game),
      isActionLocked: false,      // unlock after state is committed
      currentBet: bet,            // preserve selected bet across syncs
      showDecisionAssist: showAssist, // preserve user preference
      perfectPlay: perfectPlay,         // preserve until round ends or new round starts
      lastXpResult: lastXpResult,       // preserve until cleared or new round
      lastRoundPayout: lastRoundPayout, // preserve until cleared or new round
      winRates: null,                   // cleared; re-computed below if playerTurn + assist on
      hasSplit: _game.hasSplit,
      activeHandIndex: _game.activeHandIndex,
      allPlayerHands: allHands,
      handsDoubled: List.of(_game.handDoubled),
      handOutcomes: _game.handOutcomes.isNotEmpty ? List.of(_game.handOutcomes) : null,
      // Gate both on game rules AND coin availability — single source of truth.
      canDouble: _game.canPlayerDouble && canAffordNextBet,
      canSplit: _game.canPlayerSplit && canAffordNextBet,
    );

    // Record stats, award coins, and award XP when round just ended.
    // Use non-terminal → terminal transition so immediate blackjack is caught.
    final isNowTerminal = _isTerminalState(_game.state);
    final wasTerminal   = _isTerminalState(previousGameState);
    if (!wasTerminal && isNowTerminal) {
      debugPrint('[Perf] instrumentation alive – round_ended');
      RebuildCounter.printAndReset('round_ended');
      FramePerfMonitor.printAndReset('round_ended');

      // Use the best hand outcome for stats recording.
      final representativeState = _game.hasSplit
          ? _representativeSplitOutcome(_game.handOutcomes)
          : _game.state;
      _ref.read(statsControllerProvider.notifier).recordRound(representativeState);
      _ref.read(weeklyGoalControllerProvider.notifier).recordHand();

      // Progression hooks — fire-and-forget, safe if not initialized.
      ProgressionManager.instance.onGameHandPlayed();
      if (representativeState == GameState.playerWin ||
          representativeState == GameState.dealerBust ||
          representativeState == GameState.playerBlackjack) {
        ProgressionManager.instance.onGameHandWon();
      }

      // Compute payout — for split, sum per-hand payouts.
      final payout = _computeRoundPayout();
      final coinsBeforePayout =
          _ref.read(economyControllerProvider).valueOrNull?.coins ?? 0;
      _ref.read(economyControllerProvider.notifier).addCoins(payout);

      // Single authoritative XP calculation — result used for both award + UI.
      final xpResult = computeHandXP(representativeState, bet);
      _ref.read(progressionControllerProvider.notifier).awardXP(xpResult.total);

      if (kDebugMode) {
        debugPrint(
          '[XP] +${xpResult.total} XP  '
          'base=${xpResult.base}  win=${xpResult.winBonus}  '
          'bj=${xpResult.bjBonus}  bet=${xpResult.betBonus}',
        );
      }

      final stats = _ref.read(statsControllerProvider).value;
      if (stats != null) {
        _ref.read(progressionControllerProvider.notifier).checkMilestones(stats.handsPlayed);
      }

      // Store XP result in state so the UI can display the "+N XP" chip.
      // Explicit construction required (lastXpResult excluded from copyWith).
      state = BlackjackState(
        rules: state.rules,
        playerCards: state.playerCards,
        dealerCards: state.dealerCards,
        gameState: state.gameState,
        roundActive: state.roundActive,
        resultMessage: state.resultMessage,
        isActionLocked: state.isActionLocked,
        currentBet: state.currentBet,
        showDecisionAssist: state.showDecisionAssist,
        perfectPlay: state.perfectPlay,
        lastXpResult: xpResult,
        lastRoundPayout: payout,
        winRates: null,
        hasSplit: state.hasSplit,
        activeHandIndex: state.activeHandIndex,
        allPlayerHands: state.allPlayerHands,
        handsDoubled: state.handsDoubled,
        handOutcomes: state.handOutcomes,
        canDouble: state.canDouble,
        canSplit: state.canSplit,
      );

      // Record session stats (win streak, win rate, net coins, XP).
      _ref.read(sessionStatsProvider.notifier).recordHand(
            outcome: representativeState,
            coinDelta: payout,
            xpEarned: xpResult.total,
          );

      // SFX for round outcome.
      final sfx = _sfxForOutcome(representativeState);
      if (sfx != null) {
        try {
          _ref.read(audioServiceProvider.notifier).playSfx(sfx);
        } catch (_) {}
      }

      // Auto-clamp bet if a loss drops coins below the current bet.
      final newCoins = coinsBeforePayout + payout;
      final clampedBet = clampBetToCoins(bet, newCoins);
      if (clampedBet != bet) {
        state = state.copyWith(currentBet: clampedBet);
      }

      // Schedule auto-reset: clear the table after 3 seconds if user hasn't
      // tapped DEAL.  startNewRound() cancels this timer if user acts first.
      _scheduleAutoReset();
    }

    _previousGameState = _game.state;

    // Report newly visible cards to the Hi-Lo counting session (if active).
    _notifyCountingSession();

    if (_game.state == GameState.playerTurn && showAssist) {
      _triggerWinRateSimulation();
    }
  }

  /// Returns true for every state that represents a completed round.
  bool _isTerminalState(GameState s) => switch (s) {
        GameState.playerWin ||
        GameState.dealerWin ||
        GameState.playerBust ||
        GameState.dealerBust ||
        GameState.push ||
        GameState.playerBlackjack =>
          true,
        _ => false,
      };

  /// Total number of bet-units committed in this round.
  ///
  /// Each hand counts as one bet; each doubled hand adds one more.
  /// Used to gate double/split so the player can always cover the worst-case
  /// loss of every wager (no pre-deductions are taken during play).
  ///
  ///   Normal:               1 hand  + 0 doubles = 1
  ///   Normal + double:      1 hand  + 1 double  = 2
  ///   Split (no double):    2 hands + 0 doubles = 2
  ///   Split + DAS hand 0:   2 hands + 1 double  = 3
  ///   Split + DAS both:     2 hands + 2 doubles = 4
  int _totalBetsInRound() =>
      _game.playerHands.length +
      _game.handDoubled.where((d) => d).length;

  /// Computes net payout for the entire round, accounting for split and doubled hands.
  ///
  /// No pre-deductions are taken during play, so this function always uses
  /// the full effective bet (2× for doubled hands) in [computeBetPayout].
  int _computeRoundPayout() {
    final bet = state.currentBet;
    final bjPayout = state.rules.blackjackPayout;
    if (!_game.hasSplit) {
      // Single hand: use 2× bet when doubled so win/push correctly profit/break even.
      final effectiveBet =
          (_game.handDoubled.isNotEmpty && _game.handDoubled[0]) ? bet * 2 : bet;
      final payout = computeBetPayout(_game.state, effectiveBet,
          blackjackPayout: bjPayout);
      if (kDebugMode) {
        debugPrint('[Economy] payout: outcome=${_game.state} bet=$bet '
            'doubled=${_game.handDoubled.isNotEmpty && _game.handDoubled[0]} '
            'effectiveBet=$effectiveBet payout=$payout');
      }
      return payout;
    }
    // Split: sum per-hand payouts with per-hand effective bets.
    int total = 0;
    for (int i = 0; i < _game.handOutcomes.length; i++) {
      final effectiveBet = _game.handDoubled[i] ? bet * 2 : bet;
      final handPayout = computeBetPayout(_game.handOutcomes[i], effectiveBet,
          blackjackPayout: bjPayout);
      if (kDebugMode) {
        debugPrint('[Economy] split hand $i: outcome=${_game.handOutcomes[i]} '
            'doubled=${_game.handDoubled[i]} effectiveBet=$effectiveBet '
            'payout=$handPayout');
      }
      total += handPayout;
    }
    if (kDebugMode) debugPrint('[Economy] split total payout: $total');
    return total;
  }

  /// Derives a representative GameState for stats/XP from split hand outcomes.
  GameState _representativeSplitOutcome(List<GameState> outcomes) {
    final anyWin = outcomes.any((o) =>
        o == GameState.playerWin ||
        o == GameState.dealerBust ||
        o == GameState.playerBlackjack);
    if (anyWin) return GameState.playerWin;
    final anyPush = outcomes.any((o) => o == GameState.push);
    if (anyPush) return GameState.push;
    return GameState.playerBust;
  }

  /// Schedules the table to auto-clear 3 seconds after a round ends.
  void _scheduleAutoReset() {
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(seconds: 3), _autoReset);
  }

  /// Clears the table to a clean idle state, preserving user preferences.
  /// Called by the auto-reset timer; also see [reset] for full resets.
  void _autoReset() {
    _autoResetTimer = null;
    if (!mounted) return;
    final bet = state.currentBet;
    final showAssist = state.showDecisionAssist;
    final rules = state.rules;
    _game = BlackjackGame(rules: rules);
    _previousGameState = GameState.idle;
    state = BlackjackState(
      rules: rules,
      playerCards: const [],
      dealerCards: const [],
      gameState: GameState.idle,
      roundActive: false,
      resultMessage: null,
      isActionLocked: false,
      currentBet: bet,
      showDecisionAssist: showAssist,
      perfectPlay: true,
      lastXpResult: null,
      lastRoundPayout: null,
      winRates: null,
    );
  }

  /// Returns the set of actions currently available to the player.
  Set<StrategyAction> _availableActions() {
    return {
      if (_game.canPlayerHit) StrategyAction.hit,
      if (_game.canPlayerStand) StrategyAction.stand,
      if (_game.canPlayerDouble) StrategyAction.doubleDown,
      if (_game.canPlayerSplit) StrategyAction.split,
    };
  }

  /// Checks if [playerAction] matches basic strategy for the current position.
  /// If it doesn't match, marks [perfectPlay] = false.
  ///
  /// Uses [BasicStrategy.recommendFallback] with the real available set so that
  /// scoring is accurate for double/split decisions.
  /// Fails silently if the strategy lookup throws (edge cases, empty hands, etc.).
  void _checkPerfectPlay(StrategyAction playerAction) {
    try {
      if (_game.dealerHand.cards.isEmpty) return;
      final dealerUpcard = _game.dealerHand.cards[0].rank;
      final recommended = BasicStrategy.recommendFallback(
        playerCards: _game.playerHand.cards.toList(),
        dealerUpcard: dealerUpcard,
        availableActions: _availableActions(),
      );
      if (recommended != playerAction) {
        state = state.copyWith(perfectPlay: false);
      }
    } catch (_) {
      // Fail silently — don't penalize the player for engine edge cases.
    }
  }

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
      if (_simGeneration != gen) return; // superseded by newer position
      if (!mounted) return;
      if (state.gameState != GameState.playerTurn) return;
      if (!state.showDecisionAssist) return; // user toggled off while sim ran
      state = BlackjackState(
        rules: state.rules,
        playerCards: state.playerCards,
        dealerCards: state.dealerCards,
        gameState: state.gameState,
        roundActive: state.roundActive,
        resultMessage: state.resultMessage,
        isActionLocked: state.isActionLocked,
        currentBet: state.currentBet,
        showDecisionAssist: state.showDecisionAssist,
        perfectPlay: state.perfectPlay,
        lastXpResult: state.lastXpResult,
        lastRoundPayout: state.lastRoundPayout,
        winRates: result,
        hasSplit: state.hasSplit,
        activeHandIndex: state.activeHandIndex,
        allPlayerHands: state.allPlayerHands,
        handsDoubled: state.handsDoubled,
        handOutcomes: state.handOutcomes,
        canDouble: state.canDouble,
        canSplit: state.canSplit,
      );
    });
  }

  SfxType? _sfxForOutcome(GameState gameState) => switch (gameState) {
    GameState.playerWin ||
    GameState.dealerBust ||
    GameState.playerBlackjack => SfxType.win,
    GameState.dealerWin ||
    GameState.playerBust      => SfxType.lose,
    _                         => null,
  };

  String? _getResultMessage(BlackjackGame game) {
    if (!game.isGameOver) {
      return game.state == GameState.playerTurn ? null : null;
    }

    if (game.hasSplit && game.handOutcomes.length == 2) {
      // Split result: show per-hand outcomes.
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
      GameState.idle => null,
      GameState.playerTurn => null,
      GameState.dealerTurn => null,
      GameState.playerBlackjack => 'Blackjack!',
      GameState.playerWin => 'You win!',
      GameState.dealerWin => 'Dealer wins',
      GameState.playerBust => 'Bust!',
      GameState.dealerBust => 'Dealer busts - You win!',
      GameState.push => 'Push!',
    };
  }
}

final blackjackControllerProvider =
    StateNotifierProvider<BlackjackController, BlackjackState>((ref) {
  return BlackjackController(ref);
});
