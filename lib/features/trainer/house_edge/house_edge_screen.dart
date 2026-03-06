import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../engine/config/blackjack_rules.dart';
import '../../play/state/blackjack_controller.dart';
import '../../play/widgets/table_background.dart';
import '../shared/rules_picker.dart';
import 'house_edge_calculator.dart';

class HouseEdgeScreen extends ConsumerWidget {
  const HouseEdgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules =
        ref.watch(blackjackControllerProvider.select((s) => s.rules));
    final estimate = HouseEdgeCalculator.estimate(rules);

    return Scaffold(
      appBar: AppBar(title: const Text('House Edge')),
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RulesSummary(
                  rules: rules,
                  onEdit: () => showRulesPickerSheet(context, ref),
                ),
                const SizedBox(height: 24),
                _EdgeDisplay(edgePercent: estimate.edgePercent),
                const SizedBox(height: 24),
                _Breakdown(rows: estimate.breakdown),
                const SizedBox(height: 24),
                _Explanation(edgePercent: estimate.edgePercent),
                const SizedBox(height: 20),
                _Disclaimer(text: estimate.disclaimer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rules summary ──────────────────────────────────────────────────────────────

class _RulesSummary extends StatelessWidget {
  const _RulesSummary({required this.rules, this.onEdit});

  final BlackjackRules rules;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final bjLabel = rules.blackjackPayout >= 1.5
        ? '3:2'
        : rules.blackjackPayout >= 1.2
            ? '6:5'
            : '${rules.blackjackPayout}:1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Current Rules', style: AppTheme.displayStyle(fontSize: 20)),
            if (onEdit != null)
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.casinoGold,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        const SizedBox(height: 10),
        _RuleRow(label: 'Decks', value: '${rules.deckCount}'),
        _RuleRow(
          label: 'Dealer soft 17',
          value: rules.dealerStandsSoft17 ? 'S17 (stands)' : 'H17 (hits)',
        ),
        _RuleRow(label: 'Blackjack pays', value: bjLabel),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.bodyStyle(fontSize: 13)),
          Text(
            value,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Main edge display ──────────────────────────────────────────────────────────

class _EdgeDisplay extends StatelessWidget {
  const _EdgeDisplay({required this.edgePercent});

  final double edgePercent;

  Color get _edgeColor {
    if (edgePercent < 0.60) return AppTheme.casinoGold;
    if (edgePercent < 1.50) return Colors.orange;
    return AppTheme.chipRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.casinoGold.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Estimated House Edge',
            style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            '${edgePercent.toStringAsFixed(2)}%',
            style: AppTheme.displayStyle(
              fontSize: 52,
              color: _edgeColor,
              shadows: AppTheme.goldGlow,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Breakdown list ─────────────────────────────────────────────────────────────

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.rows});

  final List<EdgeRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Breakdown', style: AppTheme.displayStyle(fontSize: 18)),
        const SizedBox(height: 10),
        ...rows.asMap().entries.map((e) {
          final isBase = e.key == 0;
          final label = e.value.$1;
          final delta = e.value.$2;
          final sign = isBase ? '' : (delta >= 0 ? '+' : '');
          return _BreakdownRow(
            label: label,
            deltaStr: '$sign${delta.toStringAsFixed(2)}%',
            isBase: isBase,
            isNegative: !isBase && delta < 0,
          );
        }),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.deltaStr,
    required this.isBase,
    required this.isNegative,
  });

  final String label;
  final String deltaStr;
  final bool isBase;
  final bool isNegative;

  Color get _valueColor {
    if (isBase) return Colors.white70;
    if (isNegative) return Colors.greenAccent;
    return AppTheme.casinoGold;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: isBase ? Colors.white70 : Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            deltaStr,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Explanation ────────────────────────────────────────────────────────────────

class _Explanation extends StatelessWidget {
  const _Explanation({required this.edgePercent});

  final double edgePercent;

  @override
  Widget build(BuildContext context) {
    final edgeStr = edgePercent.toStringAsFixed(2);
    final dollarStr = edgePercent.toStringAsFixed(2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What does this mean?', style: AppTheme.displayStyle(fontSize: 18)),
        const SizedBox(height: 10),
        Text(
          'The house edge is the casino\'s long-term advantage. '
          'An edge of $edgeStr% means that for every \$100 wagered, '
          'the expected long-term loss is about \$$dollarStr — '
          'assuming perfect basic strategy.',
          style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Text(
          'This is not a per-hand loss. It applies over many hands.',
          style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }
}

// ── Disclaimer ─────────────────────────────────────────────────────────────────

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
    );
  }
}
