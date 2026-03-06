import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../engine/game/game_state.dart';

class SessionStats {
  final int handsPlayed;
  final int handsWon;
  final int handsLost;
  final int handsPushed;
  final int currentWinStreak;
  final int bestWinStreak;
  final int coinsNetThisSession;
  final int xpEarnedThisSession;

  const SessionStats({
    this.handsPlayed = 0,
    this.handsWon = 0,
    this.handsLost = 0,
    this.handsPushed = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.coinsNetThisSession = 0,
    this.xpEarnedThisSession = 0,
  });

  static const SessionStats initial = SessionStats();

  double get winRate =>
      handsPlayed > 0 ? (handsWon / handsPlayed) * 100 : 0.0;
}

class SessionStatsNotifier extends StateNotifier<SessionStats> {
  SessionStatsNotifier() : super(SessionStats.initial);

  void recordHand({
    required GameState outcome,
    required int coinDelta,
    required int xpEarned,
  }) {
    final isWin = outcome == GameState.playerWin ||
        outcome == GameState.dealerBust ||
        outcome == GameState.playerBlackjack;
    final isPush = outcome == GameState.push;

    final streak = isWin ? state.currentWinStreak + 1 : 0;
    final best =
        streak > state.bestWinStreak ? streak : state.bestWinStreak;

    state = SessionStats(
      handsPlayed: state.handsPlayed + 1,
      handsWon: state.handsWon + (isWin ? 1 : 0),
      handsLost: state.handsLost + (!isWin && !isPush ? 1 : 0),
      handsPushed: state.handsPushed + (isPush ? 1 : 0),
      currentWinStreak: streak,
      bestWinStreak: best,
      coinsNetThisSession: state.coinsNetThisSession + coinDelta,
      xpEarnedThisSession: state.xpEarnedThisSession + xpEarned,
    );
  }

  void reset() => state = SessionStats.initial;
}

final sessionStatsProvider =
    StateNotifierProvider<SessionStatsNotifier, SessionStats>(
  (ref) => SessionStatsNotifier(),
);
