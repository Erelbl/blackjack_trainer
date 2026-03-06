import '../game/game_state.dart';

// ---------------------------------------------------------------------------
// XP constants — change these to tune the reward curve.
// ---------------------------------------------------------------------------
const int kXpLose = 10;       // lose or push
const int kXpWin = 15;        // win or dealer-bust
const int kXpBlackjack = 35;  // blackjack (replaces win, no stacking)
const int kXpBetBonusMax = 5;  // hard cap on bet-size bonus
const int kXpBetBonusPer = 200; // 1 XP per this many coins in the bet

// ---------------------------------------------------------------------------
// XpResult — single authoritative breakdown returned by computeHandXP.
// The UI and the controller both use this object; no separate calculations.
// ---------------------------------------------------------------------------

/// Breakdown of XP earned for a completed hand.
///
/// [total] is the authoritative amount to award and display.
/// All component fields are non-negative integers.
class XpResult {
  final int total;
  final int base;
  final int winBonus;
  final int bjBonus;
  final int betBonus;

  const XpResult({
    required this.total,
    required this.base,
    required this.winBonus,
    required this.bjBonus,
    required this.betBonus,
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns the XP earned for a completed hand as an [XpResult].
///
/// [outcome] — terminal [GameState] produced by the engine.
/// [bet]     — the player's bet for this hand (coins).
///
/// Pure function: no Flutter imports, no state. Safe to unit-test in isolation.
XpResult computeHandXP(GameState outcome, int bet) {
  final isBlackjack = outcome == GameState.playerBlackjack;
  final isWin = outcome == GameState.playerWin || outcome == GameState.dealerBust;

  // BJ replaces win — no stacking.
  final int base;
  if (isBlackjack) {
    base = kXpBlackjack;
  } else if (isWin) {
    base = kXpWin;
  } else {
    base = kXpLose; // lose, bust, push, or non-terminal state
  }

  // winBonus / bjBonus kept as non-zero indicators so the UI can show labels.
  final winBonus = isWin ? kXpWin : 0;
  final bjBonus = isBlackjack ? kXpBlackjack : 0;

  // Bet bonus: 1 XP per kXpBetBonusPer coins, capped at kXpBetBonusMax.
  final betBonus = (bet ~/ kXpBetBonusPer).clamp(0, kXpBetBonusMax);

  final total = base + betBonus;

  return XpResult(
    total: total,
    base: base,
    winBonus: winBonus,
    bjBonus: bjBonus,
    betBonus: betBonus,
  );
}
