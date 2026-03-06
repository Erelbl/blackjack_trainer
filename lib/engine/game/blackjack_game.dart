import '../config/blackjack_rules.dart';
import '../models/hand.dart';
import '../models/rank.dart';
import '../models/shoe.dart';
import '../utils/hand_evaluator.dart';
import 'game_state.dart';

class BlackjackGame {
  final BlackjackRules rules;
  final Shoe shoe;
  Hand dealerHand;
  GameState state;

  // ── Multi-hand support ──────────────────────────────────────────────────
  List<Hand> playerHands;
  int activeHandIndex;
  bool hasSplit;
  List<bool> handDoubled;
  List<bool> isSplitAceHand;

  /// Per-hand terminal outcome, set after settlement. Empty until game over.
  List<GameState> handOutcomes;

  BlackjackGame({Shoe? shoe, this.rules = const BlackjackRules()})
      : shoe = shoe ?? Shoe(deckCount: rules.deckCount),
        state = GameState.idle,
        dealerHand = Hand(),
        playerHands = [Hand()],
        activeHandIndex = 0,
        hasSplit = false,
        handDoubled = [false],
        isSplitAceHand = [false],
        handOutcomes = [];

  // ── Backward-compat convenience ─────────────────────────────────────────
  Hand get playerHand => playerHands[activeHandIndex];
  set playerHand(Hand h) => playerHands[activeHandIndex] = h;

  // ── Round lifecycle ─────────────────────────────────────────────────────

  /// Starts a new round: deals 2 cards to player and dealer.
  /// May be called from [GameState.idle] or any terminal (game-over) state.
  void startNewRound() {
    if (state == GameState.playerTurn || state == GameState.dealerTurn) {
      throw StateError('Cannot start new round during active play (state: $state)');
    }

    // Reset all state.
    dealerHand = Hand();
    playerHands = [Hand()];
    activeHandIndex = 0;
    hasSplit = false;
    handDoubled = [false];
    isSplitAceHand = [false];
    handOutcomes = [];

    // Deal 2 cards each: Player, Dealer, Player, Dealer
    playerHands[0] = playerHands[0].addCard(shoe.drawCard());
    dealerHand = dealerHand.addCard(shoe.drawCard());
    playerHands[0] = playerHands[0].addCard(shoe.drawCard());
    dealerHand = dealerHand.addCard(shoe.drawCard());

    // Check for immediate blackjack
    final playerEval = HandEvaluator.evaluate(playerHands[0].cards);
    final dealerEval = HandEvaluator.evaluate(dealerHand.cards);

    if (playerEval.isBlackjack && dealerEval.isBlackjack) {
      state = GameState.push;
      handOutcomes = [GameState.push];
    } else if (playerEval.isBlackjack) {
      state = GameState.playerBlackjack;
      handOutcomes = [GameState.playerBlackjack];
    } else if (dealerEval.isBlackjack) {
      state = GameState.dealerWin;
      handOutcomes = [GameState.dealerWin];
    } else {
      state = GameState.playerTurn;
    }
  }

  // ── Player actions ──────────────────────────────────────────────────────

  /// Player hits: adds a card to the active hand.
  void playerHit() {
    if (state != GameState.playerTurn) {
      throw StateError('Player can only hit during playerTurn');
    }

    playerHand = playerHand.addCard(shoe.drawCard());

    final evaluation = HandEvaluator.evaluate(playerHand.cards);
    if (evaluation.isBust) {
      _advanceHand(busted: true);
    }
  }

  /// Player stands: ends the active hand, advances to next or dealer.
  void playerStand() {
    if (state != GameState.playerTurn) {
      throw StateError('Player can only stand during playerTurn');
    }

    _advanceHand(busted: false);
  }

  /// Player doubles down: doubles the bet, draws exactly one card,
  /// then auto-stands.
  void playerDouble() {
    if (!canPlayerDouble) {
      throw StateError('Cannot double in current state');
    }

    handDoubled[activeHandIndex] = true;
    playerHand = playerHand.addCard(shoe.drawCard());

    final evaluation = HandEvaluator.evaluate(playerHand.cards);
    _advanceHand(busted: evaluation.isBust);
  }

  /// Player splits: creates two hands from a pair, each gets one new card.
  void playerSplit() {
    if (!canPlayerSplit) {
      throw StateError('Cannot split in current state');
    }

    final card0 = playerHand.cards[0];
    final card1 = playerHand.cards[1];
    final isAces = card0.rank == Rank.ace;

    // Create two hands, each starting with one card from the pair.
    final hand0 = Hand(cards: [card0]).addCard(shoe.drawCard());
    final hand1 = Hand(cards: [card1]).addCard(shoe.drawCard());

    playerHands = [hand0, hand1];
    handDoubled = [false, false];
    isSplitAceHand = [isAces, isAces];
    hasSplit = true;
    activeHandIndex = 0;

    if (isAces) {
      // Split aces: both hands auto-stand, go straight to dealer.
      state = GameState.dealerTurn;
      _dealerPlay();
    }
    // For non-aces: stay in playerTurn on hand 0.
  }

  // ── Query helpers ───────────────────────────────────────────────────────

  bool get canPlayerDouble =>
      state == GameState.playerTurn &&
      playerHand.cardCount == 2 &&
      !isSplitAceHand[activeHandIndex];

  bool get canPlayerSplit =>
      state == GameState.playerTurn &&
      !hasSplit &&
      playerHand.cardCount == 2 &&
      playerHand.cards[0].rank == playerHand.cards[1].rank;

  bool get isGameOver =>
      state == GameState.playerBust ||
      state == GameState.dealerBust ||
      state == GameState.playerBlackjack ||
      state == GameState.push ||
      state == GameState.playerWin ||
      state == GameState.dealerWin;

  bool get canPlayerHit =>
      state == GameState.playerTurn && !isSplitAceHand[activeHandIndex];

  bool get canPlayerStand => state == GameState.playerTurn;

  // ── Internals ───────────────────────────────────────────────────────────

  /// Advances to the next playable hand, or triggers dealer play if all done.
  void _advanceHand({required bool busted}) {
    if (busted) {
      // Mark this hand as busted (tracked for settlement).
      // Don't set the overall state to playerBust yet — other hands may remain.
    }

    // Find next hand that isn't already done (split aces auto-stand).
    final nextIndex = activeHandIndex + 1;
    if (hasSplit && nextIndex < playerHands.length) {
      activeHandIndex = nextIndex;
      // Stay in playerTurn for the next hand (unless it's a split-ace hand).
      if (isSplitAceHand[nextIndex]) {
        // This shouldn't happen — split aces skip player turn entirely.
        // But guard just in case.
        state = GameState.dealerTurn;
        _dealerPlay();
      }
      // Otherwise: state stays playerTurn, player acts on the next hand.
    } else {
      // All hands played — check if all busted.
      bool allBusted = true;
      for (int i = 0; i < playerHands.length; i++) {
        final eval = HandEvaluator.evaluate(playerHands[i].cards);
        if (!eval.isBust) {
          allBusted = false;
          break;
        }
      }

      if (allBusted) {
        // All hands busted — no need for dealer to play.
        state = GameState.playerBust;
        handOutcomes = List.generate(playerHands.length, (i) => GameState.playerBust);
      } else {
        state = GameState.dealerTurn;
        _dealerPlay();
      }
    }
  }

  /// Dealer plays per the configured rule (S17 or H17).
  void _dealerPlay() {
    while (true) {
      final evaluation = HandEvaluator.evaluate(dealerHand.cards);

      // Bust: dealer loses
      if (evaluation.isBust) {
        break; // Don't set state here — _resolve handles it.
      }

      // S17: stand on all 17s (soft and hard).
      // H17: stand on hard 17+; hit soft 17.
      final shouldStand = rules.dealerStandsSoft17
          ? evaluation.total >= 17
          : evaluation.total > 17 || (evaluation.total == 17 && !evaluation.isSoft);
      if (shouldStand) break;

      // Must hit
      dealerHand = dealerHand.addCard(shoe.drawCard());
    }

    // Resolve game
    _resolve();
  }

  /// Determines winner and sets final state. Handles split hands.
  void _resolve() {
    final dealerEval = HandEvaluator.evaluate(dealerHand.cards);
    final dealerBusted = dealerEval.isBust;

    if (!hasSplit) {
      // Single-hand resolution (original behavior).
      if (dealerBusted) {
        state = GameState.dealerBust;
        handOutcomes = [GameState.dealerBust];
        return;
      }

      final playerEval = HandEvaluator.evaluate(playerHands[0].cards);
      if (playerEval.total > dealerEval.total) {
        state = GameState.playerWin;
        handOutcomes = [GameState.playerWin];
      } else if (dealerEval.total > playerEval.total) {
        state = GameState.dealerWin;
        handOutcomes = [GameState.dealerWin];
      } else {
        state = GameState.push;
        handOutcomes = [GameState.push];
      }
      return;
    }

    // Split resolution: evaluate each hand independently.
    handOutcomes = [];
    for (int i = 0; i < playerHands.length; i++) {
      final playerEval = HandEvaluator.evaluate(playerHands[i].cards);

      if (playerEval.isBust) {
        handOutcomes.add(GameState.playerBust);
      } else if (dealerBusted) {
        handOutcomes.add(GameState.dealerBust);
      } else if (playerEval.total > dealerEval.total) {
        // 21 after split is NOT blackjack — always playerWin.
        handOutcomes.add(GameState.playerWin);
      } else if (dealerEval.total > playerEval.total) {
        handOutcomes.add(GameState.dealerWin);
      } else {
        handOutcomes.add(GameState.push);
      }
    }

    // Derive overall state from hand outcomes.
    final anyWin = handOutcomes.any((o) =>
        o == GameState.playerWin || o == GameState.dealerBust);
    final anyLose = handOutcomes.any((o) =>
        o == GameState.dealerWin || o == GameState.playerBust);

    if (anyWin && !anyLose) {
      state = GameState.playerWin;
    } else if (anyLose && !anyWin) {
      state = GameState.dealerWin;
    } else if (anyWin && anyLose) {
      // Mixed results — use push as the summary state.
      state = GameState.push;
    } else {
      // All pushes.
      state = GameState.push;
    }
  }
}
