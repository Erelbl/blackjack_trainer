import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../engine/strategy/basic_strategy.dart';
import '../../../services/analytics_service.dart';
import 'drill_engine.dart';

/// Shared SharedPreferences key for the Speed Drill personal-best score.
/// Used by [DrillController], [SpeedDrillLobbyScreen], and [StatsScreen] —
/// never duplicated as a raw string elsewhere.
const kDrillBestScoreKey = 'speed_drill_best_score';

// ── State ─────────────────────────────────────────────────────────────────────

class DrillState {
  final int remainingSeconds;
  final DrillPosition? currentPosition;
  final int correct;
  final int wrong;
  final int totalAnswered;
  final double averageReactionMs;
  final bool running;
  final bool finished;
  /// All-time personal best score (correct − wrong). 0 = no best yet.
  final int personalBest;
  /// True only for the run that just beat the previous personal best.
  final bool isNewPb;

  const DrillState({
    this.remainingSeconds = 60,
    this.currentPosition,
    this.correct = 0,
    this.wrong = 0,
    this.totalAnswered = 0,
    this.averageReactionMs = 0.0,
    this.running = false,
    this.finished = false,
    this.personalBest = 0,
    this.isNewPb = false,
  });

  int get finalScore => correct - wrong;
  double get accuracy =>
      totalAnswered == 0 ? 0.0 : correct / totalAnswered * 100.0;

  DrillState copyWith({
    int? remainingSeconds,
    DrillPosition? currentPosition,
    int? correct,
    int? wrong,
    int? totalAnswered,
    double? averageReactionMs,
    bool? running,
    bool? finished,
    int? personalBest,
    bool? isNewPb,
  }) =>
      DrillState(
        remainingSeconds:  remainingSeconds  ?? this.remainingSeconds,
        currentPosition:   currentPosition   ?? this.currentPosition,
        correct:           correct           ?? this.correct,
        wrong:             wrong             ?? this.wrong,
        totalAnswered:     totalAnswered     ?? this.totalAnswered,
        averageReactionMs: averageReactionMs ?? this.averageReactionMs,
        running:           running           ?? this.running,
        finished:          finished          ?? this.finished,
        personalBest:      personalBest      ?? this.personalBest,
        isNewPb:           isNewPb           ?? this.isNewPb,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class DrillController extends StateNotifier<DrillState> {
  final Ref _ref;
  final _engine = DrillEngine();
  Timer? _ticker;
  DateTime? _questionStart;

  DrillController(this._ref) : super(const DrillState()) {
    _loadBest();
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final best = prefs.getInt(kDrillBestScoreKey) ?? 0;
      if (mounted) state = state.copyWith(personalBest: best);
    } catch (_) {}
  }

  Future<void> _saveBest(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(kDrillBestScoreKey, score);
    } catch (_) {}
  }

  // ── Drill lifecycle ──────────────────────────────────────────────────────────

  void startDrill() {
    _ticker?.cancel();
    _questionStart = DateTime.now();
    state = DrillState(
      remainingSeconds: 60,
      currentPosition:  _engine.nextPosition(),
      running:          true,
      personalBest:     state.personalBest, // carry forward loaded best
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    AnalyticsService.instance.logSpeedDrillStart();
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
    final score   = state.finalScore;
    final isNewPb = score > state.personalBest;
    final newBest = isNewPb ? score : state.personalBest;

    state = state.copyWith(
      remainingSeconds: 0,
      running:          false,
      finished:         true,
      isNewPb:          isNewPb,
      personalBest:     newBest,
    );
    AnalyticsService.instance.logSpeedDrillEnd(
      score:           score,
      durationSeconds: 60,
      correctAnswers:  state.correct,
      totalAnswers:    state.totalAnswered,
    );

    if (isNewPb) {
      await _saveBest(newBest);
      // Invalidate so the lobby and stats screens reload the updated PB.
      _ref.invalidate(drillBestScoreProvider);
    }
  }

  // ── Answering ────────────────────────────────────────────────────────────────

  /// Records a player answer. Only [StrategyAction.hit] and
  /// [StrategyAction.stand] are valid — Double/Split are absent from the UI.
  void answer(StrategyAction action) {
    if (!state.running || state.currentPosition == null) return;

    final reactionMs = _questionStart != null
        ? DateTime.now().difference(_questionStart!).inMilliseconds.toDouble()
        : 0.0;

    final pos = state.currentPosition!;
    final expected = BasicStrategy.recommendFallback(
      playerCards:      pos.playerCards,
      dealerUpcard:     pos.dealerUpcard,
      availableActions: const {StrategyAction.hit, StrategyAction.stand},
    );

    final isCorrect  = action == expected;
    final newCorrect = state.correct + (isCorrect ? 1 : 0);
    final newWrong   = state.wrong   + (isCorrect ? 0 : 1);
    final newTotal   = state.totalAnswered + 1;
    final newAvg =
        (state.averageReactionMs * state.totalAnswered + reactionMs) / newTotal;

    _questionStart = DateTime.now();
    state = state.copyWith(
      correct:           newCorrect,
      wrong:             newWrong,
      totalAnswered:     newTotal,
      averageReactionMs: newAvg,
      currentPosition:   _engine.nextPosition(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Reads the personal-best score from SharedPreferences once.
/// Auto-disposed and invalidated by [DrillController] after a new PB is saved,
/// so the lobby and stats screens always show a fresh value.
final drillBestScoreProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(kDrillBestScoreKey) ?? 0;
  } catch (_) {
    return 0;
  }
});

/// Auto-disposed so the drill resets each time the screen is popped.
final drillControllerProvider =
    StateNotifierProvider.autoDispose<DrillController, DrillState>(
  (ref) => DrillController(ref),
);
