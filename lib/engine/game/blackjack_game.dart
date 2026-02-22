import '../models/hand.dart';
import '../models/shoe.dart';
import '../utils/hand_evaluator.dart';
import 'game_state.dart';

class BlackjackGame {
  final Shoe shoe;
  Hand playerHand;
  Hand dealerHand;
  GameState state;

  BlackjackGame({Shoe? shoe, int deckCount = 6})
      : shoe = shoe ?? Shoe(deckCount: deckCount),
        state = GameState.idle,
        playerHand = Hand(),
        dealerHand = Hand();

  /// Starts a new round: deals 2 cards to player and dealer
  void startNewRound() {
    if (state != GameState.idle) {
      throw StateError('Cannot start new round unless in idle state');
    }

    playerHand = Hand();
    dealerHand = Hand();

    // Deal 2 cards each: Player, Dealer, Player, Dealer
    playerHand = playerHand.addCard(shoe.drawCard());
    dealerHand = dealerHand.addCard(shoe.drawCard());
    playerHand = playerHand.addCard(shoe.drawCard());
    dealerHand = dealerHand.addCard(shoe.drawCard());

    // Check for immediate blackjack
    final playerEval = HandEvaluator.evaluate(playerHand.cards);
    final dealerEval = HandEvaluator.evaluate(dealerHand.cards);

    if (playerEval.isBlackjack && dealerEval.isBlackjack) {
      state = GameState.push;
    } else if (playerEval.isBlackjack) {
      state = GameState.playerBlackjack;
    } else if (dealerEval.isBlackjack) {
      state = GameState.dealerWin;
    } else {
      state = GameState.playerTurn;
    }
  }

  /// Player hits: adds a card to player hand
  void playerHit() {
    if (state != GameState.playerTurn) {
      throw StateError('Player can only hit during playerTurn');
    }

    playerHand = playerHand.addCard(shoe.drawCard());

    final evaluation = HandEvaluator.evaluate(playerHand.cards);
    if (evaluation.isBust) {
      state = GameState.playerBust;
    }
  }

  /// Player stands: ends player turn, triggers dealer play
  void playerStand() {
    if (state != GameState.playerTurn) {
      throw StateError('Player can only stand during playerTurn');
    }

    state = GameState.dealerTurn;
    _dealerPlay();
  }

  /// Dealer plays per S17 rule: stands on all 17s (soft and hard)
  void _dealerPlay() {
    while (true) {
      final evaluation = HandEvaluator.evaluate(dealerHand.cards);

      // Bust: dealer loses
      if (evaluation.isBust) {
        state = GameState.dealerBust;
        return;
      }

      // S17 rule: Stand on all 17s (soft or hard)
      if (evaluation.total >= 17) {
        break; // Stand
      }

      // Total < 17: hit
      dealerHand = dealerHand.addCard(shoe.drawCard());
    }

    // Resolve game
    _resolve();
  }

  /// Determines winner and sets final state
  void _resolve() {
    if (state == GameState.dealerBust) {
      state = GameState.playerWin;
      return;
    }

    final playerEval = HandEvaluator.evaluate(playerHand.cards);
    final dealerEval = HandEvaluator.evaluate(dealerHand.cards);

    if (playerEval.total > dealerEval.total) {
      state = GameState.playerWin;
    } else if (dealerEval.total > playerEval.total) {
      state = GameState.dealerWin;
    } else {
      state = GameState.push;
    }
  }

  /// Game state query helpers
  bool get isGameOver =>
      state == GameState.playerBust ||
      state == GameState.dealerBust ||
      state == GameState.playerBlackjack ||
      state == GameState.push ||
      state == GameState.playerWin ||
      state == GameState.dealerWin;

  bool get canPlayerHit => state == GameState.playerTurn;
  bool get canPlayerStand => state == GameState.playerTurn;
}
