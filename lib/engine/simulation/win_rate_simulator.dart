import 'dart:math';
import 'package:flutter/foundation.dart' show compute;
import '../models/card.dart';

// ---------------------------------------------------------------------------
// Public result type
// ---------------------------------------------------------------------------

class WinRateResult {
  final double standWinRate;
  final double hitWinRate;

  const WinRateResult({required this.standWinRate, required this.hitWinRate});
}

// ---------------------------------------------------------------------------
// Isolate input — only plain Dart types so it is sendable across isolates.
// ---------------------------------------------------------------------------

class _SimInput {
  final List<int> remainingRankIndices;
  final List<int> playerRankIndices;
  final List<int> dealerRankIndices;
  final int count;
  final int seed;

  const _SimInput({
    required this.remainingRankIndices,
    required this.playerRankIndices,
    required this.dealerRankIndices,
    required this.count,
    required this.seed,
  });
}

// ---------------------------------------------------------------------------
// Rank helpers (must match Rank.values order)
// Rank.values: two(0) three(1) four(2) five(3) six(4) seven(5) eight(6)
//              nine(7) ten(8) jack(9) queen(10) king(11) ace(12)
// ---------------------------------------------------------------------------

int _rankValue(int rankIndex) {
  if (rankIndex == 12) return 11; // ace
  if (rankIndex >= 8) return 10;  // ten, jack, queen, king
  return rankIndex + 2;           // two=2 … nine=9
}

(int total, bool isSoft) _evalRanks(List<int> rankIndices) {
  int total = 0;
  int aces = 0;
  for (final ri in rankIndices) {
    total += _rankValue(ri);
    if (ri == 12) aces++;
  }
  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }
  return (total, aces > 0);
}

// ---------------------------------------------------------------------------
// Top-level simulation function — runs in isolate via compute().
//
// Each trial uses one freshly-shuffled copy of the remaining deck.
//
// STAND sim: dealer draws from position 0 until ≥17 (S17) or bust.
// HIT sim:   player takes deck[0], plays simplified strategy (stand hard≥17,
//            soft≥18), then dealer draws from remaining positions.
//
// Simplified player strategy in the HIT sim deliberately under-estimates
// player EV slightly but is fast and correct for the primary comparison.
// ---------------------------------------------------------------------------

// ignore: library_private_types_in_public_api  (top-level needed for compute)
WinRateResult _simulateWinRates(_SimInput input) {
  final rng = Random(input.seed);
  int standWins = 0, standTotal = 0;
  int hitWins = 0, hitTotal = 0;

  final (playerTotal, _) = _evalRanks(input.playerRankIndices);

  for (int trial = 0; trial < input.count; trial++) {
    final deck = input.remainingRankIndices.toList();
    deck.shuffle(rng);

    // ── Stand simulation ──────────────────────────────────────────────────
    {
      int p = 0;
      final dealer = input.dealerRankIndices.toList();
      while (p < deck.length) {
        final (dt, _) = _evalRanks(dealer);
        if (dt >= 17 || dt > 21) break; // S17: stand on all 17s
        dealer.add(deck[p++]);
      }
      final (dealerTotal, _) = _evalRanks(dealer);
      standTotal++;
      if (dealerTotal > 21 || playerTotal > dealerTotal) standWins++;
    }

    // ── Hit simulation ────────────────────────────────────────────────────
    {
      int p = 0;
      if (p >= deck.length) {
        hitTotal++;
        continue;
      }
      final player = [...input.playerRankIndices, deck[p++]];
      var (pt, ps) = _evalRanks(player);

      if (pt > 21) {
        hitTotal++; // immediate bust
        continue;
      }

      // Player plays: stand on hard ≥17 or soft ≥18.
      while (true) {
        (pt, ps) = _evalRanks(player);
        if (pt > 21) break;
        if (!ps && pt >= 17) break; // hard stand
        if (ps && pt >= 18) break;  // soft stand
        if (p >= deck.length) break;
        player.add(deck[p++]);
      }

      if (pt > 21) {
        hitTotal++;
        continue;
      }

      // Dealer plays from same shuffled deck at current position.
      final dealer = input.dealerRankIndices.toList();
      while (p < deck.length) {
        final (dt, _) = _evalRanks(dealer);
        if (dt >= 17 || dt > 21) break;
        dealer.add(deck[p++]);
      }
      final (dealerTotal, _) = _evalRanks(dealer);
      hitTotal++;
      if (dealerTotal > 21 || pt > dealerTotal) hitWins++;
    }
  }

  return WinRateResult(
    standWinRate: standTotal == 0 ? 0.0 : standWins / standTotal,
    hitWinRate:   hitTotal   == 0 ? 0.0 : hitWins   / hitTotal,
  );
}

// ---------------------------------------------------------------------------
// Public service
// ---------------------------------------------------------------------------

abstract final class WinRateSimulator {
  static final _cache = <String, WinRateResult>{};

  /// Estimates stand/hit win rates via Monte Carlo simulation in an isolate.
  ///
  /// Results are cached by shoe composition + player hand + dealer cards so
  /// repeated calls for the same position return instantly.
  static Future<WinRateResult> simulate({
    required List<Card> remainingCards,
    required List<Card> playerCards,
    required List<Card> dealerCards,
    int count = 2000,
  }) async {
    final key = _cacheKey(playerCards, dealerCards, remainingCards);
    final cached = _cache[key];
    if (cached != null) return cached;

    final input = _SimInput(
      remainingRankIndices:
          remainingCards.map((c) => c.rank.index).toList(),
      playerRankIndices:
          playerCards.map((c) => c.rank.index).toList(),
      dealerRankIndices:
          dealerCards.map((c) => c.rank.index).toList(),
      count: count,
      seed: key.hashCode & 0x7FFFFFFF,
    );

    final result = await compute(_simulateWinRates, input);
    _cache[key] = result;
    return result;
  }

  /// Cache key: player ranks | dealer ranks | rank frequency counts in shoe.
  /// Using rank frequencies (not ordering) makes the key order-independent.
  static String _cacheKey(
    List<Card> player,
    List<Card> dealer,
    List<Card> remaining,
  ) {
    final counts = List.filled(13, 0);
    for (final c in remaining) {
      counts[c.rank.index]++;
    }
    final p = player.map((c) => c.rank.index).join(',');
    final d = dealer.map((c) => c.rank.index).join(',');
    return '$p|$d|${counts.join(',')}';
  }
}
