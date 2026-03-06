import '../../../engine/config/blackjack_rules.dart';
import '../../../engine/models/card.dart';
import '../../../engine/game/game_state.dart';
import '../../../engine/simulation/win_rate_simulator.dart';
import '../../../engine/utils/xp_utils.dart';

class BlackjackState {
  /// Rule-set active for this session. Defaults to 6-deck S17 3:2.
  final BlackjackRules rules;
  final List<Card> playerCards;
  final List<Card> dealerCards;
  final GameState gameState;
  final bool roundActive;
  final String? resultMessage;
  /// True while the controller is processing an action (single-flight guard).
  final bool isActionLocked;
  /// The player's current bet for the active round.
  final int currentBet;
  /// Whether the Decision Assist (Win%) feature is enabled. Off by default.
  /// When off, Monte Carlo simulation is not run at all.
  final bool showDecisionAssist;
  /// Async win-rate estimate — null until simulation completes or non-playerTurn
  /// or [showDecisionAssist] is false.
  final WinRateResult? winRates;
  /// True as long as every player decision this hand has matched basic strategy.
  /// Reset to true at the start of each new round.
  final bool perfectPlay;
  /// XP breakdown for the most recently completed hand.
  /// Set when the round ends; cleared when a new round starts or auto-reset fires.
  /// Excluded from [copyWith] — managed explicitly, same pattern as [winRates].
  final XpResult? lastXpResult;
  /// Net coin payout for the most recently completed round (positive = gain,
  /// negative = loss, 0 = push).  Accounts for split and doubled hands.
  /// Set when the round ends alongside [lastXpResult]; cleared on new round /
  /// auto-reset.  Excluded from [copyWith] — managed explicitly.
  final int? lastRoundPayout;

  // ── Split fields ────────────────────────────────────────────────────────
  /// True when the player has split this round.
  final bool hasSplit;
  /// Index of the hand currently being played (0 or 1 during split).
  final int activeHandIndex;
  /// All player hands — single-element list normally, two during split.
  final List<List<Card>> allPlayerHands;
  /// Whether each hand has been doubled.
  final List<bool> handsDoubled;
  /// Per-hand terminal outcomes, set after settlement. Null until game over.
  final List<GameState>? handOutcomes;
  /// Whether the active hand can double.
  final bool canDouble;
  /// Whether the active hand can split.
  final bool canSplit;

  const BlackjackState({
    this.rules = const BlackjackRules(),
    required this.playerCards,
    required this.dealerCards,
    required this.gameState,
    required this.roundActive,
    this.resultMessage,
    this.isActionLocked = false,
    this.currentBet = 10,
    this.showDecisionAssist = false,
    this.winRates,
    this.perfectPlay = true,
    this.lastXpResult,
    this.lastRoundPayout,
    this.hasSplit = false,
    this.activeHandIndex = 0,
    this.allPlayerHands = const [[]],
    this.handsDoubled = const [false],
    this.handOutcomes,
    this.canDouble = false,
    this.canSplit = false,
  });

  factory BlackjackState.initial() {
    return const BlackjackState(
      playerCards: [],
      dealerCards: [],
      gameState: GameState.idle,
      roundActive: false,
      resultMessage: null,
      isActionLocked: false,
      perfectPlay: true,
    );
  }

  bool get isSplitRound => hasSplit;

  BlackjackState copyWith({
    BlackjackRules? rules,
    List<Card>? playerCards,
    List<Card>? dealerCards,
    GameState? gameState,
    bool? roundActive,
    String? resultMessage,
    bool? isActionLocked,
    int? currentBet,
    bool? showDecisionAssist,
    bool? perfectPlay,
    bool? hasSplit,
    int? activeHandIndex,
    List<List<Card>>? allPlayerHands,
    List<bool>? handsDoubled,
    List<GameState>? handOutcomes,
    bool? canDouble,
    bool? canSplit,
    // winRates, lastXpResult, and lastRoundPayout are intentionally absent from
    // copyWith — they are managed explicitly in _syncState() and related callbacks.
  }) {
    return BlackjackState(
      rules: rules ?? this.rules,
      playerCards: playerCards ?? this.playerCards,
      dealerCards: dealerCards ?? this.dealerCards,
      gameState: gameState ?? this.gameState,
      roundActive: roundActive ?? this.roundActive,
      resultMessage: resultMessage ?? this.resultMessage,
      isActionLocked: isActionLocked ?? this.isActionLocked,
      currentBet: currentBet ?? this.currentBet,
      showDecisionAssist: showDecisionAssist ?? this.showDecisionAssist,
      perfectPlay: perfectPlay ?? this.perfectPlay,
      winRates: winRates,             // always preserved by copyWith
      lastXpResult: lastXpResult,     // always preserved by copyWith
      lastRoundPayout: lastRoundPayout, // always preserved by copyWith
      hasSplit: hasSplit ?? this.hasSplit,
      activeHandIndex: activeHandIndex ?? this.activeHandIndex,
      allPlayerHands: allPlayerHands ?? this.allPlayerHands,
      handsDoubled: handsDoubled ?? this.handsDoubled,
      handOutcomes: handOutcomes ?? this.handOutcomes,
      canDouble: canDouble ?? this.canDouble,
      canSplit: canSplit ?? this.canSplit,
    );
  }
}
