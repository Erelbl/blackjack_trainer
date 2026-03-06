import 'dart:math';
import 'card.dart';
import 'rank.dart';
import 'suit.dart';

class Shoe {
  final List<Card> _cards;

  Shoe({int deckCount = 6, Random? random})
      : _cards = _initializeAndShuffleCards(deckCount, random ?? Random());

  static List<Card> _initializeAndShuffleCards(int deckCount, Random random) {
    final cards = <Card>[];

    for (int d = 0; d < deckCount; d++) {
      for (final suit in Suit.values) {
        for (final rank in Rank.values) {
          cards.add(Card(rank: rank, suit: suit));
        }
      }
    }

    cards.shuffle(random);
    return cards;
  }

  Card drawCard() {
    if (_cards.isEmpty) {
      throw StateError('No cards remaining in shoe');
    }
    return _cards.removeAt(0);
  }

  int get cardsRemaining => _cards.length;
  bool get isEmpty => _cards.isEmpty;

  /// An unmodifiable view of the remaining cards (used for win-rate simulation).
  List<Card> get remainingCards => List.unmodifiable(_cards);
}
