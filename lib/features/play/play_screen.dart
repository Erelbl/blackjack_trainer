import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../engine/simulation/win_rate_simulator.dart';
import '../../engine/game/game_state.dart';
import '../../engine/utils/hand_evaluator.dart';
import '../../engine/utils/bet_utils.dart';
import '../../engine/config/retention_config.dart';
import '../../engine/utils/progression_utils.dart' show levelUpCoins;
import '../../shared/widgets/coin_balance.dart';
import '../../app/theme.dart';
import '../../data/providers/economy_providers.dart';
import '../../data/providers/progression_providers.dart';
import '../../data/providers/weekly_goal_providers.dart';
import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';
import '../../services/audio_service.dart';
import 'debug/rebuild_counter.dart';
import 'state/blackjack_controller.dart';
import 'state/counting_session_controller.dart';
import 'state/session_stats.dart';
import '../../data/providers/stats_providers.dart';
import '../../engine/utils/xp_utils.dart';
import 'widgets/card_assets.dart';
import 'widgets/table_background.dart';
import 'widgets/card_row.dart';
import '../store/models/table_theme_item.dart';
import '../../engine/progression/progression_manager.dart';
import '../../engine/progression/challenge_definitions.dart';

// ---------------------------------------------------------------------------
// Layout spacing constants
// ---------------------------------------------------------------------------
const double _kHudPadH = 20.0;
const double _kHudPadV = 12.0;
const double _kBannerH = 56.0;    // reserved height for the outcome banner slot
const double _kSectionGap = 20.0; // vertical gap between table sections
const double _kActionPadH = 16.0;
const double _kActionPadV = 8.0;
const double _kCardLabelGap = 12.0;
const double _kTotalLabelGap = 8.0;

// ---------------------------------------------------------------------------
// Root screen
// ---------------------------------------------------------------------------
class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  bool _precached = false;
  late final BlackjackController _controller;

  /// GlobalKey placed on the CoinBalance widget — used to locate the target
  /// position for the coin-burst fly animation.
  final GlobalKey _coinBalanceKey = GlobalKey();

  /// Active coin-burst overlay entry — removed after animation completes.
  OverlayEntry? _particleEntry;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(blackjackControllerProvider.notifier);
    // Reset session stats after the first frame — provider writes are not
    // allowed during initState (which runs during the widget-tree build phase).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sessionStatsProvider.notifier).reset();
    });
  }

  Future<void> _handleBack() async {
    final session = ref.read(sessionStatsProvider);
    if (session.handsPlayed == 0) {
      if (mounted) context.pop();
      return;
    }

    // Check / update personal best win streak.
    bool isNewPb = false;
    final prefs = ref.read(sharedPreferencesProvider).value;
    if (prefs != null) {
      final currentPb = prefs.getInt('pb_win_streak') ?? 0;
      if (session.bestWinStreak > currentPb) {
        isNewPb = true;
        await prefs.setInt('pb_win_streak', session.bestWinStreak);
      }
    }

    if (!mounted) return;
    AnalyticsService.instance.logGameEnd(
      handsPlayed: session.handsPlayed,
      coinsDelta: session.coinsNetThisSession,
      winRate: session.winRate,
    );
    AnalyticsService.instance.logSessionSummaryShown();
    final goHome = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SessionSummaryDialog(
        session: session,
        isNewPb: isNewPb,
      ),
    );

    if (!mounted) return;
    if (goHome == true) {
      context.pop();
    } else {
      // Play Again: reset session, stay on screen.
      ref.read(sessionStatsProvider.notifier).reset();
    }
  }

  @override
  void dispose() {
    _particleEntry?.remove();
    _particleEntry = null;
    // Stop any active counting session before leaving the screen.
    ref.read(countingSessionProvider.notifier).stopSession();
    _controller.reset();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      _precacheCardImages();
    }
  }

  void _precacheCardImages() {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = (kCardWidth  * dpr).ceil();
    final decodeH = (kCardHeight * dpr).ceil();
    for (final path in CardAssets.allPaths) {
      precacheImage(
        CardAssets.provider(path, decodeW: decodeW, decodeH: decodeH),
        context,
      );
    }
  }

  /// Spawns coin icons flying from the centre of the table to the coin-balance
  /// widget.  Only called when the player wins (coinDelta > 0).
  void _triggerCoinBurst(int coinDelta) {
    // Remove any lingering burst from a previous round.
    _particleEntry?.remove();
    _particleEntry = null;

    final targetBox =
        _coinBalanceKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null) return;

    final target = targetBox.localToGlobal(
      targetBox.size.center(Offset.zero),
    );
    final size = MediaQuery.sizeOf(context);
    final source = Offset(size.width * 0.45, size.height * 0.52);

    // Clamp particle count: more coins → more particles, capped at 8.
    final count = coinDelta.clamp(4, 8);

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => _CoinBurstWidget(source: source, target: target, count: count),
    );
    _particleEntry = entry;
    Overlay.of(context).insert(entry);

    // Auto-remove: 8 particles × 50 ms stagger + 600 ms flight + buffer.
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) {
        entry?.remove();
        if (_particleEntry == entry) _particleEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    RebuildCounter.increment('TableRoot');

    // Trigger coin burst once per win, after the XP result lands.
    // ref.listen fires only when lastXpResult transitions null→non-null,
    // which happens exactly once per round-end in _syncState().
    ref.listen<XpResult?>(
      blackjackControllerProvider.select((s) => s.lastXpResult),
      (prev, next) {
        if (prev == null && next != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final s = ref.read(blackjackControllerProvider);
            final delta = s.lastRoundPayout ?? 0;
            if (delta > 0) _triggerCoinBurst(delta);
          });
        }
      },
    );

    // Reshuffle toast: fired when counting session resets the shoe.
    ref.listen<bool>(
      countingSessionProvider.select((s) => s.showReshuffleToast),
      (prev, next) {
        if (next && context.mounted) {
          ref.read(countingSessionProvider.notifier).clearReshuffleToast();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Shoe reshuffled — count reset to 0',
                style: AppTheme.bodyStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              backgroundColor: AppTheme.casinoGold,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: TableBackground(
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top HUD: title + bankroll ────────────────────────────
                _HudBar(coinBalanceKey: _coinBalanceKey, onBack: _handleBack),
                // ── XP progress bar ──────────────────────────────────────
                const _XpBar(),
                // ── Weekly goal progress ──────────────────────────────────
                const _WeeklyGoalRow(),
                // ── Counting session RC/TC badge (only when active) ───────
                const _CountingBadge(),
                // ── Daily challenges strip ────────────────────────────────
                const _DailyChallengesStrip(),
                // ── Game area + side bet panel ───────────────────────────
                const Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _TableBody()),
                      _BetPanel(),
                    ],
                  ),
                ),
                // ── Bottom action bar ────────────────────────────────────
                const _ActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HUD – title left, bankroll + decision assist right.
// ---------------------------------------------------------------------------
class _HudBar extends ConsumerWidget {
  /// Key forwarded to CoinBalance so the coin-burst animation can locate it.
  final GlobalKey coinBalanceKey;
  final VoidCallback onBack;

  const _HudBar({required this.coinBalanceKey, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _kHudPadH,
        vertical: _kHudPadV,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Back button + title ─────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  ref.read(audioServiceProvider.notifier)
                      .playSfx(SfxType.click);
                  onBack();
                },
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppTheme.casinoGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'BLACKJACK',
                style: AppTheme.displayStyle(
                  fontSize: 22,
                  shadows: AppTheme.goldGlow,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _RankDisplay(),
              const SizedBox(width: 8),
              CoinBalance(key: coinBalanceKey),
              const SizedBox(width: 10),
              const _CountingSessionToggle(),
              const SizedBox(width: 6),
              const _DecisionAssistToggle(),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XP progress bar — always visible, slim strip below the HUD.
// Animates fill on XP change; briefly glows gold on level-up.
// ---------------------------------------------------------------------------
class _XpBar extends ConsumerStatefulWidget {
  const _XpBar();

  @override
  ConsumerState<_XpBar> createState() => _XpBarState();
}

class _XpBarState extends ConsumerState<_XpBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Two independent listeners on the same provider:
    //
    // 1. Glow: fires as soon as the level number increases (first state update
    //    in awardXP — fast visual feedback on the XP bar).
    //
    // 2. Toast: fires only when pendingLevelUpInfo transitions null → non-null
    //    (second state update in awardXP, after addCoins has run).
    //    This guarantees info.totalCoins matches the actual coins awarded.
    ref.listen<AsyncValue<dynamic>>(progressionControllerProvider,
        (prev, next) {
      // --- Glow ---
      final prevLvl = prev?.valueOrNull?.level as int?;
      final nextLvl = next.valueOrNull?.level as int?;
      if (prevLvl != null && nextLvl != null && nextLvl > prevLvl) {
        _glowCtrl.forward(from: 0);
      }

      // --- Toast: triggered ONLY when pendingLevelUpInfo becomes non-null ---
      // (this fires on the second state emission in awardXP, after coins are
      //  actually awarded, so info.totalCoins == the real delta)
      final prevInfo = prev?.valueOrNull?.pendingLevelUpInfo;
      final nextInfo = next.valueOrNull?.pendingLevelUpInfo;
      if (prevInfo == null && nextInfo != null && context.mounted) {
        final coins = nextInfo.totalCoins;
        final lvl = nextInfo.level;
        final extra = nextInfo.isMilestone ? '  🎉 Milestone!' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'LEVEL UP!  LV $lvl  +${coins}c$extra',
              style: AppTheme.bodyStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: AppTheme.casinoGold,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 80),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
        // Clear so the toast cannot re-fire on the next rebuild.
        ref.read(progressionControllerProvider.notifier).clearLevelUp();
      }
    });

    final progression = ref.watch(
      progressionControllerProvider.select((s) => s.valueOrNull),
    );

    if (progression == null) return const SizedBox(height: 6);

    final progress = progression.levelProgress;
    final xpIn = progression.xpInCurrentLevel;
    final xpNeeded = progression.xpNeededForCurrentLevel;
    final level = progression.level;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Level badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.casinoGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.casinoGold.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'LV $level',
                  style: AppTheme.displayStyle(
                    fontSize: 11,
                    color: AppTheme.casinoGold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Animated progress bar
              Expanded(
                child: AnimatedBuilder(
                  animation: _glowAnim,
                  builder: (context, child) {
                    final glow = _glowAnim.value;
                    return Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: glow > 0
                            ? [
                                BoxShadow(
                                  color: AppTheme.casinoGold.withValues(
                                      alpha: 0.6 * glow),
                                  blurRadius: 8 * glow,
                                  spreadRadius: 1 * glow,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress.clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          builder: (context, value, _) {
                            return FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.casinoGold.withValues(alpha: 0.8),
                                      AppTheme.casinoGold,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // XP numbers
              Text(
                '$xpIn / $xpNeeded XP',
                style: AppTheme.bodyStyle(
                  fontSize: 10,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          // Next-reward motivation: subtle caption below the bar.
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '+${levelUpCoins(level + 1)}c at LV${level + 1}',
              style: AppTheme.bodyStyle(fontSize: 9, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Table body – dealer / banner / player, centered with explicit gaps.
// ---------------------------------------------------------------------------
class _TableBody extends StatelessWidget {
  const _TableBody();

  @override
  Widget build(BuildContext context) {
    // crossAxisAlignment: stretch so _PlayerHandView fills the available width,
    // enabling the split Row+Expanded layout. Dealer/banner are individually
    // centred via their own Center/Column(crossAxisAlignment.center) wrappers.
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Dealer section ────────────────────────────────────────────────
        _DealerHandView(),
        SizedBox(height: _kSectionGap),
        // ── Outcome banner in a fixed-height slot so the layout never jumps
        SizedBox(height: _kBannerH, child: _ResultBannerView()),
        SizedBox(height: _kSectionGap),
        // ── Player section ────────────────────────────────────────────────
        _PlayerHandView(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hand-state helpers shared by the two animated hand views.
// ---------------------------------------------------------------------------
bool _isTerminalState(GameState s) =>
    s != GameState.idle &&
    s != GameState.playerTurn &&
    s != GameState.dealerTurn;

bool _isPlayerWinState(GameState s) =>
    s == GameState.playerWin ||
    s == GameState.dealerBust ||
    s == GameState.playerBlackjack;

bool _isDealerWinState(GameState s) =>
    s == GameState.dealerWin || s == GameState.playerBust;

// ---------------------------------------------------------------------------
// Dealer hand – rebuilds only when dealer cards or game state changes.
// ---------------------------------------------------------------------------
class _DealerHandView extends ConsumerStatefulWidget {
  const _DealerHandView();

  @override
  ConsumerState<_DealerHandView> createState() => _DealerHandViewState();
}

class _DealerHandViewState extends ConsumerState<_DealerHandView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hlCtrl;
  late final Animation<double> _hlAnim;

  @override
  void initState() {
    super.initState();
    _hlCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _hlAnim = CurvedAnimation(parent: _hlCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    RebuildCounter.increment('HandArea(dealer)');

    // Drive the highlight animation on terminal-state transitions.
    ref.listen<GameState>(
      blackjackControllerProvider.select((s) => s.gameState),
      (prev, next) {
        if (prev == null) return;
        if (!_isTerminalState(prev) && _isTerminalState(next)) {
          _hlCtrl.forward(from: 0);
        } else if (!_isTerminalState(next)) {
          _hlCtrl.reset();
        }
      },
    );

    final dealerCards = ref.watch(
      blackjackControllerProvider.select((s) => s.dealerCards),
    );
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );

    final hideSecondCard =
        gameState == GameState.playerTurn && dealerCards.length >= 2;
    String totalDisplay = '—';
    if (dealerCards.isNotEmpty && !hideSecondCard) {
      final eval = HandEvaluator.evaluate(dealerCards);
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
    }

    // Winning hand: per-card glow/pop via CardHighlight.win.
    // Losing hand: container dims to 85 % opacity.
    final highlight = _isDealerWinState(gameState)
        ? CardHighlight.win
        : CardHighlight.none;
    final isDim = _isPlayerWinState(gameState);

    return AnimatedBuilder(
      animation: _hlAnim,
      // child is cached — not rebuilt on each animation frame.
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DEALER',
              style: AppTheme.displayStyle(
                fontSize: 20,
                shadows: AppTheme.goldGlow,
              ),
            ),
            SizedBox(height: _kCardLabelGap),
            if (dealerCards.isNotEmpty)
              Center(
                child: CardRow(
                  cards: dealerCards,
                  hideLast: hideSecondCard,
                  // 100 ms offset creates the P→D→P→D deal interleave.
                  dealOffset: const Duration(milliseconds: 100),
                  highlight: highlight,
                ),
              )
            else
              SizedBox(height: kCardHeight),
            SizedBox(height: _kTotalLabelGap),
            if (!hideSecondCard)
              Text(
                totalDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
          ],
        ),
      ),
      builder: (_, cached) {
        // Win glow is per-card (handled by CardRow/CardHighlight).
        // Only apply container-level opacity for the losing hand.
        if (isDim) {
          return Opacity(opacity: 1.0 - 0.15 * _hlAnim.value, child: cached!);
        }
        return cached!;
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Player hand – rebuilds only when player cards change.
// Switches to split layout (two side-by-side panels) when hasSplit is true.
// ---------------------------------------------------------------------------
class _PlayerHandView extends ConsumerStatefulWidget {
  const _PlayerHandView();

  @override
  ConsumerState<_PlayerHandView> createState() => _PlayerHandViewState();
}

class _PlayerHandViewState extends ConsumerState<_PlayerHandView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hlCtrl;
  late final Animation<double> _hlAnim;

  @override
  void initState() {
    super.initState();
    _hlCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _hlAnim = CurvedAnimation(parent: _hlCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _hlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    RebuildCounter.increment('HandArea(player)');

    // Drive the highlight animation on terminal-state transitions.
    ref.listen<GameState>(
      blackjackControllerProvider.select((s) => s.gameState),
      (prev, next) {
        if (prev == null) return;
        if (!_isTerminalState(prev) && _isTerminalState(next)) {
          _hlCtrl.forward(from: 0);
        } else if (!_isTerminalState(next)) {
          _hlCtrl.reset();
        }
      },
    );

    final hasSplit = ref.watch(
      blackjackControllerProvider.select((s) => s.hasSplit),
    );

    // AnimatedSwitcher fades smoothly between 1-hand and 2-hand layouts.
    // Keys on each child tell the switcher they are distinct subtrees.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: hasSplit ? _buildSplitView() : _buildSingleHand(),
    );
  }

  Widget _buildSingleHand() {
    final playerCards = ref.watch(
      blackjackControllerProvider.select((s) => s.playerCards),
    );
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );

    String totalDisplay = '—';
    if (playerCards.isNotEmpty) {
      final eval = HandEvaluator.evaluate(playerCards);
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
      if (eval.isBlackjack) {
        totalDisplay += ' - BLACKJACK!';
      }
    }

    final highlight = _isPlayerWinState(gameState)
        ? CardHighlight.win
        : CardHighlight.none;
    final isDim = _isDealerWinState(gameState);

    // key: distinguishes this widget from _buildSplitView for AnimatedSwitcher.
    return AnimatedBuilder(
      key: const ValueKey('player-single'),
      animation: _hlAnim,
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              totalDisplay,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: _kTotalLabelGap),
            if (playerCards.isNotEmpty)
              CardRow(cards: playerCards, highlight: highlight)
            else
              SizedBox(height: kCardHeight),
            SizedBox(height: _kCardLabelGap),
            Text(
              'YOUR HAND',
              style: AppTheme.displayStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      builder: (_, cached) {
        // Centered horizontally — single hand uses the full table width.
        final inner = isDim
            ? Opacity(opacity: 1.0 - 0.15 * _hlAnim.value, child: cached!)
            : cached!;
        return Center(child: inner);
      },
    );
  }

  Widget _buildSplitView() {
    final allHands = ref.watch(
      blackjackControllerProvider.select((s) => s.allPlayerHands),
    );
    final activeIdx = ref.watch(
      blackjackControllerProvider.select((s) => s.activeHandIndex),
    );
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );
    final handOutcomes = ref.watch(
      blackjackControllerProvider.select((s) => s.handOutcomes),
    );

    final isOver = _isTerminalState(gameState);

    // key: distinguishes this widget from _buildSingleHand for AnimatedSwitcher.
    return AnimatedBuilder(
      key: const ValueKey('player-split'),
      animation: _hlAnim,
      builder: (_, __) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row+Expanded gives each panel a bounded, equal-width slot.
            // SingleChildScrollView inside each CardRow handles card overflow.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < allHands.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _SplitHandPanel(
                      label: 'HAND ${i + 1}',
                      cards: allHands[i],
                      isActive: !isOver && activeIdx == i,
                      outcome: isOver && handOutcomes != null && i < handOutcomes.length
                          ? handOutcomes[i]
                          : null,
                      hlValue: _hlAnim.value,
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: _kCardLabelGap),
            Text(
              'YOUR HANDS',
              style: AppTheme.displayStyle(fontSize: 16),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single panel for one split hand — bounded slot, animated active highlight.
//
// Layout guarantee: Expanded in the parent Row gives this widget a bounded
// width. CardRow uses SingleChildScrollView so cards never cause overflow.
// ---------------------------------------------------------------------------
class _SplitHandPanel extends StatelessWidget {
  final String label;
  final List<dynamic> cards; // List<Card> from engine
  final bool isActive;
  final GameState? outcome;
  final double hlValue;

  const _SplitHandPanel({
    required this.label,
    required this.cards,
    required this.isActive,
    required this.outcome,
    required this.hlValue,
  });

  @override
  Widget build(BuildContext context) {
    String totalDisplay = '—';
    if (cards.isNotEmpty) {
      final eval = HandEvaluator.evaluate(cards.cast());
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
    }

    final isWin  = outcome != null && _isPlayerWinState(outcome!);
    final isLose = outcome != null && _isDealerWinState(outcome!);
    final highlight = isWin ? CardHighlight.win : CardHighlight.none;

    // Opacity: dim loser after game ends; dim inactive hand during play.
    final opacity = isLose
        ? (1.0 - 0.15 * hlValue).clamp(0.0, 1.0)
        : (!isActive && outcome == null)
            ? 0.85
            : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: opacity,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isActive ? 1.02 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // "HAND 1" / "HAND 2" label above the slot — highlighted when active.
            Text(
              label,
              style: AppTheme.displayStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: isActive ? AppTheme.casinoGold : Colors.white38,
              ),
            ),
            const SizedBox(height: 4),
            // Slot: animated gold border + glow when active.
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: isActive
                    ? Border.all(color: AppTheme.casinoGold, width: 1.5)
                    : Border.all(color: Colors.white10, width: 1.0),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.casinoGold.withValues(alpha: 0.25),
                          blurRadius: 12,
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    totalDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (cards.isNotEmpty)
                    ClipRect(
                      child: CardRow(
                        cards: cards.cast(),
                        highlight: highlight,
                        cardScale: kSplitCardScale,
                      ),
                    )
                  else
                    SizedBox(height: kCardHeight * kSplitCardScale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result banner – animates in with fade + upward slide on each new result.
// Rendered inside a fixed-height SizedBox slot so the surrounding layout
// never shifts when the banner appears or disappears.
// ---------------------------------------------------------------------------
class _ResultBannerView extends ConsumerStatefulWidget {
  const _ResultBannerView();

  @override
  ConsumerState<_ResultBannerView> createState() => _ResultBannerViewState();
}

class _ResultBannerViewState extends ConsumerState<_ResultBannerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  /// Cached message so we keep rendering the pill while it fades out.
  String? _activeMessage;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _fade  = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen fires on every resultMessage change — drive animation from here.
    ref.listen<String?>(
      blackjackControllerProvider.select((s) => s.resultMessage),
      (_, next) {
        if (next != null) {
          _activeMessage = next;
          _ctrl.forward(from: 0);
        } else {
          _activeMessage = null;
          _ctrl.reset();
        }
      },
    );

    // Also watch so this widget rebuilds when the message first arrives
    // (the listener above does not trigger a rebuild on its own).
    final resultMessage = ref.watch(
      blackjackControllerProvider.select((s) => s.resultMessage),
    );

    final message = resultMessage ?? _activeMessage;
    if (message == null) return const SizedBox.shrink();

    final isWin = message.toLowerCase().contains('win') ||
        message.toLowerCase().contains('blackjack');
    const winColor  = Color(0xFF1B7A35);
    const loseColor = Color(0xFF991B22);

    return Center(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: isWin ? winColor : loseColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTheme.displayStyle(
                  fontSize: 22,
                  color: Colors.white,
                  shadows: isWin ? AppTheme.neonGlow : AppTheme.goldGlow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bet Panel – always-visible side panel docked to the right.
// Interactive only when not in active play (playerTurn / dealerTurn).
// ---------------------------------------------------------------------------
class _BetPanel extends ConsumerWidget {
  const _BetPanel();

  static const double _kWidth = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBet = ref.watch(
      blackjackControllerProvider.select((s) => s.currentBet),
    );
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );
    final isActionLocked = ref.watch(
      blackjackControllerProvider.select((s) => s.isActionLocked),
    );
    final coins = ref.watch(economyControllerProvider).valueOrNull?.coins ?? 0;
    final controller = ref.read(blackjackControllerProvider.notifier);

    final isActivePlay = gameState == GameState.playerTurn ||
        gameState == GameState.dealerTurn;
    final canChange = !isActionLocked && !isActivePlay;

    final snapPoints = generateSnapPoints(coins);
    if (snapPoints.isEmpty) {
      return const SizedBox(width: _kWidth);
    }

    // Slider index: last point that is <= currentBet
    int sliderIdx = snapPoints.lastIndexWhere((p) => p <= currentBet);
    if (sliderIdx == -1) sliderIdx = 0;

    // Tiny preset chips: pick up to 3 spread across the range
    final presets = _buildPresets(snapPoints);

    return Opacity(
      opacity: canChange ? 1.0 : 0.52,
      child: Container(
        width: _kWidth,
        margin: const EdgeInsets.only(right: 8, top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canChange
                ? AppTheme.casinoGold.withValues(alpha: 0.35)
                : Colors.white12,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            // BET label
            Text(
              'BET',
              style: AppTheme.displayStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 2),
            // Current bet amount
            Text(
              '$currentBet',
              style: AppTheme.bodyStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.casinoGold,
              ),
            ),
            // Lock icon when inactive
            if (!canChange) ...[
              const SizedBox(height: 2),
              const Icon(Icons.lock_outline, size: 11, color: Colors.white30),
            ],
            const SizedBox(height: 8),
            // Vertical snap slider
            if (snapPoints.length > 1)
              Expanded(
                child: _SnapSlider(
                  snapPoints: snapPoints,
                  currentIndex: sliderIdx,
                  enabled: canChange,
                  onChanged: (idx) => controller.setBet(snapPoints[idx]),
                ),
              )
            else
              const Expanded(child: SizedBox.shrink()),
            const SizedBox(height: 8),
            // Quick preset chips
            for (final p in presets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _TinyChip(
                  amount: p,
                  selected: currentBet == p,
                  onTap: canChange ? () => controller.setBet(p) : null,
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  /// Pick up to 3 representative presets spread across [snapPoints].
  List<int> _buildPresets(List<int> snapPoints) {
    if (snapPoints.length <= 3) return snapPoints;
    // Pick first, middle, and last
    final mid = snapPoints[snapPoints.length ~/ 2];
    return [snapPoints.first, mid, snapPoints.last];
  }
}

// ---------------------------------------------------------------------------
// Vertical snap slider – a RotatedBox wrapping a themed Slider.
// Uses LayoutBuilder to give the Slider the correct track length.
// ---------------------------------------------------------------------------
class _SnapSlider extends StatelessWidget {
  final List<int> snapPoints;
  final int currentIndex;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _SnapSlider({
    required this.snapPoints,
    required this.currentIndex,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RotatedBox(
          quarterTurns: 3, // 270° → bottom of panel = low bet, top = high
          child: SizedBox(
            width: constraints.maxHeight,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppTheme.casinoGold,
                inactiveTrackColor: Colors.white12,
                thumbColor: enabled ? AppTheme.casinoGold : Colors.white38,
                overlayColor: AppTheme.casinoGold.withValues(alpha: 0.2),
                disabledThumbColor: Colors.white38,
                disabledActiveTrackColor: Colors.white24,
                disabledInactiveTrackColor: Colors.white12,
              ),
              child: Slider(
                value: currentIndex.toDouble(),
                min: 0,
                max: (snapPoints.length - 1).toDouble(),
                divisions: snapPoints.length - 1,
                onChanged: enabled ? (v) => onChanged(v.round()) : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tiny preset chip button inside the bet panel.
// ---------------------------------------------------------------------------
class _TinyChip extends StatelessWidget {
  final int amount;
  final bool selected;
  final VoidCallback? onTap;

  const _TinyChip({
    required this.amount,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 22,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.casinoGold
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? AppTheme.casinoGold : Colors.white24,
          ),
        ),
        child: Center(
          child: Text(
            '$amount',
            style: AppTheme.bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.black : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// XP earned chip — shown after a hand ends, displays the XP breakdown.
// Disappears automatically when the table auto-resets or a new round starts.
// ---------------------------------------------------------------------------
class _XpEarnedChip extends ConsumerWidget {
  const _XpEarnedChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xpResult = ref.watch(
      blackjackControllerProvider.select((s) => s.lastXpResult),
    );
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );

    final isActivePlay = gameState == GameState.playerTurn ||
        gameState == GameState.dealerTurn;

    if (xpResult == null || isActivePlay) return const SizedBox.shrink();

    // Build a compact breakdown label from non-zero bonus components.
    final parts = <String>[];
    if (xpResult.winBonus > 0) parts.add('Win');
    if (xpResult.bjBonus > 0) parts.add('BJ');
    if (xpResult.betBonus > 0) parts.add('Bet');
    final sub = parts.isEmpty ? 'Base' : parts.join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.casinoGold, size: 14),
          const SizedBox(width: 4),
          Text(
            '+${xpResult.total} XP',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.casinoGold,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($sub)',
            style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared button style for player-turn action buttons (HIT / STAND / DOUBLE /
// SPLIT).  Fixed height, minimal horizontal padding, consistent font, and
// a dimmed disabled state that preserves the button's colour identity.
// ---------------------------------------------------------------------------
ButtonStyle _actionButtonStyle(Color bg) => ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      disabledBackgroundColor: bg.withValues(alpha: 0.28),
      disabledForegroundColor: Colors.white30,
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );

// ---------------------------------------------------------------------------
// Action buttons – rebuilds when game state, lock state, or bet changes.
// ---------------------------------------------------------------------------
class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    RebuildCounter.increment('ControlsBar');
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );
    final isActionLocked = ref.watch(
      blackjackControllerProvider.select((s) => s.isActionLocked),
    );
    final currentBet = ref.watch(
      blackjackControllerProvider.select((s) => s.currentBet),
    );
    final winRates = ref.watch(
      blackjackControllerProvider.select((s) => s.winRates),
    );
    final showAssist = ref.watch(
      blackjackControllerProvider.select((s) => s.showDecisionAssist),
    );
    final canDouble = ref.watch(
      blackjackControllerProvider.select((s) => s.canDouble),
    );
    final canSplit = ref.watch(
      blackjackControllerProvider.select((s) => s.canSplit),
    );
    final economyState = ref.watch(economyControllerProvider).valueOrNull;
    final coins = economyState?.coins ?? 0;
    final removeAds = economyState?.removeAds ?? false;
    final adState = ref.watch(adNotifierProvider);
    final controller = ref.read(blackjackControllerProvider.notifier);

    final isPlayerTurn = gameState == GameState.playerTurn;
    final isActivePlay = isPlayerTurn || gameState == GameState.dealerTurn;
    final canStartNewRound =
        !isActionLocked && !isActivePlay && coins >= currentBet;

    // Can only double/split if enough coins for the extra bet.
    final canAffordExtra = coins >= currentBet;

    // Debug: report any condition that is silently blocking the DEAL button.
    if (kDebugMode && !canStartNewRound && !isActivePlay) {
      debugPrint(
        '[ActionBar] DEAL disabled – '
        'isActionLocked=$isActionLocked  '
        'gameState=$gameState  '
        'coins=$coins  bet=$currentBet',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kActionPadH,
        vertical: _kActionPadV,
      ),
      color: Theme.of(context).extension<TableThemeTokens>()?.darkFelt ?? AppTheme.darkFelt,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlayerTurn && showAssist && winRates != null)
            _WinRateRow(winRates: winRates),
          const _XpEarnedChip(),
          const _SessionMiniStrip(),
          if (isPlayerTurn) ...[
            // All 4 buttons are always in the layout — DOUBLE and SPLIT are
            // disabled (not hidden) when unavailable, so the bar never reflows.
            Row(
              children: [
                // HIT
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: isActionLocked
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.hit();
                            },
                      style: _actionButtonStyle(Colors.green),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('HIT', maxLines: 1),
                      ),
                    ),
                  ),
                ),
                // STAND
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: isActionLocked
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.stand();
                            },
                      style: _actionButtonStyle(AppTheme.chipRed),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('STAND', maxLines: 1),
                      ),
                    ),
                  ),
                ),
                // DOUBLE — always present; disabled when not allowed
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: (isActionLocked || !canDouble || !canAffordExtra)
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.doubleDown();
                            },
                      style: _actionButtonStyle(const Color(0xFF1A6B8A)),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('DOUBLE', maxLines: 1),
                      ),
                    ),
                  ),
                ),
                // SPLIT — always present; disabled when not allowed
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: (isActionLocked || !canSplit || !canAffordExtra)
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.split();
                            },
                      style: _actionButtonStyle(const Color(0xFF6B3FA0)),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('SPLIT', maxLines: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Out of coins: offer a revive ad or a hint.
                      if (!isActivePlay && coins == 0) ...[
                        if (adState.isReady &&
                            !removeAds &&
                            adState.remainingRevives > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.play_circle_outline,
                                  size: 16),
                              label: Text(
                                'Watch Ad — Get '
                                '${RetentionConfig.kReviveAdRewardCoins} Coins',
                              ),
                              onPressed: () => _handleReviveAd(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 42),
                                textStyle: AppTheme.bodyStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              adState.remainingRevives <= 0
                                  ? 'No revives left today'
                                  : 'Visit the Store for more coins',
                              style: AppTheme.bodyStyle(
                                fontSize: 11,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                      ],
                      // Subtle hint when coins < bet (and > 0)
                      if (!isActivePlay && coins < currentBet && coins > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Lower bet to continue',
                            style: AppTheme.bodyStyle(
                              fontSize: 11,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ElevatedButton(
                          onPressed: canStartNewRound
                              ? () {
                                  debugPrint('[Perf] instrumentation alive – deal_pressed');
                                  RebuildCounter.printAndReset('deal_pressed');
                                  FramePerfMonitor.printAndReset('deal_pressed');
                                  ref.read(audioServiceProvider.notifier)
                                      .playSfx(SfxType.click);
                                  controller.startNewRound();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.casinoGold,
                            foregroundColor: const Color(0xFF1A1000),
                            minimumSize: const Size(0, 48),
                            elevation: 10,
                            shadowColor: Colors.black87,
                            textStyle: AppTheme.bodyStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                            ),
                          ),
                          child: const Text('DEAL'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _handleReviveAd(BuildContext context, WidgetRef ref) async {
    await ref.read(adNotifierProvider.notifier).showReviveAd(
      onReward: (_) {
        ref
            .read(economyControllerProvider.notifier)
            .addCoins(RetentionConfig.kReviveAdRewardCoins);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Revived! +${RetentionConfig.kReviveAdRewardCoins} coins'),
              backgroundColor: Colors.green.shade700,
            ),
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Decision Assist toggle — lightbulb icon in HUD; toggles Win% computation.
// ---------------------------------------------------------------------------
class _DecisionAssistToggle extends ConsumerWidget {
  const _DecisionAssistToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      blackjackControllerProvider.select((s) => s.showDecisionAssist),
    );
    final controller = ref.read(blackjackControllerProvider.notifier);
    return GestureDetector(
      onTap: controller.toggleDecisionAssist,
      child: Icon(
        active ? Icons.lightbulb : Icons.lightbulb_outline,
        color: active ? AppTheme.casinoGold : Colors.white38,
        size: 20,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Win-rate bar — shown above HIT/STAND when simulation result is available.
// ---------------------------------------------------------------------------
class _WinRateRow extends StatelessWidget {
  final WinRateResult winRates;
  const _WinRateRow({required this.winRates});

  @override
  Widget build(BuildContext context) {
    final hitPct  = (winRates.hitWinRate  * 100).round();
    final standPct = (winRates.standWinRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _WinRateChip(label: 'Hit', percent: hitPct),
          _WinRateChip(label: 'Stand', percent: standPct),
        ],
      ),
    );
  }
}

class _WinRateChip extends StatelessWidget {
  final String label;
  final int percent;
  const _WinRateChip({required this.label, required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 50 ? const Color(0xFF1B7A35) : Colors.white30;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54),
        ),
        Text(
          '$percent%',
          style: AppTheme.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Session Mini Strip — compact "🔥 3 streak  •  Win 65%" shown in action bar.
// Only visible once at least 1 hand has been played this session.
// ---------------------------------------------------------------------------
class _SessionMiniStrip extends ConsumerWidget {
  const _SessionMiniStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionStatsProvider);
    if (session.handsPlayed == 0) return const SizedBox.shrink();

    final winPct = session.winRate.round();
    final streak = session.currentWinStreak;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (streak > 0) ...[
            const Icon(Icons.local_fire_department,
                size: 12, color: AppTheme.casinoGold),
            const SizedBox(width: 2),
            Text(
              '$streak streak',
              style: AppTheme.bodyStyle(
                fontSize: 11,
                color: AppTheme.casinoGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '  •  ',
              style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white24),
            ),
          ],
          Text(
            'Win $winPct%',
            style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session Summary Dialog — shown when the player taps back after playing.
// ---------------------------------------------------------------------------
class _SessionSummaryDialog extends StatelessWidget {
  final SessionStats session;
  final bool isNewPb;

  const _SessionSummaryDialog({
    required this.session,
    required this.isNewPb,
  });

  @override
  Widget build(BuildContext context) {
    final winPct = session.winRate.round();
    final net = session.coinsNetThisSession;
    final netSign = net >= 0 ? '+' : '';
    final netColor = net >= 0 ? AppTheme.casinoGold : AppTheme.chipRed;
    final tokens = Theme.of(context).extension<TableThemeTokens>();

    return Dialog(
      backgroundColor: tokens?.darkFelt ?? const Color(0xFF0D2B1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SESSION SUMMARY',
              textAlign: TextAlign.center,
              style: AppTheme.displayStyle(
                fontSize: 22,
                shadows: AppTheme.goldGlow,
              ),
            ),
            if (isNewPb) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.casinoGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.casinoGold.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '★  New Personal Best!',
                  textAlign: TextAlign.center,
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.casinoGold,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _SummaryRow('Hands played', '${session.handsPlayed}'),
            _SummaryRow(
              'Wins / Losses / Pushes',
              '${session.handsWon} / ${session.handsLost} / ${session.handsPushed}',
            ),
            _SummaryRow('Win rate', '$winPct%'),
            _SummaryRow(
              'Net coins',
              '$netSign$net',
              valueColor: netColor,
            ),
            _SummaryRow('XP earned', '+${session.xpEarnedThisSession}'),
            _SummaryRow('Best win streak', '${session.bestWinStreak}'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casinoGold,
                foregroundColor: const Color(0xFF1A1000),
                minimumSize: const Size(0, 44),
                textStyle: AppTheme.bodyStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              child: const Text('PLAY AGAIN'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                minimumSize: const Size(0, 44),
                textStyle: AppTheme.bodyStyle(fontSize: 14),
              ),
              child: const Text('BACK TO HOME'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
          ),
          Text(
            value,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Goal Row — thin strip below the XP bar showing weekly hand progress.
// Tapping "CLAIM" when the goal is complete opens a reward dialog.
// ---------------------------------------------------------------------------
class _WeeklyGoalRow extends ConsumerWidget {
  const _WeeklyGoalRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(
      weeklyGoalControllerProvider.select((s) => s.valueOrNull),
    );
    if (goal == null) return const SizedBox.shrink();

    final hands = goal.handsThisWeek;
    final target = RetentionConfig.kWeeklyHandTarget;
    final progress = goal.progress;
    final canClaim = goal.canClaim;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          Text(
            '🎯 Week: $hands / $target',
            style: AppTheme.bodyStyle(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  Container(height: 3, color: Colors.white10),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 3,
                      color: canClaim
                          ? AppTheme.casinoGold
                          : AppTheme.casinoGold.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (canClaim) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showClaimDialog(context, ref),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.casinoGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'CLAIM',
                  style: AppTheme.bodyStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showClaimDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _WeeklyGoalClaimDialog(
        onClaim: () {
          ref.read(weeklyGoalControllerProvider.notifier).claimReward();
          Navigator.of(context, rootNavigator: true).pop();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly Goal Claim Dialog
// ---------------------------------------------------------------------------
class _WeeklyGoalClaimDialog extends StatelessWidget {
  const _WeeklyGoalClaimDialog({required this.onClaim});

  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D2B1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🎯 WEEKLY GOAL',
              style: AppTheme.displayStyle(
                fontSize: 24,
                shadows: AppTheme.goldGlow,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${RetentionConfig.kWeeklyHandTarget} hands played',
              style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
            ),
            const SizedBox(height: 20),
            Text(
              '+${RetentionConfig.kWeeklyRewardCoins}',
              style: AppTheme.displayStyle(
                fontSize: 48,
                color: AppTheme.casinoGold,
                shadows: AppTheme.goldGlow,
              ),
            ),
            Text(
              'COINS  +${RetentionConfig.kWeeklyRewardXP} XP',
              style: AppTheme.displayStyle(
                fontSize: 14,
                color: AppTheme.casinoGold.withValues(alpha: 0.7),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClaim,
                child: const Text('CLAIM'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CoinBurstWidget — [count] coin icons fly from [source] to [target].
//
// Rendered via OverlayEntry (full-screen, IgnorePointer).
// Each particle is staggered by 50 ms and uses easeIn to accelerate toward
// the coin-balance HUD.  Scales down and fades out on arrival.
// ---------------------------------------------------------------------------
class _CoinBurstWidget extends StatefulWidget {
  final Offset source;
  final Offset target;
  final int count;

  const _CoinBurstWidget({
    required this.source,
    required this.target,
    required this.count,
  });

  @override
  State<_CoinBurstWidget> createState() => _CoinBurstWidgetState();
}

class _CoinBurstWidgetState extends State<_CoinBurstWidget>
    with TickerProviderStateMixin {
  final List<AnimationController> _ctrls = [];
  final List<Animation<double>> _anims = [];
  // Fixed random spread so offsets are stable across frames.
  late final List<Offset> _offsets;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _offsets = List.generate(
      widget.count,
      (_) => Offset(
        (rng.nextDouble() - 0.5) * 44,
        (rng.nextDouble() - 0.5) * 44,
      ),
    );

    for (int i = 0; i < widget.count; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 580),
      );
      _ctrls.add(ctrl);
      _anims.add(
        CurvedAnimation(parent: ctrl, curve: Curves.easeIn),
      );
      final t = Timer(Duration(milliseconds: i * 50), () {
        if (mounted) ctrl.forward();
      });
      _timers.add(t);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) { t.cancel(); }
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            for (int i = 0; i < _ctrls.length; i++)
              AnimatedBuilder(
                animation: _anims[i],
                builder: (_, __) {
                  final t = _anims[i].value; // 0→1, easeIn
                  // Source has a random spread; coin converges to exact target.
                  final sx = widget.source.dx + _offsets[i].dx;
                  final sy = widget.source.dy + _offsets[i].dy;
                  final x  = sx + (widget.target.dx - sx) * t;
                  final y  = sy + (widget.target.dy - sy) * t;
                  // Fade out in the last 20 % of flight; shrink as it arrives.
                  final opacity = t > 0.8 ? (1.0 - t) / 0.2 : 1.0;
                  final scale   = 1.0 - t * 0.55;

                  return Positioned(
                    left: x - 9,
                    top:  y - 9,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale.clamp(0.1, 1.0),
                        child: const Icon(
                          Icons.monetization_on_rounded,
                          color: Color(0xFFFFD700),
                          size: 18,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rank Display — compact tier label + thin progress bar shown in the HUD.
// Reads directly from ProgressionManager (ChangeNotifier) via ListenableBuilder.
// ---------------------------------------------------------------------------
class _RankDisplay extends StatelessWidget {
  const _RankDisplay();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProgressionManager.instance,
      builder: (_, __) {
        final pm = ProgressionManager.instance;
        if (!pm.isInitialized) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pm.getRankTier().toUpperCase(),
              style: AppTheme.bodyStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.casinoGold.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: 56,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: pm.getRankProgressPercent(),
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.casinoGold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Challenges Strip — compact tap-to-expand row shown below WeeklyGoal.
// ---------------------------------------------------------------------------
class _DailyChallengesStrip extends StatefulWidget {
  const _DailyChallengesStrip();

  @override
  State<_DailyChallengesStrip> createState() => _DailyChallengesStripState();
}

class _DailyChallengesStripState extends State<_DailyChallengesStrip> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProgressionManager.instance,
      builder: (_, __) {
        final pm = ProgressionManager.instance;
        if (!pm.isInitialized) return const SizedBox.shrink();
        final challenges = pm.todaysChallenges;
        final claimableCount = challenges
            .where((c) => pm.isDailyComplete(c.id) && !pm.isDailyClaimed(c.id))
            .length;
        return GestureDetector(
          onTap: () => _openSheet(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: claimableCount > 0
                    ? AppTheme.casinoGold.withValues(alpha: 0.7)
                    : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.task_alt,
                  size: 13,
                  color: claimableCount > 0
                      ? AppTheme.casinoGold
                      : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  "Today's Challenges",
                  style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white70),
                ),
                const Spacer(),
                ...challenges.map((c) => _buildDot(c, pm)),
                if (claimableCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.casinoGold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CLAIM',
                      style: AppTheme.bodyStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 15, color: Colors.white38),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDot(ChallengeDefinition c, ProgressionManager pm) {
    final claimed = pm.isDailyClaimed(c.id);
    final complete = pm.isDailyComplete(c.id);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: claimed
              ? AppTheme.casinoGold
              : complete
                  ? AppTheme.casinoGold.withValues(alpha: 0.45)
                  : Colors.white24,
          border: claimed ? null : Border.all(color: Colors.white24),
        ),
        child: claimed
            ? const Icon(Icons.check, size: 7, color: Colors.black)
            : null,
      ),
    );
  }

  void _openSheet(BuildContext context) {
    AnalyticsService.instance.logDailyChallengesOpen();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ChallengesBottomSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenges bottom sheet — 3 challenge cards with progress + claim button.
// ---------------------------------------------------------------------------
class _ChallengesBottomSheet extends ConsumerStatefulWidget {
  const _ChallengesBottomSheet();

  @override
  ConsumerState<_ChallengesBottomSheet> createState() =>
      _ChallengesBottomSheetState();
}

class _ChallengesBottomSheetState
    extends ConsumerState<_ChallengesBottomSheet> {
  bool _claiming = false;

  Future<void> _handleClaim(String id) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final reward = await ProgressionManager.instance.claimDaily(id);
      if (reward != null && mounted) {
        ref.read(economyControllerProvider.notifier).addCoins(reward.coins);
        ref.read(progressionControllerProvider.notifier).awardXP(reward.xp);
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ProgressionManager.instance,
      builder: (_, __) {
        final pm = ProgressionManager.instance;
        final challenges = pm.isInitialized ? pm.todaysChallenges : <ChallengeDefinition>[];
        final tokens = Theme.of(context).extension<TableThemeTokens>();
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            decoration: BoxDecoration(
              color: tokens?.darkFelt ?? const Color(0xFF0D4A25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.casinoGold.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    "TODAY'S CHALLENGES",
                    style: AppTheme.displayStyle(fontSize: 18),
                  ),
                ),
                ...challenges.map(
                  (c) => _ChallengeCard(
                    challenge: c,
                    progress: pm.getDailyProgress(c.id),
                    claimed: pm.isDailyClaimed(c.id),
                    claiming: _claiming,
                    onClaim: () => _handleClaim(c.id),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeDefinition challenge;
  final int progress;
  final bool claimed;
  final bool claiming;
  final VoidCallback onClaim;

  const _ChallengeCard({
    required this.challenge,
    required this.progress,
    required this.claimed,
    required this.claiming,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final complete = progress >= challenge.target;
    final pct = (progress / challenge.target).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: claimed
              ? AppTheme.casinoGold.withValues(alpha: 0.4)
              : complete
                  ? AppTheme.casinoGold.withValues(alpha: 0.4)
                  : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _categoryIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (claimed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.casinoGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppTheme.casinoGold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'CLAIMED',
                    style: AppTheme.bodyStyle(
                        fontSize: 9, color: AppTheme.casinoGold),
                  ),
                )
              else if (complete && !claiming)
                GestureDetector(
                  onTap: onClaim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.casinoGold,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CLAIM',
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                )
              else if (complete && claiming)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.casinoGold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.casinoGold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '$progress / ${challenge.target}',
                style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54),
              ),
              const Spacer(),
              const Icon(Icons.monetization_on, size: 12, color: AppTheme.casinoGold),
              const SizedBox(width: 3),
              Text(
                '+${challenge.rewardCoins}',
                style: AppTheme.bodyStyle(
                    fontSize: 11, color: AppTheme.casinoGold),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star, size: 12, color: AppTheme.neonCyan),
              const SizedBox(width: 3),
              Text(
                '+${challenge.rewardXp} XP',
                style: AppTheme.bodyStyle(
                    fontSize: 11, color: AppTheme.neonCyan),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryIcon() {
    final (icon, color) = switch (challenge.category) {
      ChallengeCategory.game    => (Icons.casino, AppTheme.casinoGold),
      ChallengeCategory.trainer => (Icons.school, AppTheme.neonCyan),
      ChallengeCategory.general => (Icons.stars, Colors.white70),
    };
    return Icon(icon, size: 16, color: color);
  }
}

// ---------------------------------------------------------------------------
// Counting Session Toggle — card-eye icon in HUD; starts/stops Hi-Lo session.
// ---------------------------------------------------------------------------
class _CountingSessionToggle extends ConsumerWidget {
  const _CountingSessionToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      countingSessionProvider.select((s) => s.sessionActive),
    );
    final controller = ref.read(blackjackControllerProvider.notifier);
    return GestureDetector(
      onTap: active
          ? controller.stopCountingSession
          : controller.startCountingSession,
      child: Icon(
        active ? Icons.style : Icons.style_outlined,
        color: active ? AppTheme.casinoGold : Colors.white38,
        size: 20,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Counting Badge — slim strip showing RC and TC when a session is active.
// ---------------------------------------------------------------------------
class _CountingBadge extends ConsumerWidget {
  const _CountingBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(countingSessionProvider);
    if (!session.sessionActive) return const SizedBox.shrink();

    final rc = session.runningCount;
    final tc = session.trueCountDisplay;
    final rcColor = rc > 0
        ? const Color(0xFF4CAF50)
        : rc < 0
            ? AppTheme.chipRed
            : Colors.white54;
    final tcColor = tc > 0
        ? const Color(0xFF4CAF50)
        : tc < 0
            ? AppTheme.chipRed
            : Colors.white54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CountChip(label: 'RC', value: rc, color: rcColor),
          const SizedBox(width: 16),
          _CountChip(label: 'TC', value: tc, color: tcColor),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CountChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sign = value > 0 ? '+' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: AppTheme.bodyStyle(fontSize: 10, color: Colors.white38),
        ),
        Text(
          '$sign$value',
          style: AppTheme.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
