import 'dart:math';

/// Generates an ascending list of snap points for the bet slider.
///
/// - Always includes base values [5, 10, 25, 50, 100] filtered to [cap].
/// - cap = min([coins], [maxBet]).
/// - Fills in values above 100 with tiered steps:
///     100–500  → step 25
///     500–2000 → step 100
///     above    → step 500
/// - Always includes the exact cap (highest affordable amount).
/// - Result is capped at 20 entries; important base points are preserved.
List<int> generateSnapPoints(int coins, {int maxBet = 9999}) {
  final cap = min(coins, maxBet);
  if (cap <= 0) return [];

  final pts = <int>{};

  // Base set (filtered to cap)
  for (final b in const [5, 10, 25, 50, 100]) {
    if (b <= cap) pts.add(b);
  }

  // Tiered additions
  if (cap > 100) {
    final tier1End = min(cap, 500);
    for (var v = 125; v <= tier1End; v += 25) {
      pts.add(v);
    }
  }
  if (cap > 500) {
    final tier2End = min(cap, 2000);
    for (var v = 600; v <= tier2End; v += 100) {
      pts.add(v);
    }
  }
  if (cap > 2000) {
    for (var v = 2500; v <= cap; v += 500) {
      pts.add(v);
    }
  }

  // Always include the exact cap
  pts.add(cap);

  final result = pts.toList()..sort();
  if (result.length <= 20) return result;

  // Sample down to 20 entries, always preserving important base points.
  final important = <int>{result.first, result.last};
  for (final b in const [5, 10, 25, 50, 100]) {
    if (pts.contains(b)) important.add(b);
  }

  final remaining = 20 - important.length;
  if (remaining > 0) {
    final fill =
        result.where((v) => !important.contains(v)).toList();
    final stride = fill.length / remaining.toDouble();
    for (var i = 0; i < remaining; i++) {
      important.add(fill[(i * stride).round().clamp(0, fill.length - 1)]);
    }
  }

  return important.toList()..sort();
}

/// Returns [bet] clamped down to the highest snap point affordable with
/// [coins]. Returns [bet] unchanged when [bet] <= [coins].
int clampBetToCoins(int bet, int coins) {
  if (bet <= coins) return bet;
  final snaps = generateSnapPoints(coins);
  return snaps.isNotEmpty ? snaps.last : 5;
}
