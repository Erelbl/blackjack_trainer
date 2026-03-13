import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../engine/game/game_state.dart';
import '../../engine/simulation/win_rate_simulator.dart';
import '../../engine/utils/hand_evaluator.dart';
import '../play/widgets/card_assets.dart';
import '../play/widgets/card_row.dart';
import '../play/widgets/table_background.dart';
import '../store/models/table_theme_item.dart';
import '../../services/audio_service.dart';
import 'state/trainer_controller.dart';
import 'state/trainer_state.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
const double _kStatsPadV = 10.0;
const double _kSectionGap = 16.0;
const double _kResultH = 52.0;
const double _kFeedbackMinH = 80.0;
const double _kActionPadH = 16.0;
const double _kActionPadV = 10.0;
const double _kCardLabelGap = 10.0;
const double _kTotalLabelGap = 6.0;

// ---------------------------------------------------------------------------
// Root tab widget
// ---------------------------------------------------------------------------
class TrainerGameTab extends ConsumerStatefulWidget {
  const TrainerGameTab({super.key});

  @override
  ConsumerState<TrainerGameTab> createState() => _TrainerGameTabState();
}

class _TrainerGameTabState extends ConsumerState<TrainerGameTab> {
  bool _precached = false;
  TrainerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(trainerControllerProvider.notifier);
  }

  @override
  void dispose() {
    _controller?.resetSession();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
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
  }

  @override
  Widget build(BuildContext context) {
    return TableBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            _StatsBar(),
            _ModeToggle(),
            Expanded(child: _TableBody()),
            _FeedbackStrip(),
            _ActionBar(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode toggle — LEARN / TEST segmented control
// ---------------------------------------------------------------------------
class _ModeToggle extends ConsumerWidget {
  const _ModeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<TableThemeTokens>();
    final mode = ref.watch(
      trainerControllerProvider.select((s) => s.mode),
    );
    final controller = ref.read(trainerControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: SegmentedButton<TrainerMode>(
        segments: const [
          ButtonSegment(value: TrainerMode.learn, label: Text('LEARN')),
          ButtonSegment(value: TrainerMode.test,  label: Text('TEST')),
        ],
        selected: {mode},
        onSelectionChanged: (s) => controller.setMode(s.first),
        style: SegmentedButton.styleFrom(
          foregroundColor: Colors.white70,
          selectedForegroundColor: const Color(0xFF1A1000),
          selectedBackgroundColor: AppTheme.casinoGold,
          backgroundColor: tokens?.mid.withValues(alpha: 0.4) ?? Colors.white10,
          side: BorderSide(color: tokens?.mid ?? Colors.white24),
          textStyle: AppTheme.bodyStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats bar — accuracy + streak (reflects current mode's stats)
// ---------------------------------------------------------------------------
class _StatsBar extends ConsumerWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accuracy = ref.watch(
      trainerControllerProvider.select((s) => s.accuracy),
    );
    final streak = ref.watch(
      trainerControllerProvider.select((s) => s.currentStreak),
    );
    final best = ref.watch(
      trainerControllerProvider.select((s) => s.bestStreak),
    );
    final decisions = ref.watch(
      trainerControllerProvider.select((s) => s.decisionsCount),
    );

    final accuracyText = decisions == 0
        ? '—'
        : '${(accuracy * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: _kStatsPadV),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'TRAINER',
            style: AppTheme.displayStyle(
              fontSize: 18,
              shadows: AppTheme.goldGlow,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatChip(label: 'Accuracy', value: accuracyText),
              const SizedBox(width: 12),
              _StatChip(label: 'Streak', value: '$streak'),
              const SizedBox(width: 12),
              _StatChip(label: 'Best', value: '$best'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTheme.bodyStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: 10,
            color: Colors.white54,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Table body — dealer / result banner / player
// ---------------------------------------------------------------------------
class _TableBody extends StatelessWidget {
  const _TableBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DealerView(),
        SizedBox(height: _kSectionGap),
        SizedBox(height: _kResultH, child: _ResultBanner()),
        SizedBox(height: _kSectionGap),
        _PlayerView(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dealer hand
// ---------------------------------------------------------------------------
class _DealerView extends ConsumerWidget {
  const _DealerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealerCards = ref.watch(
      trainerControllerProvider.select((s) => s.dealerCards),
    );
    final gameState = ref.watch(
      trainerControllerProvider.select((s) => s.gameState),
    );

    final hideHole = gameState == GameState.playerTurn && dealerCards.length >= 2;

    String totalDisplay = '—';
    if (dealerCards.isNotEmpty && !hideHole) {
      final eval = HandEvaluator.evaluate(dealerCards);
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'DEALER',
          style: AppTheme.displayStyle(
            fontSize: 18,
            shadows: AppTheme.goldGlow,
          ),
        ),
        const SizedBox(height: _kCardLabelGap),
        if (dealerCards.isNotEmpty)
          Center(child: CardRow(cards: dealerCards, hideLast: hideHole))
        else
          const SizedBox(height: 100),
        const SizedBox(height: _kTotalLabelGap),
        if (!hideHole)
          Text(
            totalDisplay,
            style: AppTheme.bodyStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Result banner (round outcome) — fixed-height slot
// ---------------------------------------------------------------------------
class _ResultBanner extends ConsumerWidget {
  const _ResultBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final msg = ref.watch(
      trainerControllerProvider.select((s) => s.resultMessage),
    );
    if (msg == null) return const SizedBox.shrink();

    final isWin = msg.toLowerCase().contains('win') ||
        msg.toLowerCase().contains('blackjack');

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isWin ? const Color(0xFF1B7A35) : const Color(0xFF991B22),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          msg.toUpperCase(),
          style: AppTheme.displayStyle(
            fontSize: 20,
            color: Colors.white,
            shadows: isWin ? AppTheme.neonGlow : AppTheme.goldGlow,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player hand — switches to split layout when hasSplit is true
// ---------------------------------------------------------------------------
class _PlayerView extends ConsumerWidget {
  const _PlayerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSplit = ref.watch(
      trainerControllerProvider.select((s) => s.hasSplit),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: hasSplit
          ? const _TrainerSplitView(key: ValueKey('trainer-split'))
          : const _TrainerSingleHandView(key: ValueKey('trainer-single')),
    );
  }
}

class _TrainerSingleHandView extends ConsumerWidget {
  const _TrainerSingleHandView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerCards = ref.watch(
      trainerControllerProvider.select((s) => s.playerCards),
    );

    String totalDisplay = '—';
    if (playerCards.isNotEmpty) {
      final eval = HandEvaluator.evaluate(playerCards);
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
      if (eval.isBlackjack) totalDisplay += ' — Blackjack!';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          totalDisplay,
          style: AppTheme.bodyStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: _kTotalLabelGap),
        if (playerCards.isNotEmpty)
          Center(child: CardRow(cards: playerCards))
        else
          const SizedBox(height: 100),
        const SizedBox(height: _kCardLabelGap),
        Text(
          'YOUR HAND',
          style: AppTheme.displayStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class _TrainerSplitView extends ConsumerWidget {
  const _TrainerSplitView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHands = ref.watch(
      trainerControllerProvider.select((s) => s.allPlayerHands),
    );
    final activeIdx = ref.watch(
      trainerControllerProvider.select((s) => s.activeHandIndex),
    );
    final gameState = ref.watch(
      trainerControllerProvider.select((s) => s.gameState),
    );
    final isOver = gameState != GameState.playerTurn &&
        gameState != GameState.dealerTurn &&
        gameState != GameState.idle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row+Expanded gives each panel a bounded, equal-width slot.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < allHands.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _TrainerSplitPanel(
                  label: 'HAND ${i + 1}',
                  cards: allHands[i],
                  isActive: !isOver && activeIdx == i,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: _kCardLabelGap),
        Text(
          'YOUR HANDS',
          style: AppTheme.displayStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class _TrainerSplitPanel extends StatelessWidget {
  final String label;
  final List<dynamic> cards;
  final bool isActive;

  const _TrainerSplitPanel({
    required this.label,
    required this.cards,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    String totalDisplay = '—';
    if (cards.isNotEmpty) {
      final eval = HandEvaluator.evaluate(cards.cast());
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isActive ? 1.0 : 0.85,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 200),
        scale: isActive ? 1.02 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label above slot — gold when active.
            Text(
              label,
              style: AppTheme.displayStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: isActive ? AppTheme.casinoGold : Colors.white38,
              ),
            ),
            const SizedBox(height: 4),
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
                    CardRow(
                      cards: cards.cast(),
                      cardScale: kSplitCardScale,
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
// Feedback strip — correct / incorrect + explanation
// Fixed minimum height so the action bar never shifts.
// ---------------------------------------------------------------------------
class _FeedbackStrip extends ConsumerWidget {
  const _FeedbackStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(
      trainerControllerProvider.select((s) => s.lastFeedback),
    );
    final controller = ref.read(trainerControllerProvider.notifier);

    final tokens = Theme.of(context).extension<TableThemeTokens>();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kFeedbackMinH),
      child: Container(
        color: tokens?.darkFelt ?? AppTheme.darkFelt,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: feedback == null
            ? Center(
                child: Text(
                  'Deal to start practising',
                  style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white38),
                ),
              )
            : _FeedbackContent(
                feedback: feedback,
                onRevealExplanation: controller.revealExplanation,
              ),
      ),
    );
  }
}

class _FeedbackContent extends StatelessWidget {
  final TrainerFeedback feedback;
  final VoidCallback onRevealExplanation;

  const _FeedbackContent({
    required this.feedback,
    required this.onRevealExplanation,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = feedback.isCorrect;
    final pillColor =
        isCorrect ? const Color(0xFF1B7A35) : const Color(0xFF991B22);

    // When the ideal action (split/double) is not in the trainer UI, surface
    // the best available fallback rather than the unreachable ideal.
    final String pillLabel;
    if (isCorrect) {
      pillLabel = '✓  Correct';
    } else if (feedback.isIdealUnavailable) {
      pillLabel =
          '✗  Best: ${feedback.fallbackAction!.displayName}'
          '  (${feedback.recommended.displayName} not in trainer)';
    } else {
      pillLabel = '✗  Incorrect — strategy: ${feedback.recommended.displayName}';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            pillLabel,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (!isCorrect && feedback.explanation.isNotEmpty) ...[
          const SizedBox(height: 4),
          if (feedback.showExplanation)
            Text(
              feedback.explanation,
              textAlign: TextAlign.center,
              style: AppTheme.bodyStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            )
          else
            TextButton(
              onPressed: onRevealExplanation,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: AppTheme.bodyStyle(fontSize: 11),
              ),
              child: const Text('Show explanation'),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared button style for trainer action buttons (HIT / STAND / DOUBLE / SPLIT).
// ---------------------------------------------------------------------------
ButtonStyle _trainerButtonStyle(Color bg) => ElevatedButton.styleFrom(
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
// Action bar — Deal (between rounds) or Hit + Stand (during player turn)
// ---------------------------------------------------------------------------
class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(
      trainerControllerProvider.select((s) => s.gameState),
    );
    final isLocked = ref.watch(
      trainerControllerProvider.select((s) => s.isActionLocked),
    );
    final winRates = ref.watch(
      trainerControllerProvider.select((s) => s.winRates),
    );
    final mode = ref.watch(
      trainerControllerProvider.select((s) => s.mode),
    );
    final canDouble = ref.watch(
      trainerControllerProvider.select((s) => s.canDouble),
    );
    final canSplit = ref.watch(
      trainerControllerProvider.select((s) => s.canSplit),
    );
    final controller = ref.read(trainerControllerProvider.notifier);

    final tokens = Theme.of(context).extension<TableThemeTokens>();
    final isPlayerTurn = gameState == GameState.playerTurn;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kActionPadH,
        vertical: _kActionPadV,
      ),
      color: tokens?.darkFelt ?? AppTheme.darkFelt,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlayerTurn && mode == TrainerMode.learn && winRates != null)
            _TrainerWinRateRow(winRates: winRates),
          if (isPlayerTurn) ...[
            // All 4 buttons always in layout — DOUBLE/SPLIT disabled, not hidden.
            Row(
              children: [
                // HIT
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ElevatedButton(
                      onPressed: isLocked
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.hit();
                            },
                      style: _trainerButtonStyle(Colors.green),
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
                      onPressed: isLocked
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.stand();
                            },
                      style: _trainerButtonStyle(AppTheme.chipRed),
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
                      onPressed: (isLocked || !canDouble)
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.doubleDown();
                            },
                      style: _trainerButtonStyle(const Color(0xFF1A6B8A)),
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
                      onPressed: (isLocked || !canSplit)
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.split();
                            },
                      style: _trainerButtonStyle(const Color(0xFF6B3FA0)),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      onPressed: isLocked
                          ? null
                          : () {
                              ref.read(audioServiceProvider.notifier)
                                  .playSfx(SfxType.click);
                              controller.startNewRound();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.casinoGold,
                        foregroundColor: const Color(0xFF1A1000),
                        minimumSize: const Size(0, 52),
                        textStyle: AppTheme.bodyStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      child: const Text('DEAL'),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Win-rate bar for the trainer (Learn mode only).
// ---------------------------------------------------------------------------
class _TrainerWinRateRow extends StatelessWidget {
  final WinRateResult winRates;
  const _TrainerWinRateRow({required this.winRates});

  @override
  Widget build(BuildContext context) {
    final hitPct   = (winRates.hitWinRate   * 100).round();
    final standPct = (winRates.standWinRate * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _WinChip(label: 'Hit',   percent: hitPct),
          _WinChip(label: 'Stand', percent: standPct),
        ],
      ),
    );
  }
}

class _WinChip extends StatelessWidget {
  final String label;
  final int percent;
  const _WinChip({required this.label, required this.percent});

  @override
  Widget build(BuildContext context) {
    final color = percent >= 50 ? const Color(0xFF1B7A35) : Colors.white30;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54)),
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
