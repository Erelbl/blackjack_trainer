enum GameState {
  /// Initial state, no game in progress
  idle,

  /// Player can hit, stand, or double
  playerTurn,

  /// Dealer is playing per house rules (S17)
  dealerTurn,

  /// Player's hand exceeded 21
  playerBust,

  /// Dealer's hand exceeded 21, player wins
  dealerBust,

  /// Player has natural 21 (2 cards)
  playerBlackjack,

  /// Player and dealer have equal value (push/tie)
  push,

  /// Player's hand beats dealer's
  playerWin,

  /// Dealer's hand beats player's
  dealerWin,
}
