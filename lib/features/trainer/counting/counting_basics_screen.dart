import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../play/widgets/table_background.dart';

/// Full-screen "How to Count (Hi-Lo)" explanation.
///
/// Route: /trainer/counting/basics
/// Accessible via the info icon in [CountingTrainerScreen]'s AppBar.
class CountingBasicsScreen extends StatelessWidget {
  const CountingBasicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Count (Hi-Lo)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TableBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  title: 'How to Count',
                  children: [
                    const _HiLoGrid(),
                    const SizedBox(height: 16),
                    _Bullet('Start the count at 0 each shoe.'),
                    _Bullet('Update the count for every card you see.'),
                  ],
                ),

                _Section(
                  title: 'Running Count',
                  children: [
                    _Bullet('The current total of all Hi-Lo values seen.'),
                    _Bullet(
                        'Positive count → more high cards remain in the shoe.'),
                    _Bullet(
                        'Negative count → more low cards remain.'),
                  ],
                ),

                _Section(
                  title: 'True Count',
                  children: [
                    _Bullet(
                      'TC = Running Count ÷ Decks Remaining.',
                    ),
                    _Bullet(
                        'Required when playing with multiple decks.'),
                    _Bullet(
                        'More accurate than the running count alone.'),
                  ],
                ),

                _Section(
                  title: 'What It Means',
                  children: [
                    _Bullet(
                        'Higher TC statistically favors the player.'),
                    _Bullet('Lower TC favors the house.'),
                    _Bullet(
                        'A probability tool — not a guarantee of any outcome.'),
                  ],
                ),

                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    'Training only. Do not use card counting for real-money gambling.',
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section ───────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTheme.bodyStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.casinoGold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          const Divider(color: Colors.white12, height: 12),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

// ── Hi-Lo visual grid ────────────────────────────────────────────────────────

/// 2-row responsive table: rank labels on top, Hi-Lo values below.
/// Scrolls horizontally on narrow screens.
class _HiLoGrid extends StatelessWidget {
  static const _cards  = ['2','3','4','5','6','7','8','9','10','J','Q','K','A'];
  static const _values = ['+1','+1','+1','+1','+1','0','0','0','−1','−1','−1','−1','−1'];

  static Color _bg(String v) => switch (v) {
        '+1' => const Color(0xFF4CAF50),
        '0'  => Colors.white,
        _    => AppTheme.chipRed,
      };

  const _HiLoGrid();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — rank labels
          Row(
            children: [
              for (final c in _cards) _Cell(label: c, bg: Colors.white.withValues(alpha: 0.08), fg: Colors.white70, bold: false),
            ],
          ),
          const SizedBox(height: 3),
          // Row 2 — Hi-Lo values
          Row(
            children: [
              for (int i = 0; i < _values.length; i++)
                _Cell(
                  label: _values[i],
                  bg: _bg(_values[i]).withValues(alpha: 0.18),
                  fg: _bg(_values[i]),
                  bold: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final bool bold;

  const _Cell({required this.label, required this.bg, required this.fg, required this.bold});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 34,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTheme.bodyStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: fg,
        ),
      ),
    );
  }
}

// ── Bullet item ───────────────────────────────────────────────────────────────

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: AppTheme.bodyStyle(color: AppTheme.casinoGold),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
