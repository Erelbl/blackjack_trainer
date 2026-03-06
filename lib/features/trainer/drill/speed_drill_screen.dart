import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../engine/models/card.dart';
import '../../../engine/models/suit.dart';
import '../../../engine/strategy/basic_strategy.dart';
import '../../play/widgets/playing_card_widget.dart';
import '../../play/widgets/table_background.dart';
import 'drill_controller.dart';

// ── Root screen ───────────────────────────────────────────────────────────────

/// The active drill screen — auto-starts the drill on first mount.
///
/// Navigated to from [SpeedDrillLobbyScreen] via "/speed-drill/run".
/// The lobby owns the pre-start UX; this screen owns running + results.
class SpeedDrillScreen extends ConsumerStatefulWidget {
  const SpeedDrillScreen({super.key});

  @override
  ConsumerState<SpeedDrillScreen> createState() => _SpeedDrillScreenState();
}

class _SpeedDrillScreenState extends ConsumerState<SpeedDrillScreen> {
  @override
  void initState() {
    super.initState();
    // Start the drill after the first frame so the provider is fully wired.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(drillControllerProvider.notifier).startDrill();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(drillControllerProvider);
    final notifier = ref.read(drillControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Drill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TableBackground(
        child: SafeArea(
          child: state.finished
              ? _ResultView(state: state, onPlayAgain: notifier.startDrill)
              : _DrillView(state: state, onAnswer: notifier.answer),
        ),
      ),
    );
  }
}

// ── Drill view ────────────────────────────────────────────────────────────────

class _DrillView extends StatelessWidget {
  final DrillState state;
  final void Function(StrategyAction) onAnswer;

  const _DrillView({required this.state, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final pos = state.currentPosition;
    if (pos == null) return const SizedBox.shrink();

    // Dealer upcard rendered with a fixed suit — only rank matters for strategy.
    final dealerCard = Card(rank: pos.dealerUpcard, suit: Suit.spades);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── Timer + Score HUD ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Large countdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${state.remainingSeconds}',
                    style: AppTheme.displayStyle(
                      fontSize: 56,
                      color: state.remainingSeconds <= 10
                          ? AppTheme.chipRed
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    's',
                    style: AppTheme.bodyStyle(fontSize: 18, color: Colors.white38),
                  ),
                ],
              ),

              // Correct / Wrong + running score + PB
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(
                        '✓ ${state.correct}',
                        style: AppTheme.bodyStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '✗ ${state.wrong}',
                        style: AppTheme.bodyStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.chipRed,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Score: ${state.finalScore}',
                    style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
                  ),
                  if (state.personalBest > 0)
                    Text(
                      'PB: ${state.personalBest}',
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        color: AppTheme.casinoGold,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Centered card content ──────────────────────────────────────────
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEALER SHOWS',
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PlayingCardWidget(card: dealerCard, faceDown: false, animate: false),
                  const SizedBox(height: 28),
                  Text(
                    'YOUR HAND',
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      color: Colors.white38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < pos.playerCards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        PlayingCardWidget(
                          card: pos.playerCards[i],
                          faceDown: false,
                          animate: false,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Hit / Stand buttons ────────────────────────────────────────────
          Row(
            children: [
              _DrillButton(
                label: 'Hit',
                onTap: () => onAnswer(StrategyAction.hit),
              ),
              const SizedBox(width: 12),
              _DrillButton(
                label: 'Stand',
                onTap: () => onAnswer(StrategyAction.stand),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Result view ───────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final DrillState state;
  final VoidCallback onPlayAgain;

  const _ResultView({required this.state, required this.onPlayAgain});

  @override
  Widget build(BuildContext context) {
    final avgSecs  = (state.averageReactionMs / 1000).toStringAsFixed(1);
    final accuracy = state.accuracy.toStringAsFixed(0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.casinoGold.withValues(alpha: 0.4),
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DRILL COMPLETE',
                style: AppTheme.displayStyle(fontSize: 28),
              ),
              // NEW PB badge — only shown when the record was beaten this run
              if (state.isNewPb) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.casinoGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.casinoGold.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    '🏆  NEW PERSONAL BEST',
                    style: AppTheme.bodyStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.casinoGold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _StatRow(
                label: 'Correct',
                value: '${state.correct}',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 10),
              _StatRow(
                label: 'Wrong',
                value: '${state.wrong}',
                color: AppTheme.chipRed,
              ),
              const SizedBox(height: 10),
              _StatRow(label: 'Accuracy', value: '$accuracy%'),
              const SizedBox(height: 10),
              _StatRow(label: 'Avg Reaction', value: '${avgSecs}s'),
              // Show previous PB only when this run didn't beat it
              if (!state.isNewPb && state.personalBest > 0) ...[
                const SizedBox(height: 10),
                _StatRow(
                  label: 'Personal Best',
                  value: '${state.personalBest}',
                  color: AppTheme.casinoGold,
                ),
              ],
              const Divider(color: Colors.white12, height: 28),
              _StatRow(
                label: 'Final Score',
                value: '${state.finalScore}',
                large: true,
                color: AppTheme.casinoGold,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPlayAgain,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.casinoGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Play Again',
                    style: AppTheme.bodyStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _DrillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DrillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.casinoGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.casinoGold.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.bodyStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool large;

  const _StatRow({
    required this.label,
    required this.value,
    this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: large ? 15 : 13,
            color: Colors.white54,
          ),
        ),
        Text(
          value,
          style: AppTheme.bodyStyle(
            fontSize: large ? 22 : 15,
            fontWeight: large ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
