/// Immutable rule-set for a Blackjack game.
///
/// Defaults match the standard 6-deck S17 casino configuration used by the
/// app.  Additional rule flags (dealerStandsSoft17, blackjackPayout) are
/// carried here for future wiring; they do not yet affect engine logic.
class BlackjackRules {
  /// Number of 52-card decks in the shoe.
  final int deckCount;

  /// Dealer stands on all 17s (soft and hard) when true; hits soft-17 when false.
  final bool dealerStandsSoft17;

  /// Payout multiplier for a natural blackjack (1.5 = 3:2, 1.2 = 6:5, etc.).
  final double blackjackPayout;

  const BlackjackRules({
    this.deckCount = 6,
    this.dealerStandsSoft17 = true,
    this.blackjackPayout = 1.5,
  });

  BlackjackRules copyWith({
    int? deckCount,
    bool? dealerStandsSoft17,
    double? blackjackPayout,
  }) {
    return BlackjackRules(
      deckCount: deckCount ?? this.deckCount,
      dealerStandsSoft17: dealerStandsSoft17 ?? this.dealerStandsSoft17,
      blackjackPayout: blackjackPayout ?? this.blackjackPayout,
    );
  }

  factory BlackjackRules.fromJson(Map<String, dynamic> json) {
    return BlackjackRules(
      deckCount: (json['deckCount'] as int?) ?? 6,
      dealerStandsSoft17: (json['dealerStandsSoft17'] as bool?) ?? true,
      blackjackPayout: (json['blackjackPayout'] as num?)?.toDouble() ?? 1.5,
    );
  }

  Map<String, dynamic> toJson() => {
        'deckCount': deckCount,
        'dealerStandsSoft17': dealerStandsSoft17,
        'blackjackPayout': blackjackPayout,
      };
}
