import '../../../engine/models/card.dart';
import '../../../engine/game/game_state.dart';

class BlackjackState {
  final List<Card> playerCards;
  final List<Card> dealerCards;
  final GameState gameState;
  final bool roundActive;
  final String? resultMessage;

  const BlackjackState({
    required this.playerCards,
    required this.dealerCards,
    required this.gameState,
    required this.roundActive,
    this.resultMessage,
  });

  factory BlackjackState.initial() {
    return const BlackjackState(
      playerCards: [],
      dealerCards: [],
      gameState: GameState.idle,
      roundActive: false,
      resultMessage: null,
    );
  }

  BlackjackState copyWith({
    List<Card>? playerCards,
    List<Card>? dealerCards,
    GameState? gameState,
    bool? roundActive,
    String? resultMessage,
  }) {
    return BlackjackState(
      playerCards: playerCards ?? this.playerCards,
      dealerCards: dealerCards ?? this.dealerCards,
      gameState: gameState ?? this.gameState,
      roundActive: roundActive ?? this.roundActive,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
}
