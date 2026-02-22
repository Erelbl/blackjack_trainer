import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../engine/game/blackjack_game.dart';
import '../../../engine/game/game_state.dart';
import '../../../data/providers/stats_providers.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../data/providers/progression_providers.dart';
import 'blackjack_state.dart';

class BlackjackController extends StateNotifier<BlackjackState> {
  late BlackjackGame _game;
  late bool _previousRoundActive = false;
  final Ref _ref;

  BlackjackController(this._ref) : super(BlackjackState.initial()) {
    _game = BlackjackGame(deckCount: 6);
  }

  void startNewRound() {
    // Allow starting new round from idle or any end state
    final canStart = _game.state == GameState.idle ||
        _game.state == GameState.playerBust ||
        _game.state == GameState.dealerBust ||
        _game.state == GameState.playerBlackjack ||
        _game.state == GameState.push ||
        _game.state == GameState.playerWin ||
        _game.state == GameState.dealerWin;

    if (!canStart) {
      print('[BlackjackController] Cannot start new round from state: ${_game.state}');
      return;
    }

    print('[BlackjackController] Starting new round (current state: ${_game.state})');
    _game.startNewRound();
    _syncState();
    print('[BlackjackController] New round started (new state: ${_game.state}, player: ${_game.playerHand.cards.length} cards, dealer: ${_game.dealerHand.cards.length} cards)');
  }

  void hit() {
    if (!_game.canPlayerHit) {
      return;
    }

    _game.playerHit();
    _syncState();
  }

  void stand() {
    if (!_game.canPlayerStand) {
      return;
    }

    _game.playerStand();
    _syncState();
  }

  void reset() {
    _game = BlackjackGame(deckCount: 6);
    state = BlackjackState.initial();
  }

  void _syncState() {
    final currentRoundActive = _game.canPlayerHit || _game.canPlayerStand;

    state = BlackjackState(
      playerCards: _game.playerHand.cards.toList(),
      dealerCards: _game.dealerHand.cards.toList(),
      gameState: _game.state,
      roundActive: currentRoundActive,
      resultMessage: _getResultMessage(_game.state),
    );

    // Record stats, award coins, and award XP when round just ended
    if (_previousRoundActive && !currentRoundActive) {
      _ref.read(statsControllerProvider.notifier).recordRound(_game.state);
      _ref.read(economyControllerProvider.notifier).addCoins(_calculateReward(_game.state));
      _ref.read(progressionControllerProvider.notifier).awardXP(_calculateXP(_game.state));

      // Check milestones based on total hands played
      final stats = _ref.read(statsControllerProvider).value;
      if (stats != null) {
        _ref.read(progressionControllerProvider.notifier).checkMilestones(stats.handsPlayed);
      }
    }

    _previousRoundActive = currentRoundActive;
  }

  int _calculateReward(GameState gameState) {
    int reward = 5; // Base reward for playing

    // Add win bonus
    if (gameState == GameState.playerWin ||
        gameState == GameState.dealerBust ||
        gameState == GameState.playerBlackjack) {
      reward += 10;
    }

    // Add blackjack bonus
    if (gameState == GameState.playerBlackjack) {
      reward += 25;
    }

    return reward;
  }

  int _calculateXP(GameState gameState) {
    int xp = 10; // Base XP for playing

    // Add win bonus
    if (gameState == GameState.playerWin ||
        gameState == GameState.dealerBust ||
        gameState == GameState.playerBlackjack) {
      xp += 15;
    }

    // Add blackjack bonus
    if (gameState == GameState.playerBlackjack) {
      xp += 50;
    }

    return xp;
  }

  String? _getResultMessage(GameState gameState) {
    return switch (gameState) {
      GameState.idle => null,
      GameState.playerTurn => null,
      GameState.dealerTurn => null,
      GameState.playerBlackjack => 'Blackjack!',
      GameState.playerWin => 'You win!',
      GameState.dealerWin => 'Dealer wins',
      GameState.playerBust => 'Bust!',
      GameState.dealerBust => 'Dealer busts - You win!',
      GameState.push => 'Push!',
    };
  }
}

final blackjackControllerProvider =
    StateNotifierProvider<BlackjackController, BlackjackState>((ref) {
  return BlackjackController(ref);
});
