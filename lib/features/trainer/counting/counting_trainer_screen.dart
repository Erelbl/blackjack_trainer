import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../play/widgets/playing_card_widget.dart';
import '../../play/widgets/table_background.dart';
import 'counting_config.dart';
import 'counting_controller.dart';

// ── Root screen ───────────────────────────────────────────────────────────────

class CountingTrainerScreen extends ConsumerStatefulWidget {
  const CountingTrainerScreen({super.key});

  @override
  ConsumerState<CountingTrainerScreen> createState() =>
      _CountingTrainerScreenState();
}

class _CountingTrainerScreenState
    extends ConsumerState<CountingTrainerScreen> {
  final _answerCtrl = TextEditingController();

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(countingTrainerProvider);
    final notifier = ref.read(countingTrainerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Counting'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.casinoGold),
            tooltip: 'How to Count',
            onPressed: () => context.push('/trainer/counting/basics'),
          ),
        ],
      ),
      body: TableBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Selector strip — always visible, disabled while running ────
              _SelectorStrip(
                state:      state,
                onDuration: notifier.setDuration,
                onPace:     notifier.setPace,
              ),
              const Divider(color: Colors.white12, height: 1),

              // ── Phase content ─────────────────────────────────────────────
              Expanded(
                child: switch (state.phase) {
                  CountingPhase.idle => _IdleView(
                      onStart: notifier.startSession,
                    ),
                  CountingPhase.running => _RunningView(state: state),
                  CountingPhase.ended => _EndedView(
                      state:       state,
                      answerCtrl:  _answerCtrl,
                      onSubmit:    notifier.submitAnswer,
                      onPlayAgain: () {
                        _answerCtrl.clear();
                        notifier.startSession();
                      },
                    ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Selector strip ────────────────────────────────────────────────────────────

class _SelectorStrip extends StatelessWidget {
  final CountingTrainerState state;
  final void Function(CountingSessionDuration) onDuration;
  final void Function(CountingCardPace) onPace;

  const _SelectorStrip({
    required this.state,
    required this.onDuration,
    required this.onPace,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = state.phase != CountingPhase.running;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration row
          Row(
            children: [
              Text(
                'Duration',
                style: AppTheme.bodyStyle(
                    fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(width: 10),
              for (final d in CountingSessionDuration.values)
                _Chip(
                  label:    d.label,
                  selected: state.selectedDuration == d,
                  enabled:  enabled,
                  onTap:    () => onDuration(d),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Pace row
          Row(
            children: [
              Text(
                'Pace',
                style: AppTheme.bodyStyle(
                    fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(width: 10),
              for (final p in CountingCardPace.values)
                _Chip(
                  label:    p.label,
                  selected: state.selectedPace == p,
                  enabled:  enabled,
                  onTap:    () => onPace(p),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeAlpha = enabled ? 1.0 : 0.4;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.casinoGold.withValues(alpha: 0.18 * activeAlpha)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppTheme.casinoGold.withValues(alpha: 0.8 * activeAlpha)
                  : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            label,
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: selected
                  ? AppTheme.casinoGold.withValues(alpha: activeAlpha)
                  : Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle view ─────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final VoidCallback onStart;

  const _IdleView({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.style_outlined,
            size: 64,
            color: AppTheme.casinoGold,
          ),
          const SizedBox(height: 16),
          Text(
            'CARD COUNTING',
            style: AppTheme.displayStyle(fontSize: 32),
          ),
          const SizedBox(height: 8),
          Text(
            'Hi-Lo  ·  6 decks',
            style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white38),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: onStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casinoGold,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'START',
                style: AppTheme.bodyStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Running view ──────────────────────────────────────────────────────────────

class _RunningView extends StatelessWidget {
  final CountingTrainerState state;

  const _RunningView({required this.state});

  @override
  Widget build(BuildContext context) {
    final card = state.currentCard;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // ── HUD ──────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Countdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${state.timeLeft}',
                    style: AppTheme.displayStyle(
                      fontSize: 56,
                      color: state.timeLeft <= 10
                          ? AppTheme.chipRed
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    's',
                    style: AppTheme.bodyStyle(
                        fontSize: 18, color: Colors.white38),
                  ),
                ],
              ),
              // Cards shown
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${state.cardsShown}',
                    style: AppTheme.bodyStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'cards shown',
                    style: AppTheme.bodyStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ],
          ),

          // ── Card ─────────────────────────────────────────────────────────
          Expanded(
            child: Center(
              child: card == null
                  ? const SizedBox.shrink()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: PlayingCardWidget(
                        key: ValueKey(card),
                        card: card,
                        faceDown: false,
                        animate: false,
                      ),
                    ),
            ),
          ),

          Text(
            'Keep a mental count…',
            style: AppTheme.bodyStyle(
                fontSize: 12, color: Colors.white24),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Ended view ────────────────────────────────────────────────────────────────

class _EndedView extends StatelessWidget {
  final CountingTrainerState state;
  final TextEditingController answerCtrl;
  final void Function(int) onSubmit;
  final VoidCallback onPlayAgain;

  const _EndedView({
    required this.state,
    required this.answerCtrl,
    required this.onSubmit,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final submitted = state.result != null;

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
                "TIME'S UP!",
                style: AppTheme.displayStyle(fontSize: 30),
              ),
              const SizedBox(height: 6),
              Text(
                '${state.cardsShown} cards shown',
                style: AppTheme.bodyStyle(
                    fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 28),

              if (!submitted) ...[
                // ── Input ──────────────────────────────────────────────────
                Text(
                  'What was the running count?',
                  style: AppTheme.bodyStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: answerCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^-?\d*')),
                    ],
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: AppTheme.bodyStyle(
                          fontSize: 22, color: Colors.white24),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.casinoGold
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppTheme.casinoGold),
                      ),
                    ),
                    autofocus: true,
                    onSubmitted: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null) onSubmit(parsed);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final parsed = int.tryParse(answerCtrl.text);
                      if (parsed != null) onSubmit(parsed);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.casinoGold,
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'SUBMIT',
                      style: AppTheme.bodyStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // ── Result ────────────────────────────────────────────────
                _ResultBanner(correct: state.result!),
                const SizedBox(height: 20),
                _StatRow(
                  label: 'Your answer',
                  value: '${state.userAnswer}',
                  color: state.result!
                      ? const Color(0xFF4CAF50)
                      : AppTheme.chipRed,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'Actual count',
                  value: '${state.runningCountActual}',
                  color: AppTheme.casinoGold,
                  large: true,
                ),
                const SizedBox(height: 10),
                _StatRow(
                  label: 'Cards shown',
                  value: '${state.cardsShown}',
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPlayAgain,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.casinoGold,
                      foregroundColor: Colors.black,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ── Result banner ─────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final bool correct;

  const _ResultBanner({required this.correct});

  @override
  Widget build(BuildContext context) {
    final color =
        correct ? const Color(0xFF4CAF50) : AppTheme.chipRed;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        correct ? '✓  Correct!' : '✗  Incorrect',
        style: AppTheme.bodyStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ── Stat row ──────────────────────────────────────────────────────────────────

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
            fontWeight:
                large ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.white,
          ),
        ),
      ],
    );
  }
}
