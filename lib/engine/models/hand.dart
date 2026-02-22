import 'card.dart';

class Hand {
  final List<Card> _cards;

  Hand({List<Card> cards = const []}) : _cards = List.unmodifiable(cards);

  List<Card> get cards => List.unmodifiable(_cards);

  Hand addCard(Card card) {
    final newCards = [..._cards, card];
    return Hand(cards: newCards);
  }

  int get cardCount => _cards.length;

  bool get isEmpty => _cards.isEmpty;
}
