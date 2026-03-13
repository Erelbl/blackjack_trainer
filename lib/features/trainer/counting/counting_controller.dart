import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/card.dart';
import '../../../engine/models/rank.dart';
import '../../../engine/models/suit.dart';
import 'counting_config.dart';
import '../../../services/analytics_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

/// Number of decks in the counting shoe.
const kCountingDecks = 6;

// ── Hi-Lo ─────────────────────────────────────────────────────────────────────

/// Hi-Lo count value for a rank.
/// 2–6 → +1 | 7–9 → 0 | 10/J/Q/K/A → −1
int hiLoValue(Rank rank) => switch (rank) {
      Rank.two ||
      Rank.three ||
      Rank.four ||
      Rank.five ||
      Rank.six =>
        1,
      Rank.seven || Rank.eight || Rank.nine => 0,
      _ => -1,
    };

// ── State ─────────────────────────────────────────────────────────────────────

enum CountingPhase { idle, running, ended }

class CountingTrainerState {
  final CountingPhase phase;
  final CountingSessionDuration selectedDuration;
  final CountingCardPace selectedPace;
  final int timeLeft;
  final int runningCountActual;
  final int cardsShown;
  final Card? currentCard;
  final int? userAnswer;

  /// null = not submitted; true = correct; false = wrong.
  final bool? result;

  const CountingTrainerState({
    this.phase            = CountingPhase.idle,
    this.selectedDuration = CountingSessionDuration.s60,
    this.selectedPace     = CountingCardPace.ms1500,
    this.timeLeft         = 60, // matches selectedDuration default
    this.runningCountActual = 0,
    this.cardsShown       = 0,
    this.currentCard,
    this.userAnswer,
    this.result,
  });

  /// Cards still unplayed in the shoe (informational).
  int get cardsRemaining => kCountingDecks * 52 - cardsShown;

  CountingTrainerState copyWith({
    CountingPhase? phase,
    CountingSessionDuration? selectedDuration,
    CountingCardPace? selectedPace,
    int? timeLeft,
    int? runningCountActual,
    int? cardsShown,
    Card? currentCard,
    int? userAnswer,
    bool? result,
  }) =>
      CountingTrainerState(
        phase:               phase               ?? this.phase,
        selectedDuration:    selectedDuration    ?? this.selectedDuration,
        selectedPace:        selectedPace        ?? this.selectedPace,
        timeLeft:            timeLeft            ?? this.timeLeft,
        runningCountActual:  runningCountActual  ?? this.runningCountActual,
        cardsShown:          cardsShown          ?? this.cardsShown,
        currentCard:         currentCard         ?? this.currentCard,
        userAnswer:          userAnswer          ?? this.userAnswer,
        result:              result              ?? this.result,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class CountingTrainerController
    extends StateNotifier<CountingTrainerState> {
  List<Card> _shoe = [];
  int _shoeIndex = 0;
  Timer? _countdownTimer;
  Timer? _revealTimer;

  CountingTrainerController() : super(const CountingTrainerState());

  // ── Settings ──────────────────────────────────────────────────────────────

  /// Change duration only when not running; resets to idle.
  void setDuration(CountingSessionDuration duration) {
    if (state.phase == CountingPhase.running) return;
    _cancelTimers();
    state = CountingTrainerState(
      selectedDuration: duration,
      selectedPace:     state.selectedPace,
      timeLeft:         duration.seconds,
    );
  }

  /// Change pace only when not running; resets to idle.
  void setPace(CountingCardPace pace) {
    if (state.phase == CountingPhase.running) return;
    _cancelTimers();
    state = CountingTrainerState(
      selectedDuration: state.selectedDuration,
      selectedPace:     pace,
      timeLeft:         state.selectedDuration.seconds,
    );
  }

  // ── Shoe ──────────────────────────────────────────────────────────────────

  void _buildShoe() {
    final rng = Random();
    _shoe = [
      for (final suit in Suit.values)
        for (final rank in Rank.values)
          for (int d = 0; d < kCountingDecks; d++) Card(rank: rank, suit: suit),
    ]..shuffle(rng);
    _shoeIndex = 0;
  }

  Card? _nextCard() {
    if (_shoeIndex >= _shoe.length) return null;
    return _shoe[_shoeIndex++];
  }

  // ── Session ───────────────────────────────────────────────────────────────

  void startSession() {
    _cancelTimers();
    _buildShoe();

    final first = _nextCard()!;
    state = CountingTrainerState(
      phase:              CountingPhase.running,
      selectedDuration:   state.selectedDuration,
      selectedPace:       state.selectedPace,
      timeLeft:           state.selectedDuration.seconds,
      runningCountActual: hiLoValue(first.rank),
      cardsShown:         1,
      currentCard:        first,
    );

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      _onCountdownTick,
    );
    _revealTimer = Timer.periodic(
      Duration(milliseconds: state.selectedPace.milliseconds),
      _onRevealTick,
    );
    AnalyticsService.instance.logCountingSessionStart(
      durationSeconds: state.selectedDuration.seconds,
    );
  }

  void _onCountdownTick(Timer _) {
    final next = state.timeLeft - 1;
    if (next <= 0) {
      _endSession();
    } else {
      state = state.copyWith(timeLeft: next);
    }
  }

  void _onRevealTick(Timer _) {
    if (state.phase != CountingPhase.running) return;
    final card = _nextCard();
    if (card == null) return; // shoe exhausted — won't happen in ≤90 s
    state = state.copyWith(
      currentCard:        card,
      cardsShown:         state.cardsShown + 1,
      runningCountActual: state.runningCountActual + hiLoValue(card.rank),
    );
  }

  void _endSession() {
    _cancelTimers();
    state = state.copyWith(phase: CountingPhase.ended, timeLeft: 0);
  }

  // ── Answer ────────────────────────────────────────────────────────────────

  void submitAnswer(int answer) {
    if (state.phase != CountingPhase.ended) return;
    state = state.copyWith(
      userAnswer: answer,
      result:     answer == state.runningCountActual,
    );
    AnalyticsService.instance.logCountingSessionEnd(
      durationSeconds: state.selectedDuration.seconds,
      score: state.cardsShown,
    );
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void _cancelTimers() {
    _countdownTimer?.cancel();
    _revealTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

/// Auto-disposed so each visit starts fresh.
final countingTrainerProvider = StateNotifierProvider.autoDispose<
    CountingTrainerController, CountingTrainerState>(
  (ref) => CountingTrainerController(),
);
