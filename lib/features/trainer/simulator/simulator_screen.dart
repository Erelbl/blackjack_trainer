import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../engine/config/blackjack_rules.dart';
import '../../play/state/blackjack_controller.dart';
import '../../play/widgets/table_background.dart';
import '../shared/rules_picker.dart';
import 'simulator_controller.dart';
import 'simulator_engine.dart';

class SimulatorScreen extends ConsumerWidget {
  const SimulatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules =
        ref.watch(blackjackControllerProvider.select((s) => s.rules));
    final simState = ref.watch(simulatorControllerProvider);
    final ctrl = ref.read(simulatorControllerProvider.notifier);

    // Reset results when rules change while a result is displayed.
    ref.listen<BlackjackRules>(
      blackjackControllerProvider.select((s) => s.rules),
      (previous, next) {
        if (previous == null) return;
        final changed = previous.deckCount != next.deckCount ||
            previous.dealerStandsSoft17 != next.dealerStandsSoft17 ||
            previous.blackjackPayout != next.blackjackPayout;
        if (!changed) return;
        final hasResult = ref.read(simulatorControllerProvider).result != null;
        if (!hasResult) return;
        ctrl.resetForRulesChange();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rules changed — run again',
              style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white),
            ),
            backgroundColor: const Color(0xFF1A4A28),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Simulator')),
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Rules summary ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Rules  ',
                          style: AppTheme.bodyStyle(
                              fontSize: 13, color: Colors.white38),
                        ),
                        _RulesSummary(rules: rules),
                      ],
                    ),
                    TextButton(
                      onPressed: () => showRulesPickerSheet(context, ref),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.casinoGold,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Edit',
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.casinoGold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Hands selector ────────────────────────────────────────
                Text(
                  'Hands to Simulate',
                  style: AppTheme.displayStyle(fontSize: 20),
                ),
                const SizedBox(height: 10),
                _HandsSelector(
                  selected: simState.selectedHands,
                  enabled: !simState.running,
                  onChanged: ctrl.setHands,
                ),
                const SizedBox(height: 20),

                // ── Run button ────────────────────────────────────────────
                _RunButton(
                  running: simState.running,
                  onRun: () => ctrl.run(rules),
                ),

                // ── Loading ───────────────────────────────────────────────
                if (simState.running) ...[
                  const SizedBox(height: 36),
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.casinoGold,
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Simulating ${simState.selectedHands ~/ 1000}K hands…',
                      style: AppTheme.bodyStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],

                // ── Results ───────────────────────────────────────────────
                if (simState.result != null) ...[
                  const SizedBox(height: 24),
                  _ResultCard(result: simState.result!),
                  if (simState.lastRunRules != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Last run: ${_formatRules(simState.lastRunRules!)}',
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _UnitsExplanation(),
                ],

                // ── Error ─────────────────────────────────────────────────
                if (simState.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    simState.error!,
                    style: AppTheme.bodyStyle(
                        fontSize: 12, color: AppTheme.chipRed),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRules(BlackjackRules r) {
  final decks = '${r.deckCount}D';
  final soft17 = r.dealerStandsSoft17 ? 'S17' : 'H17';
  final payout = r.blackjackPayout >= 1.5
      ? '3:2'
      : r.blackjackPayout >= 1.2
          ? '6:5'
          : '${r.blackjackPayout}:1';
  return '$decks · $soft17 · $payout';
}

// ── Rules summary (compact one-liner) ─────────────────────────────────────────

class _RulesSummary extends StatelessWidget {
  const _RulesSummary({required this.rules});

  final BlackjackRules rules;

  @override
  Widget build(BuildContext context) {
    final decks = '${rules.deckCount}-deck';
    final soft17 = rules.dealerStandsSoft17 ? 'S17' : 'H17';
    final payout = rules.blackjackPayout >= 1.5
        ? '3:2'
        : rules.blackjackPayout >= 1.2
            ? '6:5'
            : '${rules.blackjackPayout}:1';

    return Text(
      '$decks · $soft17 · BJ $payout',
      style: AppTheme.bodyStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    );
  }
}

// ── Hands selector ─────────────────────────────────────────────────────────────

class _HandsSelector extends StatelessWidget {
  const _HandsSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final int selected;
  final bool enabled;
  final ValueChanged<int> onChanged;

  static const _options = [10000, 50000, 100000];
  static const _labels = ['10K', '50K', '100K'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_options.length, (i) {
        final isActive = _options[i] == selected;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: GestureDetector(
              onTap: enabled ? () => onChanged(_options[i]) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.casinoGold
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[i],
                  style: AppTheme.bodyStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive
                        ? Colors.black
                        : (enabled ? Colors.white70 : Colors.white30),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Run button ─────────────────────────────────────────────────────────────────

class _RunButton extends StatelessWidget {
  const _RunButton({required this.running, required this.onRun});

  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: running ? null : onRun,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.casinoGold,
          disabledBackgroundColor: Colors.white12,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          running ? 'SIMULATING…' : 'RUN SIMULATION',
          style: AppTheme.bodyStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: running ? Colors.white30 : Colors.black,
          ),
        ),
      ),
    );
  }
}

// ── Result card ────────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final SimResult result;

  Color _evColor(double absEv) {
    if (absEv < 0.60) return AppTheme.casinoGold;
    if (absEv < 1.50) return Colors.orange;
    return AppTheme.chipRed;
  }

  @override
  Widget build(BuildContext context) {
    final ev = result.evPer100Hands;
    final sign = ev >= 0 ? '+' : '';
    final color = _evColor(ev.abs());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.casinoGold.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        children: [
          // Primary metric
          Text(
            'EV per 100 hands',
            style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Text(
            '$sign${ev.toStringAsFixed(2)} units',
            style: AppTheme.displayStyle(
              fontSize: 40,
              color: color,
              shadows: AppTheme.goldGlow,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'EV per 100 units wagered: '
            '${result.evPer100UnitsWagered >= 0 ? '+' : ''}'
            '${result.evPer100UnitsWagered.toStringAsFixed(2)}',
            style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                label: 'Win',
                value: '${(result.winRate * 100).toStringAsFixed(1)}%',
                color: AppTheme.casinoGold,
              ),
              _Stat(
                label: 'Push',
                value: '${(result.pushRate * 100).toStringAsFixed(1)}%',
                color: Colors.white54,
              ),
              _Stat(
                label: 'Loss',
                value: '${(result.lossRate * 100).toStringAsFixed(1)}%',
                color: AppTheme.chipRed,
              ),
              _Stat(
                label: 'Blackjack',
                value: '${(result.blackjackRate * 100).toStringAsFixed(1)}%',
                color: AppTheme.neonCyan,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),

          // Exposure row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(
                label: 'Units wagered',
                value: result.totalUnitsWagered.toString(),
                color: Colors.white70,
              ),
              _Stat(
                label: 'Doubles',
                value: result.doubleCount.toString(),
                color: Colors.white70,
              ),
              _Stat(
                label: 'Splits',
                value: result.splitCount.toString(),
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Runtime
          Text(
            '${result.handsSimulated ~/ 1000}K hands · '
            '${(result.elapsedMs / 1000).toStringAsFixed(1)}s',
            style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.bodyStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTheme.bodyStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}

// ── Units explanation ──────────────────────────────────────────────────────────

class _UnitsExplanation extends StatelessWidget {
  const _UnitsExplanation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What does 'units' mean?",
            style: AppTheme.displayStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'A unit represents one base bet. '
            'If your base bet is \$10, an EV of −0.50 units per 100 hands '
            'means you can expect to lose about \$5 every 100 hands on average '
            '— assuming perfect basic strategy.',
            style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'EV can vary between runs because blackjacks, doubles, and splits '
            'change payout sizes even if win/loss rates look similar.',
            style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 4),
          Text(
            'Estimates assume simulated randomness and may vary slightly per run.',
            style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
