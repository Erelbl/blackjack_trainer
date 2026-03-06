import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack_trainer/engine/game/game_state.dart';
import 'package:blackjack_trainer/engine/utils/xp_utils.dart';

void main() {
  group('computeHandXP', () {
    // ── Flat outcome values ───────────────────────────────────────────────────

    test('loss awards kXpLose', () {
      expect(computeHandXP(GameState.dealerWin, 10).total, equals(kXpLose));
    });

    test('bust awards kXpLose', () {
      expect(computeHandXP(GameState.playerBust, 50).total, equals(kXpLose));
    });

    test('push awards kXpLose', () {
      expect(computeHandXP(GameState.push, 100).total, equals(kXpLose));
    });

    test('idle (non-terminal) awards kXpLose', () {
      expect(computeHandXP(GameState.idle, 10).total, equals(kXpLose));
    });

    test('playerWin awards kXpWin', () {
      expect(computeHandXP(GameState.playerWin, 10).total, equals(kXpWin));
    });

    test('dealerBust awards kXpWin', () {
      expect(computeHandXP(GameState.dealerBust, 10).total, equals(kXpWin));
    });

    test('playerBlackjack awards kXpBlackjack', () {
      expect(
        computeHandXP(GameState.playerBlackjack, 10).total,
        equals(kXpBlackjack),
      );
    });

    // ── BJ replaces win — no stacking ────────────────────────────────────────

    test('blackjack total equals kXpBlackjack, not kXpWin + bonus', () {
      final r = computeHandXP(GameState.playerBlackjack, 10);
      expect(r.total, equals(kXpBlackjack)); // 35, not 15+25
      expect(r.winBonus, equals(0));         // win label suppressed for BJ
      expect(r.bjBonus, equals(kXpBlackjack));
    });

    // ── Bet bonus ────────────────────────────────────────────────────────────

    test('bet below threshold gives no bet bonus', () {
      // 199 ~/ 200 = 0
      expect(
        computeHandXP(GameState.playerWin, 199).total,
        equals(kXpWin + 0),
      );
    });

    test('bet at threshold gives 1 bet bonus', () {
      // 200 ~/ 200 = 1
      expect(
        computeHandXP(GameState.playerWin, 200).total,
        equals(kXpWin + 1),
      );
    });

    test('bet of 600 gives 3 bet bonus', () {
      // 600 ~/ 200 = 3
      expect(
        computeHandXP(GameState.playerWin, 600).total,
        equals(kXpWin + 3),
      );
    });

    test('bet bonus caps at kXpBetBonusMax', () {
      // 9999 ~/ 200 = 49 → clamped to 5
      expect(
        computeHandXP(GameState.playerWin, 9999).total,
        equals(kXpWin + kXpBetBonusMax),
      );
    });

    test('extreme bet does not exceed cap', () {
      expect(
        computeHandXP(GameState.playerBlackjack, 999999).total,
        equals(kXpBlackjack + kXpBetBonusMax),
      );
    });

    // ── Max XP ───────────────────────────────────────────────────────────────

    test('max XP hand: blackjack + max bet bonus', () {
      expect(
        computeHandXP(GameState.playerBlackjack, 1000).total,
        equals(kXpBlackjack + kXpBetBonusMax), // 35 + 5 = 40
      );
    });

    test('constants sum to expected max XP', () {
      expect(kXpBlackjack + kXpBetBonusMax, equals(40));
    });

    // ── XpResult breakdown fields ─────────────────────────────────────────────

    test('XpResult breakdown for a regular win', () {
      final r = computeHandXP(GameState.playerWin, 200);
      expect(r.base, equals(kXpWin));
      expect(r.winBonus, equals(kXpWin));
      expect(r.bjBonus, equals(0));
      expect(r.betBonus, equals(1)); // 200 ~/ 200 = 1
      expect(r.total, equals(kXpWin + 1));
    });

    test('XpResult breakdown for a loss', () {
      final r = computeHandXP(GameState.dealerWin, 10);
      expect(r.base, equals(kXpLose));
      expect(r.winBonus, equals(0));
      expect(r.bjBonus, equals(0));
      expect(r.betBonus, equals(0));
      expect(r.total, equals(kXpLose));
    });

    test('XpResult breakdown for a blackjack', () {
      final r = computeHandXP(GameState.playerBlackjack, 10);
      expect(r.base, equals(kXpBlackjack));
      expect(r.winBonus, equals(0));
      expect(r.bjBonus, equals(kXpBlackjack));
      expect(r.betBonus, equals(0));
      expect(r.total, equals(kXpBlackjack));
    });
  });
}
