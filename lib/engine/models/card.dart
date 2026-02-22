import 'rank.dart';
import 'suit.dart';

class Card {
  final Rank rank;
  final Suit suit;

  const Card({required this.rank, required this.suit});

  @override
  String toString() => '${rank.name}Of${suit.name}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Card && rank == other.rank && suit == other.suit;

  @override
  int get hashCode => Object.hash(rank, suit);
}
