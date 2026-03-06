// Pure-Dart unit tests for BlackjackGame phase transitions and bet payouts.
// Run with: flutter test test/blackjack_game_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack_trainer/engine/game/blackjack_game.dart';
import 'package:blackjack_trainer/engine/game/game_state.dart';
import 'package:blackjack_trainer/features/play/state/blackjack_controller.dart';

void main() {
  group('BlackjackGame – phase transitions', () {
    test('idle -> playerTurn (or immediate terminal) on startNewRound', () {
      final game = BlackjackGame();
      expect(game.state, GameState.idle);

      game.startNewRound();

      // After the deal the game must be either in playerTurn or a terminal
      // state (push or playerBlackjack/dealerWin on a natural).
      final validAfterDeal = game.state == GameState.playerTurn ||
          game.state == GameState.playerBlackjack ||
          game.state == GameState.dealerWin ||
          game.state == GameState.push;
      expect(validAfterDeal, isTrue,
          reason: 'Unexpected state after deal: ${game.state}');
    });

    test('startNewRound throws during active play (playerTurn or dealerTurn)', () {
      final game = BlackjackGame();
      game.startNewRound();

      // Force into playerTurn for the guard test (handle rare instant-terminal).
      if (game.state != GameState.playerTurn) return; // natural – skip

      expect(
        () => game.startNewRound(),
        throwsA(isA<StateError>()),
        reason: 'startNewRound must throw during active play',
      );
    });

    test('startNewRound succeeds from any terminal state (restart guard)', () {
      final game = BlackjackGame();
      game.startNewRound();

      // Manually set a terminal state to simulate round completion.
      game.state = GameState.playerBust;

      // Must not throw – controller can restart from terminal states.
      expect(() => game.startNewRound(), returnsNormally);

      final validAfterRestart = game.state == GameState.playerTurn ||
          game.state == GameState.playerBlackjack ||
          game.state == GameState.dealerWin ||
          game.state == GameState.push;
      expect(validAfterRestart, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Bet payout deltas – pure function, no provider graph required.
  // ---------------------------------------------------------------------------
  group('computeBetPayout', () {
    const bet = 10;

    test('playerWin  → +bet', () {
      expect(computeBetPayout(GameState.playerWin, bet), equals(bet));
    });

    test('dealerBust → +bet', () {
      expect(computeBetPayout(GameState.dealerBust, bet), equals(bet));
    });

    test('dealerWin  → -bet', () {
      expect(computeBetPayout(GameState.dealerWin, bet), equals(-bet));
    });

    test('playerBust → -bet', () {
      expect(computeBetPayout(GameState.playerBust, bet), equals(-bet));
    });

    test('push       → 0', () {
      expect(computeBetPayout(GameState.push, bet), equals(0));
    });

    test('playerBlackjack → +round(1.5 × bet), even bet', () {
      // 10 × 1.5 = 15.0 → 15
      expect(computeBetPayout(GameState.playerBlackjack, 10), equals(15));
    });

    test('playerBlackjack → +round(1.5 × bet), odd bet (rounds half-up)', () {
      // 5 × 1.5 = 7.5 → 8  (Dart rounds half away from zero)
      expect(computeBetPayout(GameState.playerBlackjack, 5), equals(8));
    });

    test('idle / in-play states → 0', () {
      expect(computeBetPayout(GameState.idle, bet), equals(0));
      expect(computeBetPayout(GameState.playerTurn, bet), equals(0));
      expect(computeBetPayout(GameState.dealerTurn, bet), equals(0));
    });
  });
}
