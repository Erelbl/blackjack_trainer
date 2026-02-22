import '../models/card.dart';
import '../models/rank.dart';

class HandEvaluation {
  final int total;
  final bool isBlackjack;
  final bool isBust;
  final bool isSoft;

  const HandEvaluation({
    required this.total,
    required this.isBlackjack,
    required this.isBust,
    required this.isSoft,
  });
}

class HandEvaluator {
  /// Evaluates a hand of cards
  /// Ace soft/hard logic:
  /// - Start with all aces as 11
  /// - If bust, convert aces to 1 one-by-one until not bust
  /// - isSoft = true if any ace is counted as 11
  static HandEvaluation evaluate(List<Card> cards) {
    if (cards.isEmpty) {
      return const HandEvaluation(
        total: 0,
        isBlackjack: false,
        isBust: false,
        isSoft: false,
      );
    }

    // Count aces and calculate initial total (all aces as 11)
    int total = 0;
    int aceCount = 0;

    for (final card in cards) {
      total += card.rank.blackjackValue;
      if (card.rank == Rank.ace) {
        aceCount++;
      }
    }

    // Convert aces from 11 to 1 until not bust
    int acesAsEleven = aceCount;
    while (total > 21 && acesAsEleven > 0) {
      total -= 10; // Convert one ace from 11 to 1
      acesAsEleven--;
    }

    // Check for blackjack (must be exactly 2 cards totaling 21)
    final isBlackjack = cards.length == 2 && total == 21;

    return HandEvaluation(
      total: total,
      isBlackjack: isBlackjack,
      isBust: total > 21,
      isSoft: acesAsEleven > 0,
    );
  }
}
