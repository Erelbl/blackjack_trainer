import 'package:flutter/material.dart' hide Card;
import '../../../engine/models/card.dart';
import 'playing_card_widget.dart';

class CardRow extends StatelessWidget {
  final List<Card> cards;
  final bool hideLast;

  const CardRow({
    super.key,
    required this.cards,
    this.hideLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < cards.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PlayingCardWidget(
                key: ValueKey('${cards[index].toString()}_$index'),
                card: cards[index],
                faceDown: hideLast && index == cards.length - 1,
                animate: false,
              ),
            ),
        ],
      ),
    );
  }
}
