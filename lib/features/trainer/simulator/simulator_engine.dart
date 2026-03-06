import 'dart:isolate';
import 'dart:math';

import '../../../engine/config/blackjack_rules.dart';
import '../../../engine/game/blackjack_game.dart';
import '../../../engine/game/game_state.dart';
import '../../../engine/models/shoe.dart';
import '../../../engine/strategy/basic_strategy.dart';

// ── Public result ──────────────────────────────────────────────────────────────

class SimResult {
  const SimResult({
    required this.handsSimulated,
    required this.evPerHand,
    required this.evPer100Hands,
    required this.evPer100UnitsWagered,
    required this.winRate,
    required this.pushRate,
    required this.lossRate,
    required this.blackjackRate,
    required this.doubleCount,
    required this.splitCount,
    required this.totalUnitsWagered,
    required this.elapsedMs,
  });

  final int handsSimulated;

  /// Mean net profit per hand in bet units (typically slightly negative).
  final double evPerHand;

  /// [evPerHand] × 100 — the conventional house-edge presentation.
  final double evPer100Hands;

  /// Net profit divided by total units wagered × 100.
  final double evPer100UnitsWagered;

  final double winRate;
  final double pushRate;
  final double lossRate;
  final double blackjackRate;

  /// Number of double-down actions executed across all simulated rounds.
  final int doubleCount;

  /// Number of split actions executed across all simulated rounds.
  final int splitCount;

  /// Total bet units put at risk (1 per round + 1 per double + 1 per split).
  final int totalUnitsWagered;

  final int elapsedMs;
}

// ── Sendable input (plain types only — safe across isolate boundary) ───────────

class _SimInput {
  const _SimInput({
    required this.deckCount,
    required this.dealerStandsSoft17,
    required this.blackjackPayout,
    required this.hands,
    required this.seed,
  });

  final int deckCount;
  final bool dealerStandsSoft17;
  final double blackjackPayout;
  final int hands;
  final int seed;
}

// ── Top-level helpers (visible to closure inside spawned isolate) ──────────────

BlackjackGame _newGame(BlackjackRules rules, Random rng) =>
    BlackjackGame(rules: rules, shoe: Shoe(deckCount: rules.deckCount, random: rng));

double _outcomeNet(GameState outcome, bool doubled, BlackjackRules rules) {
  final m = doubled ? 2.0 : 1.0;
  return switch (outcome) {
    GameState.playerBlackjack                    => rules.blackjackPayout,
    GameState.playerWin || GameState.dealerBust  => m,
    GameState.push                               => 0.0,
    _                                            => -m,
  };
}

/// Computes net profit for a completed round.
///
/// For splits, each hand outcome is resolved independently against
/// [game.handDoubled], then summed.  For single-hand rounds, [game.state]
/// is used directly.
double _computeNet(BlackjackGame game, BlackjackRules rules) {
  if (!game.hasSplit) {
    return _outcomeNet(game.state, game.handDoubled[0], rules);
  }
  var net = 0.0;
  for (var i = 0; i < game.handOutcomes.length; i++) {
    net += _outcomeNet(game.handOutcomes[i], game.handDoubled[i], rules);
  }
  return net;
}

/// Main simulation loop — runs entirely inside the spawned isolate.
SimResult _runSimulation(_SimInput input) {
  final sw = Stopwatch()..start();
  final rng = Random(input.seed);
  final rules = BlackjackRules(
    deckCount: input.deckCount,
    dealerStandsSoft17: input.dealerStandsSoft17,
    blackjackPayout: input.blackjackPayout,
  );

  var game = _newGame(rules, rng);

  double totalProfit = 0;
  int wins = 0, pushes = 0, losses = 0, blackjacks = 0;
  int doubleCount = 0, splitCount = 0, totalUnitsWagered = 0;

  for (var i = 0; i < input.hands; i++) {
    // Refresh shoe before it empties (a 6-deck shoe holds 312 cards;
    // refill at ≤20 to ensure every hand always has enough cards).
    if (game.shoe.cardsRemaining < 20) {
      game = _newGame(rules, rng);
    }

    game.startNewRound();

    if (game.state == GameState.playerBlackjack) blackjacks++;

    // 1 unit wagered for the initial bet; incremented below for doubles/splits.
    var roundUnits = 1;

    // Player turn — the while loop naturally handles splits because
    // BlackjackGame.activeHandIndex advances to the next split hand
    // (state stays playerTurn) until all hands are resolved.
    while (game.state == GameState.playerTurn) {
      final available = <StrategyAction>{
        StrategyAction.hit,
        StrategyAction.stand,
      };
      if (game.canPlayerDouble) available.add(StrategyAction.doubleDown);
      if (game.canPlayerSplit) available.add(StrategyAction.split);

      final action = BasicStrategy.recommendFallback(
        playerCards: game.playerHand.cards,
        dealerUpcard: game.dealerHand.cards[0].rank,
        availableActions: available,
      );

      switch (action) {
        case StrategyAction.hit:
          game.playerHit();
        case StrategyAction.stand:
          game.playerStand();
        case StrategyAction.doubleDown:
          doubleCount++;
          roundUnits++; // extra unit staked when doubling
          game.playerDouble();
        case StrategyAction.split:
          splitCount++;
          roundUnits++; // extra unit staked for the new split hand
          game.playerSplit();
      }
    }

    totalUnitsWagered += roundUnits;

    final net = _computeNet(game, rules);
    totalProfit += net;
    if (net > 0) {
      wins++;
    } else if (net < 0) {
      losses++;
    } else {
      pushes++;
    }
  }

  sw.stop();
  final ev = totalProfit / input.hands;
  final evPerUnit = totalUnitsWagered > 0
      ? (totalProfit / totalUnitsWagered) * 100.0
      : 0.0;

  return SimResult(
    handsSimulated: input.hands,
    evPerHand: ev,
    evPer100Hands: ev * 100,
    evPer100UnitsWagered: evPerUnit,
    winRate: wins / input.hands,
    pushRate: pushes / input.hands,
    lossRate: losses / input.hands,
    blackjackRate: blackjacks / input.hands,
    doubleCount: doubleCount,
    splitCount: splitCount,
    totalUnitsWagered: totalUnitsWagered,
    elapsedMs: sw.elapsedMilliseconds,
  );
}

// ── Public API ─────────────────────────────────────────────────────────────────

abstract final class SimulatorEngine {
  /// Runs [hands] simulated rounds of basic-strategy blackjack off the main
  /// thread via [Isolate.run] and returns a [SimResult].
  ///
  /// Passing an explicit [seed] makes runs deterministic; omitting it picks a
  /// seed from the current timestamp for varied results.
  static Future<SimResult> estimate(
    BlackjackRules rules, {
    int hands = 50000,
    int? seed,
  }) {
    final input = _SimInput(
      deckCount: rules.deckCount,
      dealerStandsSoft17: rules.dealerStandsSoft17,
      blackjackPayout: rules.blackjackPayout,
      hands: hands,
      seed: seed ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF),
    );
    return Isolate.run(() => _runSimulation(input));
  }
}
