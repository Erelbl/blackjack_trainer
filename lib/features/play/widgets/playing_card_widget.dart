import 'package:flutter/material.dart' hide Card;
import '../../../engine/models/card.dart';
import '../../../engine/models/rank.dart';
import '../../../engine/models/suit.dart';

class PlayingCardWidget extends StatelessWidget {
  final Card? card;
  final bool faceDown;
  final bool animate;

  const PlayingCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (card == null) {
      return const SizedBox(width: 70, height: 100);
    }

    return RepaintBoundary(
      child: faceDown ? _buildCardBack() : _buildCardFace(),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(
        child: Icon(
          Icons.casino,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildCardFace() {
    final currentCard = card!;
    final isRed = currentCard.suit == Suit.hearts || currentCard.suit == Suit.diamonds;
    final suitColor = isRed ? Colors.red : Colors.black;
    final rankText = _getRankSymbol(currentCard.rank);
    final suitText = _getSuitSymbol(currentCard.suit);

    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            rankText,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: suitColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            suitText,
            style: TextStyle(
              fontSize: 28,
              color: suitColor,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  String _getRankSymbol(Rank rank) {
    return switch (rank) {
      Rank.ace => 'A',
      Rank.two => '2',
      Rank.three => '3',
      Rank.four => '4',
      Rank.five => '5',
      Rank.six => '6',
      Rank.seven => '7',
      Rank.eight => '8',
      Rank.nine => '9',
      Rank.ten => '10',
      Rank.jack => 'J',
      Rank.queen => 'Q',
      Rank.king => 'K',
    };
  }

  String _getSuitSymbol(Suit suit) {
    return switch (suit) {
      Suit.spades => '♠',
      Suit.hearts => '♥',
      Suit.diamonds => '♦',
      Suit.clubs => '♣',
    };
  }
}
