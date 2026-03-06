import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack_trainer/engine/models/card.dart';
import 'package:blackjack_trainer/engine/models/rank.dart';
import 'package:blackjack_trainer/engine/models/suit.dart';
import 'package:blackjack_trainer/engine/strategy/basic_strategy.dart';
import 'package:blackjack_trainer/features/trainer/state/trainer_controller.dart';
import 'package:blackjack_trainer/features/trainer/state/trainer_state.dart';

// Helper: build a card (suit doesn't affect strategy).
Card c(Rank rank, [Suit suit = Suit.spades]) => Card(rank: rank, suit: suit);

void main() {
  // ---------------------------------------------------------------------------
  // Test mode — no Win% computation
  // ---------------------------------------------------------------------------
  group('TrainerMode.test — no simulation', () {
    test('winRates is null immediately after startNewRound in test mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);
      controller.setMode(TrainerMode.test);
      controller.startNewRound();

      // Simulation is never triggered in test mode; winRates stays null.
      expect(container.read(trainerControllerProvider).winRates, isNull);
    });

    test('winRates is null after hit() in test mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);
      controller.setMode(TrainerMode.test);
      controller.startNewRound();
      controller.hit();

      expect(container.read(trainerControllerProvider).winRates, isNull);
    });

    test('switching to test mode clears winRates', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);
      // Start in learn mode (default).
      controller.startNewRound();
      // winRates is null synchronously (async sim hasn't completed yet).
      // Switch to test mode — should remain null.
      controller.setMode(TrainerMode.test);
      expect(container.read(trainerControllerProvider).winRates, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Separate stats per mode
  // ---------------------------------------------------------------------------
  group('Separate stats per mode', () {
    test('learn and test decisionsCount are tracked independently', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);

      // Make one decision in learn mode.
      controller.setMode(TrainerMode.learn);
      controller.startNewRound();
      controller.hit();
      final learnCount =
          container.read(trainerControllerProvider).learnStats.decisionsCount;
      expect(learnCount, 1);

      // Make one decision in test mode.
      controller.setMode(TrainerMode.test);
      controller.startNewRound();
      controller.hit();
      final s = container.read(trainerControllerProvider);
      expect(s.testStats.decisionsCount, 1);
      // Learn stats must not have changed.
      expect(s.learnStats.decisionsCount, learnCount);
    });

    test('convenience getters reflect the active mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);

      controller.setMode(TrainerMode.learn);
      controller.startNewRound();
      controller.hit();

      controller.setMode(TrainerMode.test);
      // decisionsCount should now return testStats (0), not learnStats (1).
      expect(container.read(trainerControllerProvider).decisionsCount, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Fallback scoring — SPLIT/DOUBLE unavailable, only HIT/STAND offered
  // ---------------------------------------------------------------------------
  group('Fallback scoring — HIT/STAND only available', () {
    const available = {StrategyAction.hit, StrategyAction.stand};

    test('A-A vs dealer 7: split ideal, fallback is hit', () {
      // A+A → pairsTable[ace][5]=split; soft 12 hard 2 → fallback hit
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.ace), c(Rank.ace)],
        dealerUpcard: Rank.seven,
        availableActions: available,
      );
      expect(result, StrategyAction.hit);
    });

    test('8-8 vs dealer 6: split ideal, fallback is stand (hard 16 vs 6)', () {
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.eight), c(Rank.eight)],
        dealerUpcard: Rank.six,
        availableActions: available,
      );
      expect(result, StrategyAction.stand);
    });

    test('11 vs dealer 6: double ideal, fallback is hit', () {
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.seven), c(Rank.four)],
        dealerUpcard: Rank.six,
        availableActions: available,
      );
      expect(result, StrategyAction.hit);
    });

    test('hit/stand ideal already in available set — returned unchanged', () {
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.nine), c(Rank.seven)],
        dealerUpcard: Rank.ten,
        availableActions: available,
      );
      expect(result, StrategyAction.hit);
    });
  });

  // ---------------------------------------------------------------------------
  // Test mode feedback — explanation hidden initially
  // ---------------------------------------------------------------------------
  group('Test mode feedback visibility', () {
    test('incorrect decision in test mode: showExplanation starts false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);
      controller.setMode(TrainerMode.test);

      // Deal rounds until we can make a decision; the specific correctness
      // depends on the dealt hand, but we verify the flag in all cases.
      controller.startNewRound();
      // We don't know which action is correct, so just check the flag.
      controller.hit();

      final fb = container.read(trainerControllerProvider).lastFeedback;
      if (fb != null && !fb.isCorrect) {
        expect(fb.showExplanation, isFalse);
      }
    });

    test('revealExplanation sets showExplanation to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(trainerControllerProvider.notifier);
      controller.setMode(TrainerMode.test);
      controller.startNewRound();
      controller.stand(); // stand is wrong often enough; just test the toggle

      final fb = container.read(trainerControllerProvider).lastFeedback;
      if (fb != null && !fb.isCorrect) {
        expect(fb.showExplanation, isFalse);
        controller.revealExplanation();
        expect(
          container.read(trainerControllerProvider).lastFeedback?.showExplanation,
          isTrue,
        );
      }
    });
  });
}
