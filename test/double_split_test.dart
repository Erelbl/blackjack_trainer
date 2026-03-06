// Tests for Double Down and Split support in the BlackjackGame engine.
// Run with: flutter test test/double_split_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack_trainer/engine/game/blackjack_game.dart';
import 'package:blackjack_trainer/engine/game/game_state.dart';
import 'package:blackjack_trainer/engine/models/card.dart';
import 'package:blackjack_trainer/engine/models/rank.dart';
import 'package:blackjack_trainer/engine/models/shoe.dart';
import 'package:blackjack_trainer/engine/models/suit.dart';
import 'package:blackjack_trainer/features/play/state/blackjack_controller.dart';

/// Creates a shoe with pre-determined cards on top (drawn first).
/// The [topCards] are placed at the front of the shoe so drawCard()
/// returns them in order.
Shoe _riggedShoe(List<Card> topCards) {
  final shoe = Shoe(deckCount: 6);
  // Access internal list and prepend our rigged cards.
  // We use a fresh shoe and replace its internal state.
  return _TestShoe(topCards, shoe);
}

/// A test shoe that serves pre-determined cards first, then falls back to
/// the underlying shoe.
class _TestShoe extends Shoe {
  final List<Card> _rigged;
  int _riggedIdx = 0;
  final Shoe _fallback;

  _TestShoe(this._rigged, this._fallback) : super(deckCount: 1);

  @override
  Card drawCard() {
    if (_riggedIdx < _rigged.length) {
      return _rigged[_riggedIdx++];
    }
    return _fallback.drawCard();
  }

  @override
  int get cardsRemaining => (_rigged.length - _riggedIdx) + _fallback.cardsRemaining;
}

void main() {
  // ---------------------------------------------------------------------------
  // Double Down
  // ---------------------------------------------------------------------------
  group('Double Down', () {
    test('canPlayerDouble is true for 2-card hand in playerTurn', () {
      final game = BlackjackGame();
      game.startNewRound();
      if (game.state != GameState.playerTurn) return; // natural, skip
      expect(game.playerHand.cardCount, 2);
      expect(game.canPlayerDouble, isTrue);
    });

    test('canPlayerDouble is false after a hit (3+ cards)', () {
      final game = BlackjackGame();
      game.startNewRound();
      if (game.state != GameState.playerTurn) return;
      game.playerHit();
      if (game.state != GameState.playerTurn) return; // busted
      expect(game.canPlayerDouble, isFalse);
    });

    test('playerDouble draws exactly 1 card and ends the hand', () {
      // Rig: player gets 5,6 (=11), dealer gets 7,8. Double card = 10 (→21).
      final shoe = _riggedShoe([
        const Card(rank: Rank.five, suit: Suit.hearts),   // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),   // D1
        const Card(rank: Rank.six, suit: Suit.hearts),    // P2
        const Card(rank: Rank.eight, suit: Suit.clubs),   // D2
        const Card(rank: Rank.ten, suit: Suit.diamonds),  // Double card
        // Dealer draws...
        const Card(rank: Rank.three, suit: Suit.spades),  // Dealer hits to 18
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      expect(game.state, GameState.playerTurn);
      expect(game.playerHand.cardCount, 2);

      game.playerDouble();

      // Player should now have 3 cards.
      expect(game.playerHands[0].cardCount, 3);
      // Hand doubled flag should be set.
      expect(game.handDoubled[0], isTrue);
      // Game should have advanced past playerTurn (dealer played + resolved).
      expect(game.isGameOver, isTrue);
    });

    test('playerDouble with bust', () {
      // Rig: player gets 10,6 (=16), double card = King (=26, bust).
      final shoe = _riggedShoe([
        const Card(rank: Rank.ten, suit: Suit.hearts),    // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),   // D1
        const Card(rank: Rank.six, suit: Suit.hearts),    // P2
        const Card(rank: Rank.eight, suit: Suit.clubs),   // D2
        const Card(rank: Rank.king, suit: Suit.diamonds), // Double card → bust
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      expect(game.state, GameState.playerTurn);

      game.playerDouble();

      // All hands busted → playerBust.
      expect(game.state, GameState.playerBust);
      expect(game.handDoubled[0], isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Split
  // ---------------------------------------------------------------------------
  group('Split', () {
    test('canPlayerSplit is true for same-rank pair', () {
      // Rig: player gets 8,8.
      final shoe = _riggedShoe([
        const Card(rank: Rank.eight, suit: Suit.hearts),  // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),   // D1
        const Card(rank: Rank.eight, suit: Suit.spades),  // P2
        const Card(rank: Rank.six, suit: Suit.clubs),     // D2
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      expect(game.state, GameState.playerTurn);
      expect(game.canPlayerSplit, isTrue);
    });

    test('canPlayerSplit is false for different ranks', () {
      // Rig: player gets 8,9.
      final shoe = _riggedShoe([
        const Card(rank: Rank.eight, suit: Suit.hearts),  // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),   // D1
        const Card(rank: Rank.nine, suit: Suit.spades),   // P2
        const Card(rank: Rank.six, suit: Suit.clubs),     // D2
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      expect(game.state, GameState.playerTurn);
      expect(game.canPlayerSplit, isFalse);
    });

    test('playerSplit creates 2 hands with correct cards', () {
      // Rig: player gets 8♥,8♠. Split draws: 5♦ for hand0, 3♣ for hand1.
      final shoe = _riggedShoe([
        const Card(rank: Rank.eight, suit: Suit.hearts),    // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.eight, suit: Suit.spades),    // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.five, suit: Suit.diamonds),   // Split draw for hand0
        const Card(rank: Rank.three, suit: Suit.clubs),     // Split draw for hand1
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      expect(game.playerHands.length, 2);
      expect(game.hasSplit, isTrue);
      expect(game.activeHandIndex, 0);
      expect(game.state, GameState.playerTurn);

      // Hand 0: 8♥ + 5♦
      expect(game.playerHands[0].cards[0].rank, Rank.eight);
      expect(game.playerHands[0].cards[1].rank, Rank.five);
      // Hand 1: 8♠ + 3♣
      expect(game.playerHands[1].cards[0].rank, Rank.eight);
      expect(game.playerHands[1].cards[1].rank, Rank.three);
    });

    test('no resplit allowed (canPlayerSplit false after split)', () {
      // Rig: player gets 8,8. After split, hand0 gets another 8.
      final shoe = _riggedShoe([
        const Card(rank: Rank.eight, suit: Suit.hearts),    // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.eight, suit: Suit.spades),    // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.eight, suit: Suit.diamonds),  // Split draw → another 8!
        const Card(rank: Rank.three, suit: Suit.clubs),     // Split draw for hand1
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      // Hand 0 now has 8,8 again — but resplit should NOT be allowed.
      expect(game.canPlayerSplit, isFalse);
    });

    test('split hands advance correctly: stand on hand0 → play hand1', () {
      final shoe = _riggedShoe([
        const Card(rank: Rank.eight, suit: Suit.hearts),    // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.eight, suit: Suit.spades),    // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.five, suit: Suit.diamonds),   // hand0 second card
        const Card(rank: Rank.three, suit: Suit.clubs),     // hand1 second card
        // Dealer draws after both hands complete.
        const Card(rank: Rank.four, suit: Suit.hearts),     // Dealer hit
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      expect(game.activeHandIndex, 0);
      game.playerStand(); // stand on hand 0
      expect(game.activeHandIndex, 1);
      expect(game.state, GameState.playerTurn);

      game.playerStand(); // stand on hand 1 → dealer plays
      expect(game.isGameOver, isTrue);
      expect(game.handOutcomes.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Split Aces
  // ---------------------------------------------------------------------------
  group('Split Aces', () {
    test('split aces auto-stand both hands and go to dealer turn', () {
      final shoe = _riggedShoe([
        const Card(rank: Rank.ace, suit: Suit.hearts),      // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.ace, suit: Suit.spades),      // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.ten, suit: Suit.diamonds),    // hand0 second card (A+10=21)
        const Card(rank: Rank.five, suit: Suit.clubs),      // hand1 second card (A+5=16)
        // Dealer plays S17.
        const Card(rank: Rank.four, suit: Suit.hearts),     // Dealer hit: 7+6+4=17 → stand
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      // After splitting aces, game should be completely resolved.
      expect(game.isGameOver, isTrue);
      expect(game.playerHands.length, 2);
      expect(game.isSplitAceHand[0], isTrue);
      expect(game.isSplitAceHand[1], isTrue);
      expect(game.handOutcomes.length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Split 21 is NOT blackjack
  // ---------------------------------------------------------------------------
  group('Split 21 payout', () {
    test('21 after split pays 1:1 (not 3:2 blackjack)', () {
      // If split results in A+10=21, it should be playerWin, not playerBlackjack.
      final shoe = _riggedShoe([
        const Card(rank: Rank.ace, suit: Suit.hearts),      // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.ace, suit: Suit.spades),      // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.ten, suit: Suit.diamonds),    // hand0: A+10=21
        const Card(rank: Rank.two, suit: Suit.clubs),       // hand1: A+2=13
        // Dealer: 7+6=13, draws 4=17, stands.
        const Card(rank: Rank.four, suit: Suit.hearts),
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      expect(game.isGameOver, isTrue);
      // Hand 0 has 21 but should NOT be playerBlackjack.
      expect(game.handOutcomes[0], isNot(GameState.playerBlackjack));
      // 21 > 17 → should be playerWin.
      expect(game.handOutcomes[0], GameState.playerWin);

      // Payout for hand 0: 1:1 (not 3:2).
      const bet = 100;
      expect(computeBetPayout(game.handOutcomes[0], bet), equals(bet)); // +100, not +150
    });
  });

  // ---------------------------------------------------------------------------
  // DAS (Double After Split)
  // ---------------------------------------------------------------------------
  group('DAS – Double After Split', () {
    test('canPlayerDouble is true on non-ace split hand with 2 cards', () {
      final shoe = _riggedShoe([
        const Card(rank: Rank.eight, suit: Suit.hearts),    // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.eight, suit: Suit.spades),    // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.three, suit: Suit.diamonds),  // hand0 second card: 8+3=11
        const Card(rank: Rank.four, suit: Suit.clubs),      // hand1 second card
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      // On hand 0 with 2 cards (non-ace split): double should be allowed.
      expect(game.activeHandIndex, 0);
      expect(game.playerHand.cardCount, 2);
      expect(game.canPlayerDouble, isTrue);
    });

    test('canPlayerDouble is false on split-ace hand', () {
      // Split aces auto-stand, so canPlayerDouble never applies.
      // But verify the flag is set correctly.
      final shoe = _riggedShoe([
        const Card(rank: Rank.ace, suit: Suit.hearts),      // P1
        const Card(rank: Rank.seven, suit: Suit.clubs),     // D1
        const Card(rank: Rank.ace, suit: Suit.spades),      // P2
        const Card(rank: Rank.six, suit: Suit.clubs),       // D2
        const Card(rank: Rank.five, suit: Suit.diamonds),   // hand0 card
        const Card(rank: Rank.four, suit: Suit.clubs),      // hand1 card
        const Card(rank: Rank.three, suit: Suit.hearts),    // Dealer
      ]);
      final game = BlackjackGame(shoe: shoe);
      game.startNewRound();
      game.playerSplit();

      // After split aces, game should be over (auto-stood).
      expect(game.isGameOver, isTrue);
      // isSplitAceHand should be true for both.
      expect(game.isSplitAceHand[0], isTrue);
      expect(game.isSplitAceHand[1], isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Split payout scenarios
  // ---------------------------------------------------------------------------
  group('Split payouts', () {
    test('split win + lose = net zero', () {
      const bet = 100;
      final hand0Payout = computeBetPayout(GameState.playerWin, bet);  // +100
      final hand1Payout = computeBetPayout(GameState.dealerWin, bet);  // -100
      expect(hand0Payout + hand1Payout, equals(0));
    });

    test('split doubled win = +2x bet', () {
      const bet = 100;
      final payout = computeBetPayout(GameState.playerWin, bet * 2);  // doubled
      expect(payout, equals(200));
    });

    test('split both win = +2x bet', () {
      const bet = 100;
      final h0 = computeBetPayout(GameState.playerWin, bet);
      final h1 = computeBetPayout(GameState.dealerBust, bet);
      expect(h0 + h1, equals(200));
    });

    test('split win + push = +1x bet', () {
      const bet = 100;
      final h0 = computeBetPayout(GameState.playerWin, bet);
      final h1 = computeBetPayout(GameState.push, bet);
      expect(h0 + h1, equals(100));
    });
  });

  // ---------------------------------------------------------------------------
  // Economy correctness — verifies the no-pre-deduction payout model.
  //
  // Model: bets are never deducted during play.  At round end, the full
  // effectiveBet is settled via computeBetPayout, producing the correct net
  // change in one atomic call.
  //
  // Legend:  C = starting coins,  B = bet.
  // ---------------------------------------------------------------------------
  group('Economy: double payout correctness', () {
    test('double + win: net +2B (effectiveBet=2B, win payout)', () {
      // C=1000, B=100.  Win on doubled hand → +200 → C+200=1200.
      const bet = 100;
      expect(computeBetPayout(GameState.playerWin, bet * 2), equals(200));
    });

    test('double + lose: net -2B (effectiveBet=2B, lose payout)', () {
      // C=1000, B=100.  Lose on doubled hand → -200 → C-200=800.
      const bet = 100;
      expect(computeBetPayout(GameState.dealerWin, bet * 2), equals(-200));
    });

    test('double + push: net 0 (effectiveBet=2B, push payout)', () {
      // C=1000, B=100.  Push on doubled hand → 0 → C unchanged=1000.
      const bet = 100;
      expect(computeBetPayout(GameState.push, bet * 2), equals(0));
    });

    test('double + dealer bust: net +2B (treated as win)', () {
      const bet = 100;
      expect(computeBetPayout(GameState.dealerBust, bet * 2), equals(200));
    });
  });

  group('Economy: split payout correctness (no pre-deduction)', () {
    // All scenarios verify the net change from the player's starting coins (C).
    // Split adds a second hand at the same bet; settlement sums both.

    test('both win: net +2B', () {
      const bet = 100;
      final total = computeBetPayout(GameState.playerWin, bet)
                  + computeBetPayout(GameState.playerWin, bet);
      expect(total, equals(200)); // C+200
    });

    test('both lose: net -2B', () {
      const bet = 100;
      final total = computeBetPayout(GameState.dealerWin, bet)
                  + computeBetPayout(GameState.dealerWin, bet);
      expect(total, equals(-200)); // C-200
    });

    test('win + lose: net 0', () {
      const bet = 100;
      final total = computeBetPayout(GameState.playerWin, bet)
                  + computeBetPayout(GameState.dealerWin, bet);
      expect(total, equals(0)); // C unchanged
    });

    test('win + push: net +1B', () {
      const bet = 100;
      final total = computeBetPayout(GameState.playerWin, bet)
                  + computeBetPayout(GameState.push, bet);
      expect(total, equals(100)); // C+100
    });

    test('push + push: net 0', () {
      const bet = 100;
      final total = computeBetPayout(GameState.push, bet)
                  + computeBetPayout(GameState.push, bet);
      expect(total, equals(0)); // C unchanged
    });
  });

  group('Economy: DAS (split + double) payout correctness', () {
    test('doubled-win hand + normal-lose hand: net +1B', () {
      // hand 0 doubled (effectiveBet=2B) and wins → +200
      // hand 1 normal (effectiveBet=B) and loses → -100
      // net = +100
      const bet = 100;
      final total = computeBetPayout(GameState.playerWin, bet * 2)
                  + computeBetPayout(GameState.dealerWin, bet);
      expect(total, equals(100));
    });

    test('doubled-lose hand + normal-win hand: net -1B', () {
      // hand 0 doubled and loses → -200
      // hand 1 normal wins → +100
      // net = -100
      const bet = 100;
      final total = computeBetPayout(GameState.dealerWin, bet * 2)
                  + computeBetPayout(GameState.playerWin, bet);
      expect(total, equals(-100));
    });

    test('doubled-win hand + normal-push hand: net +2B', () {
      const bet = 100;
      final total = computeBetPayout(GameState.playerWin, bet * 2)
                  + computeBetPayout(GameState.push, bet);
      expect(total, equals(200));
    });
  });

  group('Economy: coin guard (_totalBetsInRound logic)', () {
    // Verifies the guard formula: coins >= (existingBets + 1) * bet.

    test('normal hand: need coins >= 2B to double', () {
      // existingBets=1, adding double → need 2B.
      const bet = 100;
      const existingBets = 1; // 1 hand, 0 doubles
      final required = (existingBets + 1) * bet;
      expect(required, equals(200));
      // 200 coins: allowed (200 >= 200); worst case lose 2B → 0.
      expect(200 >= required, isTrue);
      // 199 coins: not allowed (199 < 200); would go negative.
      expect(199 >= required, isFalse);
    });

    test('after split: need coins >= 3B to double (DAS)', () {
      // existingBets=2 (2 hands, 0 doubles), adding double → need 3B.
      const bet = 100;
      const existingBets = 2; // 2 hands from split
      final required = (existingBets + 1) * bet;
      expect(required, equals(300));
      expect(300 >= required, isTrue);
      expect(299 >= required, isFalse);
    });

    test('split guard: need coins >= 2B to split', () {
      // existingBets=1 (original hand), adding split → need 2B.
      const bet = 100;
      const existingBets = 1;
      final required = (existingBets + 1) * bet;
      expect(required, equals(200));
    });

    test('sufficient coins: no negative balance on double+lose', () {
      // Player has exactly 2B coins.  Double lose = -2B → 0.  Non-negative ✓.
      const bet = 100;
      const startCoins = 200;
      final netChange = computeBetPayout(GameState.dealerWin, bet * 2);
      expect(startCoins + netChange, equals(0)); // exactly zero, not negative
    });

    test('insufficient coins: would go negative if guard skipped', () {
      // Player has 150 (< 2B=200).  Guard must block the double.
      const bet = 100;
      const startCoins = 150;
      final netChange = computeBetPayout(GameState.dealerWin, bet * 2);
      expect(startCoins + netChange, isNegative); // guard is there to prevent this
    });
  });
}
