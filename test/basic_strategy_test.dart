import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack_trainer/engine/models/card.dart';
import 'package:blackjack_trainer/engine/models/rank.dart';
import 'package:blackjack_trainer/engine/models/suit.dart';
import 'package:blackjack_trainer/engine/strategy/basic_strategy.dart';

// Helper: build a card from rank + suit (suit doesn't affect strategy).
Card c(Rank rank, [Suit suit = Suit.spades]) => Card(rank: rank, suit: suit);

void main() {
  group('BasicStrategy.dealerIndex', () {
    test('maps 2–9 to indices 0–7', () {
      expect(BasicStrategy.dealerIndex(Rank.two),   0);
      expect(BasicStrategy.dealerIndex(Rank.nine),  7);
    });

    test('maps 10 / face cards to index 8', () {
      expect(BasicStrategy.dealerIndex(Rank.ten),   8);
      expect(BasicStrategy.dealerIndex(Rank.jack),  8);
      expect(BasicStrategy.dealerIndex(Rank.queen), 8);
      expect(BasicStrategy.dealerIndex(Rank.king),  8);
    });

    test('maps Ace to index 9', () {
      expect(BasicStrategy.dealerIndex(Rank.ace), 9);
    });
  });

  group('BasicStrategy.recommend – hard totals', () {
    test('Hard 16 vs dealer 10 → Hit', () {
      // 9 + 7 = hard 16
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.nine), c(Rank.seven)],
        dealerUpcard: Rank.ten,
      );
      expect(result, StrategyAction.hit);
    });

    test('Hard 16 vs dealer 6 → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.nine), c(Rank.seven)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.stand);
    });

    test('Hard 12 vs dealer 4 → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ten), c(Rank.two)],
        dealerUpcard: Rank.four,
      );
      expect(result, StrategyAction.stand);
    });

    test('Hard 12 vs dealer 2 → Hit', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ten), c(Rank.two)],
        dealerUpcard: Rank.two,
      );
      expect(result, StrategyAction.hit);
    });

    test('Hard 11 vs dealer 6 → Double', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.seven), c(Rank.four)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.doubleDown);
    });

    test('Hard 11 vs dealer Ace → Hit (S17)', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.seven), c(Rank.four)],
        dealerUpcard: Rank.ace,
      );
      expect(result, StrategyAction.hit);
    });

    test('Hard 17 vs dealer Ace → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ten), c(Rank.seven)],
        dealerUpcard: Rank.ace,
      );
      expect(result, StrategyAction.stand);
    });

    test('Hard 8 (or less) vs any dealer → Hit', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.three), c(Rank.five)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.hit);
    });
  });

  group('BasicStrategy.recommend – soft totals', () {
    test('Soft 18 (A+7) vs dealer 5 → Double', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.seven)],
        dealerUpcard: Rank.five,
      );
      expect(result, StrategyAction.doubleDown);
    });

    test('Soft 18 (A+7) vs dealer 9 → Hit', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.seven)],
        dealerUpcard: Rank.nine,
      );
      expect(result, StrategyAction.hit);
    });

    test('Soft 18 (A+7) vs dealer 2 → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.seven)],
        dealerUpcard: Rank.two,
      );
      expect(result, StrategyAction.stand);
    });

    test('Soft 20 (A+9) vs any dealer → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.nine)],
        dealerUpcard: Rank.five,
      );
      expect(result, StrategyAction.stand);
    });

    test('Soft 17 (A+6) vs dealer 3 → Double', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.six)],
        dealerUpcard: Rank.three,
      );
      expect(result, StrategyAction.doubleDown);
    });

    test('Soft 17 (A+6) vs dealer 2 → Hit', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.six)],
        dealerUpcard: Rank.two,
      );
      expect(result, StrategyAction.hit);
    });
  });

  group('BasicStrategy.recommend – pairs', () {
    test('A-A vs any dealer → Split', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.ace)],
        dealerUpcard: Rank.seven,
      );
      expect(result, StrategyAction.split);
    });

    test('8-8 vs dealer 10 → Split', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.eight), c(Rank.eight)],
        dealerUpcard: Rank.ten,
      );
      expect(result, StrategyAction.split);
    });

    test('10-10 vs dealer 6 → Stand (never split)', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ten), c(Rank.king)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.stand);
    });

    test('5-5 vs dealer 8 → Double (treat as hard 10)', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.five), c(Rank.five)],
        dealerUpcard: Rank.eight,
      );
      expect(result, StrategyAction.doubleDown);
    });

    test('5-5 vs dealer Ace → Hit', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.five), c(Rank.five)],
        dealerUpcard: Rank.ace,
      );
      expect(result, StrategyAction.hit);
    });

    test('9-9 vs dealer 7 → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.nine), c(Rank.nine)],
        dealerUpcard: Rank.seven,
      );
      expect(result, StrategyAction.stand);
    });

    test('9-9 vs dealer 6 → Split', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.nine), c(Rank.nine)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.split);
    });
  });

  group('BasicStrategy.recommendFallback – unavailable actions', () {
    test('5-5 vs dealer 6: ideal=Double, fallback=Hit (double collapses to hit)', () {
      // pairsTable key=5 vs dealer index 4 (six) → doubleDown
      // fallback from {hit, stand}: hit
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.five), c(Rank.five)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.hit);
    });

    test('8-8 vs dealer 6: ideal=Split, fallback=Stand (hard 16 vs 6)', () {
      // pairsTable key=8 vs dealer index 4 (six) → split
      // _hitOrStand: hardTable[16][4] = stand
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.eight), c(Rank.eight)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.stand);
    });

    test('ideal already available is returned unchanged', () {
      // Hard 16 vs 10 → hit (already in {hit, stand})
      final result = BasicStrategy.recommendFallback(
        playerCards: [c(Rank.nine), c(Rank.seven)],
        dealerUpcard: Rank.ten,
      );
      expect(result, StrategyAction.hit);
    });
  });

  group('BasicStrategy.recommend – multi-card soft', () {
    test('Soft 18 (A+5+2) with 3 cards → Stand', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.five), c(Rank.two)],
        dealerUpcard: Rank.nine,
      );
      expect(result, StrategyAction.stand);
    });

    test('Soft 17 (A+4+2) with 3 cards → Hit', () {
      final result = BasicStrategy.recommend(
        playerCards: [c(Rank.ace), c(Rank.four), c(Rank.two)],
        dealerUpcard: Rank.six,
      );
      expect(result, StrategyAction.hit);
    });
  });
}
