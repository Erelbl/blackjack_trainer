import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../engine/models/card.dart';
import '../../../engine/models/suit.dart';
import '../../../engine/strategy/basic_strategy.dart';
import '../../play/widgets/playing_card_widget.dart';
import '../../play/widgets/table_background.dart';
import 'daily_drill_controller.dart';

// ── Root screen ───────────────────────────────────────────────────────────────

/// Active Daily Drill screen — auto-starts on mount.
///
/// Navigated to from the DRILL tab via "/daily-drill".
class DailyDrillScreen extends ConsumerStatefulWidget {
  const DailyDrillScreen({super.key});

  @override
  ConsumerState<DailyDrillScreen> createState() => _DailyDrillScreenState();
}

class _DailyDrillScreenState extends ConsumerState<DailyDrillScreen> {
  @override
  void initState() {
    super.initState();
    // Start after first frame so the provider is fully wired.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(dailyDrillControllerProvider.notifier).startDrill();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(dailyDrillControllerProvider);
    final notifier = ref.read(dailyDrillControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Drill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TableBackground(
        child: SafeArea(
          child: state.finished
              ? _ResultView(
                  state:       state,
                  onPlayAgain: notifier.startDrill,
                  onClaim:     notifier.claimReward,
                )
              : _DrillView(state: state, onAnswer: notifier.answer),
        ),
      ),
    );
  }
}

// ── Drill view ────────────────────────────────────────────────────────────────

class _DrillView extends StatelessWidget {
  final DailyDrillState state;
  final void Function(StrategyAction) onAnswer;

  const _DrillView({required this.state, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final pos = state.currentPosition;
    if (pos == null) return const SizedBox.shrink();

    // Only rank matters for strategy lookups; suit is arbitrary.
    final dealerCard = Card(rank: pos.dealerUpcard, suit: Suit.spades);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── Timer + score HUD ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                    'Score: ${state.drillScore}',
                    style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
                  ),
                  if (state.bestScore > 0)
                    Text(
                      'Best: ${state.bestScore}',
                      style: AppTheme.bodyStyle(
                        fontSize: 11,
                        color: AppTheme.casinoGold,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Card area ──────────────────────────────────────────────────────
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
                          card:     pos.playerCards[i],
                          faceDown: false,
                          animate:  false,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Action buttons ─────────────────────────────────────────────────
          Row(
            children: [
              _DrillBtn(label: 'Hit',   onTap: () => onAnswer(StrategyAction.hit)),
              const SizedBox(width: 12),
              _DrillBtn(label: 'Stand', onTap: () => onAnswer(StrategyAction.stand)),
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
  final DailyDrillState state;
  final VoidCallback onPlayAgain;
  final Future<void> Function() onClaim;

  const _ResultView({
    required this.state,
    required this.onPlayAgain,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final score    = state.drillScore;
    final accuracy = state.accuracyPercent.toStringAsFixed(0);
    final reward   = DailyDrillState.rewardForScore(score);

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
              Text('DAILY DRILL', style: AppTheme.displayStyle(fontSize: 28)),

              // New-best badge
              if (state.isNewBest) ...[
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
                    '🏆  NEW BEST TODAY',
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
              const Divider(color: Colors.white12, height: 28),
              _StatRow(
                label: 'Daily Score',
                value: '$score',
                large: true,
                color: AppTheme.casinoGold,
              ),

              // ── Reward section ─────────────────────────────────────────────
              const SizedBox(height: 20),
              if (state.claimed)
                Text(
                  'Reward claimed ✓',
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4CAF50),
                  ),
                )
              else
                _ClaimArea(reward: reward, onClaim: onClaim),

              const SizedBox(height: 24),

              // ── Action buttons ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppTheme.casinoGold.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: AppTheme.bodyStyle(
                          fontSize: 14,
                          color: AppTheme.casinoGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onPlayAgain,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.casinoGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Play Again',
                        style: AppTheme.bodyStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Claim area (stateful for busy guard) ──────────────────────────────────────

class _ClaimArea extends StatefulWidget {
  final int reward;
  final Future<void> Function() onClaim;

  const _ClaimArea({required this.reward, required this.onClaim});

  @override
  State<_ClaimArea> createState() => _ClaimAreaState();
}

class _ClaimAreaState extends State<_ClaimArea> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Reward: ${widget.reward} coins',
          style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await widget.onClaim();
                    if (mounted) setState(() => _busy = false);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.casinoGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black54,
                    ),
                  )
                : Text(
                    'Claim ${widget.reward} Coins',
                    style: AppTheme.bodyStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DrillBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DrillBtn({required this.label, required this.onTap});

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
