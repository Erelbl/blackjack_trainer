import '../../../engine/config/blackjack_rules.dart';

/// Breakdown entry: (human-readable label, delta in percent).
typedef EdgeRow = (String, double);

/// Output of [HouseEdgeCalculator.estimate].
///
/// [edgePercent] is the total estimated house edge (e.g. 0.55 means 0.55%).
/// [breakdown]  lists the base then each applied delta in order.
/// [disclaimer] should be shown in the UI to set user expectations.
class HouseEdgeEstimate {
  const HouseEdgeEstimate({
    required this.edgePercent,
    required this.breakdown,
    required this.disclaimer,
  });

  final double edgePercent;
  final List<EdgeRow> breakdown;
  final String disclaimer;
}

/// Simple base + delta house-edge model.
///
/// Values are MVP estimates only — coarse but transparent.
/// Assumes the player uses basic strategy.
abstract final class HouseEdgeCalculator {
  static const _disclaimer =
      'Estimated edge. Assumes basic strategy. Does not account for '
      'side rules (surrender, DAS, RSA, etc.).';

  static HouseEdgeEstimate estimate(BlackjackRules rules) {
    final rows = <EdgeRow>[
      ('Base (6-deck, S17, 3:2)', 0.50),
    ];

    if (!rules.dealerStandsSoft17) {
      rows.add(('Dealer hits soft 17 (H17)', 0.20));
    }

    if (rules.blackjackPayout <= 1.2) {
      rows.add(('Blackjack pays 6:5', 1.40));
    }

    final deckDelta = _deckDelta(rules.deckCount);
    if (deckDelta != 0.0) {
      rows.add(('${rules.deckCount}-deck shoe', deckDelta));
    }

    final total =
        rows.fold(0.0, (sum, r) => sum + r.$2).clamp(0.0, double.infinity);

    return HouseEdgeEstimate(
      edgePercent: total,
      breakdown: rows,
      disclaimer: _disclaimer,
    );
  }

  static double _deckDelta(int decks) => switch (decks) {
        1 => -0.10,
        2 => -0.05,
        8 => 0.05,
        _ => 0.00,
      };
}
