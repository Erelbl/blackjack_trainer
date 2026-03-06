import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../engine/models/card.dart';
import '../../../engine/models/rank.dart';

// Reshuffle threshold: 1.5 decks = 78 cards.
const int kCountingReshuffleCards = 78;

// ── State ─────────────────────────────────────────────────────────────────────

class CountingSessionState {
  final bool sessionActive;
  final int runningCount;
  final int cardsRemaining;
  /// Ephemeral: true for one frame after a reshuffle — cleared by UI.
  final bool showReshuffleToast;

  const CountingSessionState({
    this.sessionActive = false,
    this.runningCount = 0,
    this.cardsRemaining = 312,
    this.showReshuffleToast = false,
  });

  /// Decks remaining (floating-point).
  double get decksRemaining => cardsRemaining / 52.0;

  /// True count, truncated toward zero (standard Hi-Lo display format).
  int get trueCountDisplay {
    if (decksRemaining < 0.5) return runningCount;
    final tc = runningCount / decksRemaining;
    return tc >= 0 ? tc.floor() : tc.ceil();
  }

  CountingSessionState copyWith({
    bool? sessionActive,
    int? runningCount,
    int? cardsRemaining,
    bool? showReshuffleToast,
  }) {
    return CountingSessionState(
      sessionActive: sessionActive ?? this.sessionActive,
      runningCount: runningCount ?? this.runningCount,
      cardsRemaining: cardsRemaining ?? this.cardsRemaining,
      showReshuffleToast: showReshuffleToast ?? this.showReshuffleToast,
    );
  }
}

// ── Controller ────────────────────────────────────────────────────────────────

class CountingSessionController
    extends StateNotifier<CountingSessionState> {
  CountingSessionController() : super(const CountingSessionState());

  /// Begins (or restarts) a counting session.  Resets RC to 0.
  void startSession(int shoeCardsRemaining) {
    state = CountingSessionState(
      sessionActive: true,
      runningCount: 0,
      cardsRemaining: shoeCardsRemaining,
      showReshuffleToast: false,
    );
  }

  /// Ends the counting session (e.g. toggle off or PlayScreen disposed).
  void stopSession() {
    state = const CountingSessionState();
  }

  /// Called by [BlackjackController] after each state sync with the list of
  /// cards that became face-up since the last call.
  ///
  /// [shoeCardsRemaining] is always updated so TC stays accurate.
  void notifyCards(List<Card> cards, int shoeCardsRemaining) {
    if (!state.sessionActive) return;
    if (cards.isEmpty) {
      if (shoeCardsRemaining != state.cardsRemaining) {
        state = state.copyWith(cardsRemaining: shoeCardsRemaining);
      }
      return;
    }
    int delta = 0;
    for (final card in cards) {
      delta += _hiLoValue(card.rank);
    }
    state = state.copyWith(
      runningCount: state.runningCount + delta,
      cardsRemaining: shoeCardsRemaining,
    );
  }

  /// Called by [BlackjackController] after reshuffling the shoe mid-session.
  /// Resets the running count and fires the reshuffle toast flag.
  void onReshuffle(int newCardsRemaining) {
    if (!state.sessionActive) return;
    state = CountingSessionState(
      sessionActive: true,
      runningCount: 0,
      cardsRemaining: newCardsRemaining,
      showReshuffleToast: true,
    );
  }

  /// Clears the ephemeral reshuffle toast flag after the UI has shown it.
  void clearReshuffleToast() {
    if (state.showReshuffleToast) {
      state = state.copyWith(showReshuffleToast: false);
    }
  }

  // ── Hi-Lo card value ───────────────────────────────────────────────────────

  static int _hiLoValue(Rank rank) => switch (rank) {
        Rank.two ||
        Rank.three ||
        Rank.four ||
        Rank.five ||
        Rank.six =>
          1,
        Rank.seven || Rank.eight || Rank.nine => 0,
        _ => -1, // ten, jack, queen, king, ace
      };
}

// ── Provider ──────────────────────────────────────────────────────────────────

final countingSessionProvider =
    StateNotifierProvider<CountingSessionController, CountingSessionState>(
  (ref) => CountingSessionController(),
);
