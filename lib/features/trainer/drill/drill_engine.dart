import 'dart:math';

import '../../../engine/models/card.dart';
import '../../../engine/models/rank.dart';
import '../../../engine/models/suit.dart';
import '../../../engine/utils/hand_evaluator.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

/// A single drill hand: two player cards and a dealer upcard rank.
///
/// Only rank matters for basic-strategy lookups — suit is irrelevant.
class DrillPosition {
  final List<Card> playerCards;
  final Rank dealerUpcard;

  const DrillPosition({required this.playerCards, required this.dealerUpcard});
}

// ── Engine ────────────────────────────────────────────────────────────────────

/// Generates random [DrillPosition] instances on demand.
///
/// No shoe tracking — each call is fully independent.
/// Hands with an immediate blackjack (21 from two cards) are excluded
/// so the drill always presents a decision point.
class DrillEngine {
  static const _ranks = Rank.values;
  static const _suits = Suit.values;

  final _rng = Random();

  Card _randomCard() => Card(
        rank: _ranks[_rng.nextInt(_ranks.length)],
        suit: _suits[_rng.nextInt(_suits.length)],
      );

  /// Returns the next position synchronously.
  ///
  /// Loops until a non-blackjack hand is generated — in practice this
  /// almost always succeeds on the first attempt.
  DrillPosition nextPosition() {
    while (true) {
      final c1 = _randomCard();
      final c2 = _randomCard();
      final cards = [c1, c2];
      if (!HandEvaluator.evaluate(cards).isBlackjack) {
        return DrillPosition(
          playerCards: List.unmodifiable(cards),
          dealerUpcard: _ranks[_rng.nextInt(_ranks.length)],
        );
      }
    }
  }
}
