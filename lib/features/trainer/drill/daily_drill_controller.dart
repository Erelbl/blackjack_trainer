import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/providers/economy_providers.dart';
import '../../../engine/models/card.dart';
import '../../../engine/models/rank.dart';
import '../../../engine/models/suit.dart';
import '../../../engine/strategy/basic_strategy.dart';
import '../../../engine/utils/hand_evaluator.dart';
import 'drill_engine.dart'; // DrillPosition (shared data class)

// ── Day helpers ───────────────────────────────────────────────────────────────

/// Returns an integer seed unique to today's local date (YYYYMMDD).
int _dailySeed() {
  final now        = DateTime.now();
  final normalized = DateTime(now.year, now.month, now.day);
  return int.parse(
    '${normalized.year}'
    '${normalized.month.toString().padLeft(2, '0')}'
    '${normalized.day.toString().padLeft(2, '0')}',
  );
}

/// SharedPreferences key scoped to today's date.
String _todayKey() => 'daily_drill_${_dailySeed()}';

// ── Seeded engine (local — never touches DrillEngine or its Random) ───────────

class _SeededEngine {
  static const _ranks = Rank.values;
  static const _suits = Suit.values;

  final Random _rng;

  _SeededEngine(this._rng);

  Card _card() => Card(
        rank: _ranks[_rng.nextInt(_ranks.length)],
        suit: _suits[_rng.nextInt(_suits.length)],
      );

  /// Returns a non-blackjack two-card hand with a random dealer upcard.
  DrillPosition nextPosition() {
    while (true) {
      final c1    = _card();
      final c2    = _card();
      final cards = [c1, c2];
      if (!HandEvaluator.evaluate(cards).isBlackjack) {
        return DrillPosition(
          playerCards:  List.unmodifiable(cards),
          dealerUpcard: _ranks[_rng.nextInt(_ranks.length)],
        );
      }
    }
  }
}

// ── State ─────────────────────────────────────────────────────────────────────

class DailyDrillState {
  final int remainingSeconds;
  final DrillPosition? currentPosition;
  final int correct;
  final int wrong;
  final int totalAnswered;
  final bool running;
  final bool finished;

  /// Today's persisted best score (0 = not played yet today).
  final int bestScore;

  /// Whether today's coin reward has been claimed.
  final bool claimed;

  /// True only for the run that just beat today's best.
  final bool isNewBest;

  const DailyDrillState({
    this.remainingSeconds = 60,
    this.currentPosition,
    this.correct        = 0,
    this.wrong          = 0,
    this.totalAnswered  = 0,
    this.running        = false,
    this.finished       = false,
    this.bestScore      = 0,
    this.claimed        = false,
    this.isNewBest      = false,
  });

  /// Daily Drill score:
  ///   (correct × 100) + (accuracyPercent × 5).round() + (handsPlayed × 10)
  int get drillScore {
    final acc = totalAnswered == 0 ? 0.0 : correct / totalAnswered * 100.0;
    return (correct * 100) + (acc * 5).round() + (totalAnswered * 10);
  }

  double get accuracyPercent =>
      totalAnswered == 0 ? 0.0 : correct / totalAnswered * 100.0;

  /// Coin reward tier for the given score.
  static int rewardForScore(int score) {
    if (score >= 6000) return 500;
    if (score >= 4000) return 350;
    if (score >= 2000) return 200;
    return 100;
  }

  DailyDrillState copyWith({
    int?          remainingSeconds,
    DrillPosition? currentPosition,
    int?          correct,
    int?          wrong,
    int?          totalAnswered,
    bool?         running,
    bool?         finished,
    int?          bestScore,
    bool?         claimed,
    bool?         isNewBest,
  }) =>
      DailyDrillState(
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        currentPosition:  currentPosition  ?? this.currentPosition,
        correct:          correct          ?? this.correct,
        wrong:            wrong            ?? this.wrong,
        totalAnswered:    totalAnswered    ?? this.totalAnswered,
        running:          running          ?? this.running,
        finished:         finished         ?? this.finished,
        bestScore:        bestScore        ?? this.bestScore,
        claimed:          claimed          ?? this.claimed,
        isNewBest:        isNewBest        ?? this.isNewBest,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class DailyDrillController extends StateNotifier<DailyDrillState> {
  final Ref _ref;
  _SeededEngine? _engine;
  Timer? _ticker;

  DailyDrillController(this._ref) : super(const DailyDrillState()) {
    _loadDailyState();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadDailyState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json  = prefs.getString(_todayKey());
      if (json == null) return;
      final map = jsonDecode(json) as Map<String, dynamic>;
      if (mounted) {
        state = state.copyWith(
          bestScore: (map['bestScore'] as int?)  ?? 0,
          claimed:   (map['claimed']   as bool?) ?? false,
        );
      }
    } catch (_) {}
  }

  Future<void> _saveDailyState(int bestScore, bool claimed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _todayKey(),
        jsonEncode({'bestScore': bestScore, 'claimed': claimed}),
      );
    } catch (_) {}
  }

  // ── Drill lifecycle ──────────────────────────────────────────────────────────

  void startDrill() {
    if (state.running) return;
    _ticker?.cancel();
    _engine = _SeededEngine(Random(_dailySeed()));
    state = DailyDrillState(
      remainingSeconds: 60,
      currentPosition:  _engine!.nextPosition(),
      running:          true,
      bestScore:        state.bestScore,
      claimed:          state.claimed,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _onTick(Timer _) {
    final next = state.remainingSeconds - 1;
    if (next <= 0) {
      _ticker?.cancel();
      _finishDrill();
    } else {
      state = state.copyWith(remainingSeconds: next);
    }
  }

  Future<void> _finishDrill() async {
    final score     = state.drillScore;
    final isNewBest = score > state.bestScore;
    final newBest   = isNewBest ? score : state.bestScore;

    state = state.copyWith(
      remainingSeconds: 0,
      running:          false,
      finished:         true,
      isNewBest:        isNewBest,
      bestScore:        newBest,
    );

    if (isNewBest) {
      await _saveDailyState(newBest, state.claimed);
    }
  }

  // ── Answering ────────────────────────────────────────────────────────────────

  void answer(StrategyAction action) {
    final engine = _engine;
    if (!state.running || state.currentPosition == null || engine == null) return;

    final pos      = state.currentPosition!;
    final expected = BasicStrategy.recommendFallback(
      playerCards:      pos.playerCards,
      dealerUpcard:     pos.dealerUpcard,
      availableActions: const {StrategyAction.hit, StrategyAction.stand},
    );

    final isCorrect  = action == expected;
    final newCorrect = state.correct + (isCorrect ? 1 : 0);
    final newWrong   = state.wrong   + (isCorrect ? 0 : 1);
    final newTotal   = state.totalAnswered + 1;

    state = state.copyWith(
      correct:         newCorrect,
      wrong:           newWrong,
      totalAnswered:   newTotal,
      currentPosition: engine.nextPosition(),
    );
  }

  // ── Reward ───────────────────────────────────────────────────────────────────

  Future<void> claimReward() async {
    if (state.claimed || state.bestScore == 0) return;
    final coins = DailyDrillState.rewardForScore(state.bestScore);
    await _ref.read(economyControllerProvider.notifier).addCoins(coins);
    state = state.copyWith(claimed: true);
    await _saveDailyState(state.bestScore, true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Not auto-disposed — state (bestScore/claimed) must survive tab navigation.
final dailyDrillControllerProvider =
    StateNotifierProvider<DailyDrillController, DailyDrillState>(
  (ref) => DailyDrillController(ref),
);
