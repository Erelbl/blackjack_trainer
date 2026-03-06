import '../models/card.dart';
import '../models/rank.dart';
import '../utils/hand_evaluator.dart';

/// The action recommended by basic strategy.
enum StrategyAction {
  hit,
  stand,
  doubleDown,
  split;

  /// Single-character label used in strategy table cells.
  String get label => switch (this) {
        StrategyAction.hit        => 'H',
        StrategyAction.stand      => 'S',
        StrategyAction.doubleDown => 'D',
        StrategyAction.split      => 'P',
      };

  String get displayName => switch (this) {
        StrategyAction.hit        => 'Hit',
        StrategyAction.stand      => 'Stand',
        StrategyAction.doubleDown => 'Double',
        StrategyAction.split      => 'Split',
      };
}

// Top-level shorthand constants — avoids the lowerCamelCase lint on static
// fields while keeping the table data compact and readable.
const _h = StrategyAction.hit;
const _s = StrategyAction.stand;
const _d = StrategyAction.doubleDown;
const _p = StrategyAction.split;

/// Basic strategy tables for 6-deck, dealer stands on soft 17 (S17).
///
/// Table layout: each row is a list of 10 [StrategyAction] values,
/// one per dealer upcard in order: 2, 3, 4, 5, 6, 7, 8, 9, 10/face, Ace.
/// Use [BasicStrategy.dealerIndex] to map a [Rank] to the correct column.
abstract final class BasicStrategy {
  /// Ordered dealer upcard display labels (matches column index 0–9).
  static const List<String> dealerUpcardLabels = [
    '2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'
  ];

  // ---------------------------------------------------------------------------
  // Hard totals table
  // Key: hard total (≤8 uses key 8; ≥17 uses key 17).
  // ---------------------------------------------------------------------------
  static const Map<int, List<StrategyAction>> hardTable = {
    8:  [_h, _h, _h, _h, _h, _h, _h, _h, _h, _h],
    9:  [_h, _d, _d, _d, _d, _h, _h, _h, _h, _h],
    10: [_d, _d, _d, _d, _d, _d, _d, _d, _h, _h],
    11: [_d, _d, _d, _d, _d, _d, _d, _d, _d, _h],
    12: [_h, _h, _s, _s, _s, _h, _h, _h, _h, _h],
    13: [_s, _s, _s, _s, _s, _h, _h, _h, _h, _h],
    14: [_s, _s, _s, _s, _s, _h, _h, _h, _h, _h],
    15: [_s, _s, _s, _s, _s, _h, _h, _h, _h, _h],
    16: [_s, _s, _s, _s, _s, _h, _h, _h, _h, _h],
    17: [_s, _s, _s, _s, _s, _s, _s, _s, _s, _s],
  };

  /// Display labels for hard table rows (keys in ascending order: 8..17).
  static const Map<int, String> hardRowLabels = {
    8:  '≤8',
    9:  '9',
    10: '10',
    11: '11',
    12: '12',
    13: '13',
    14: '14',
    15: '15',
    16: '16',
    17: '17+',
  };

  // ---------------------------------------------------------------------------
  // Soft totals table
  // Key: non-ace card value (2–9) → A+2 (soft 13) … A+9 (soft 20).
  // ---------------------------------------------------------------------------
  static const Map<int, List<StrategyAction>> softTable = {
    2: [_h, _h, _h, _d, _d, _h, _h, _h, _h, _h], // A+2 = soft 13
    3: [_h, _h, _h, _d, _d, _h, _h, _h, _h, _h], // A+3 = soft 14
    4: [_h, _h, _d, _d, _d, _h, _h, _h, _h, _h], // A+4 = soft 15
    5: [_h, _h, _d, _d, _d, _h, _h, _h, _h, _h], // A+5 = soft 16
    6: [_h, _d, _d, _d, _d, _h, _h, _h, _h, _h], // A+6 = soft 17
    7: [_s, _d, _d, _d, _d, _s, _s, _h, _h, _h], // A+7 = soft 18
    8: [_s, _s, _s, _s, _d, _s, _s, _s, _s, _s], // A+8 = soft 19
    9: [_s, _s, _s, _s, _s, _s, _s, _s, _s, _s], // A+9 = soft 20
  };

  /// Display labels for soft table rows.
  static const Map<int, String> softRowLabels = {
    2: 'A+2 (13)',
    3: 'A+3 (14)',
    4: 'A+4 (15)',
    5: 'A+5 (16)',
    6: 'A+6 (17)',
    7: 'A+7 (18)',
    8: 'A+8 (19)',
    9: 'A+9 (20)',
  };

  // ---------------------------------------------------------------------------
  // Pairs table
  // Key: pair card value (1 = Aces, 2–10; J/Q/K map to 10).
  // ---------------------------------------------------------------------------
  static const Map<int, List<StrategyAction>> pairsTable = {
    1:  [_p, _p, _p, _p, _p, _p, _p, _p, _p, _p], // A-A
    2:  [_p, _p, _p, _p, _p, _p, _h, _h, _h, _h], // 2-2
    3:  [_p, _p, _p, _p, _p, _p, _h, _h, _h, _h], // 3-3
    4:  [_h, _h, _h, _p, _p, _h, _h, _h, _h, _h], // 4-4
    5:  [_d, _d, _d, _d, _d, _d, _d, _d, _h, _h], // 5-5 (treat as hard 10)
    6:  [_p, _p, _p, _p, _p, _h, _h, _h, _h, _h], // 6-6
    7:  [_p, _p, _p, _p, _p, _p, _h, _h, _h, _h], // 7-7
    8:  [_p, _p, _p, _p, _p, _p, _p, _p, _p, _p], // 8-8
    9:  [_p, _p, _p, _p, _p, _s, _p, _p, _s, _s], // 9-9
    10: [_s, _s, _s, _s, _s, _s, _s, _s, _s, _s], // 10-10
  };

  /// Display labels for pairs table rows.
  static const Map<int, String> pairsRowLabels = {
    1:  'A-A',
    2:  '2-2',
    3:  '3-3',
    4:  '4-4',
    5:  '5-5',
    6:  '6-6',
    7:  '7-7',
    8:  '8-8',
    9:  '9-9',
    10: '10-10',
  };

  /// Returns the column index (0–9) for [rank] in the strategy tables.
  static int dealerIndex(Rank rank) => switch (rank) {
        Rank.two   => 0,
        Rank.three => 1,
        Rank.four  => 2,
        Rank.five  => 3,
        Rank.six   => 4,
        Rank.seven => 5,
        Rank.eight => 6,
        Rank.nine  => 7,
        Rank.ten || Rank.jack || Rank.queen || Rank.king => 8,
        Rank.ace   => 9,
      };

  /// Returns the best [StrategyAction] from [availableActions] for the given
  /// situation, applying 6-deck S17 basic strategy.
  ///
  /// If the ideal action (from [recommend]) is in [availableActions] it is
  /// returned unchanged. Otherwise the best fallback is computed:
  ///   - doubleDown → hit  (taking a card is the next-best move)
  ///   - split      → re-evaluate the hand as a hard/soft total (no pair priority)
  static StrategyAction recommendFallback({
    required List<Card> playerCards,
    required Rank dealerUpcard,
    Set<StrategyAction> availableActions = const {
      StrategyAction.hit,
      StrategyAction.stand,
    },
  }) {
    final ideal = recommend(playerCards: playerCards, dealerUpcard: dealerUpcard);
    if (availableActions.contains(ideal)) return ideal;

    if (ideal == StrategyAction.doubleDown) return StrategyAction.hit;

    // split → evaluate as plain hard/soft total, collapsing doubles → hit.
    return _hitOrStand(playerCards: playerCards, di: dealerIndex(dealerUpcard));
  }

  // Hit-or-stand evaluation used when the ideal action is unavailable.
  // Evaluates by soft/hard total; any double recommendation collapses to hit.
  static StrategyAction _hitOrStand({
    required List<Card> playerCards,
    required int di,
  }) {
    final eval = HandEvaluator.evaluate(playerCards);

    if (eval.isSoft && playerCards.length == 2) {
      for (final card in playerCards) {
        if (card.rank != Rank.ace) {
          final key = card.rank.blackjackValue.clamp(2, 9);
          final row = softTable[key];
          if (row != null) {
            final a = row[di];
            return a == StrategyAction.doubleDown ? StrategyAction.hit : a;
          }
        }
      }
    }

    if (eval.isSoft) return eval.total >= 18 ? StrategyAction.stand : StrategyAction.hit;

    final total = eval.total;
    if (total >= 17) return StrategyAction.stand;
    if (total <= 8) return StrategyAction.hit;
    final row = hardTable[total];
    if (row != null) {
      final a = row[di];
      return a == StrategyAction.doubleDown ? StrategyAction.hit : a;
    }
    return StrategyAction.hit;
  }

  /// Returns the recommended [StrategyAction] for [playerCards] against
  /// [dealerUpcard], using 6-deck S17 basic strategy.
  ///
  /// Decision priority:
  ///   1. Pair (2-card hand with equal blackjack values)
  ///   2. Soft (2-card hand with an ace counted as 11)
  ///   3. Multi-card soft (simplified: stand ≥18, else hit)
  ///   4. Hard total
  static StrategyAction recommend({
    required List<Card> playerCards,
    required Rank dealerUpcard,
  }) {
    final di = dealerIndex(dealerUpcard);

    // 1. Pair check — only applicable for exactly 2 cards.
    if (playerCards.length == 2) {
      final r0 = playerCards[0].rank;
      final r1 = playerCards[1].rank;
      final isAcePair = r0 == Rank.ace && r1 == Rank.ace;
      final v0 = r0.blackjackValue;
      final v1 = r1.blackjackValue;
      if (isAcePair || v0 == v1) {
        final key = isAcePair ? 1 : v0.clamp(1, 10);
        final row = pairsTable[key];
        if (row != null) return row[di];
      }
    }

    final eval = HandEvaluator.evaluate(playerCards);

    // 2. Two-card soft hand (ace + non-ace).
    if (eval.isSoft && playerCards.length == 2) {
      for (final card in playerCards) {
        if (card.rank != Rank.ace) {
          final key = card.rank.blackjackValue.clamp(2, 9);
          final row = softTable[key];
          if (row != null) return row[di];
        }
      }
    }

    // 3. Multi-card soft — doubling not possible; stand ≥18, hit otherwise.
    if (eval.isSoft) {
      return eval.total >= 18 ? _s : _h;
    }

    // 4. Hard total.
    final total = eval.total;
    if (total >= 17) return _s;
    if (total <= 8)  return _h;
    final row = hardTable[total];
    return row != null ? row[di] : _h;
  }
}
