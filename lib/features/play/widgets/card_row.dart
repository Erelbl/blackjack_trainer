import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Card;
import '../../../engine/models/card.dart';
import '../../../app/theme.dart';
import 'card_assets.dart';
import 'playing_card_widget.dart';

// ---------------------------------------------------------------------------
// Result highlight state for a card row.
// ---------------------------------------------------------------------------
enum CardHighlight {
  none, // idle / active play
  win,  // winning hand — gold glow + scale pop per card
  lose, // losing hand  — opacity handled at container level; no per-card effect
}

// ---------------------------------------------------------------------------
// Timing constants
// ---------------------------------------------------------------------------

/// Slide-in + fade duration for each individual card entrance.
const Duration _kCardInDuration = Duration(milliseconds: 250);

/// Stagger between consecutive cards in the same row.
const Duration _kCardStagger = Duration(milliseconds: 150);

/// Stagger between consecutive win-pop animations (feels premium).
const Duration _kWinPopStagger = Duration(milliseconds: 40);

// ---------------------------------------------------------------------------
// CardRow — animated card row.
//
// Deal animation: P→D→P→D stagger via [dealOffset].
// Hit / dealer draw: only new card animates; existing cards stay in place.
// Win highlight: per-card gold glow + scale pop, staggered by [_kWinPopStagger].
// Reset: clears instantly; all pending timers cancelled.
// ---------------------------------------------------------------------------
class CardRow extends StatefulWidget {
  final List<Card> cards;
  final bool hideLast;
  final Duration dealOffset;
  final CardHighlight highlight;
  /// Scale applied to every card in this row (default 1.0 = full size).
  /// Use [kSplitCardScale] for split-mode panels so two hands fit on screen.
  final double cardScale;

  const CardRow({
    super.key,
    required this.cards,
    this.hideLast = false,
    this.dealOffset = Duration.zero,
    this.highlight = CardHighlight.none,
    this.cardScale = 1.0,
  });

  @override
  State<CardRow> createState() => _CardRowState();
}

class _CardRowState extends State<CardRow> with TickerProviderStateMixin {
  final List<Card> _shown = [];
  final List<AnimationController> _ctrls = [];
  final List<Timer> _timers = [];
  int _gen = 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    if (widget.cards.isNotEmpty) {
      _stageCards(widget.cards, from: 0, delay: widget.dealOffset);
    }
  }

  @override
  void didUpdateWidget(covariant CardRow old) {
    super.didUpdateWidget(old);

    // --- Part 2 fix: content-equality guard ---
    // _syncState() always calls .toList() so references differ even when cards
    // are identical.  Compare by value so we never trigger a spurious animation.
    if (_contentEquals(widget.cards, old.cards)) return;

    if (widget.cards.isEmpty) {
      _reset();
      return;
    }

    final isNewDeal = _shown.isEmpty || !_isPrefixOf(_shown, widget.cards);

    if (kDebugMode) {
      debugPrint('[CardRow] didUpdateWidget: '
          'shown=${_shown.length} old=${old.cards.length} '
          'new=${widget.cards.length} isNewDeal=$isNewDeal');
    }

    if (isNewDeal) {
      _reset();
      _stageCards(widget.cards, from: 0, delay: widget.dealOffset);
    } else {
      for (final t in _timers) { t.cancel(); }
      _timers.clear();
      _stageCards(widget.cards, from: _shown.length, delay: Duration.zero);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) { t.cancel(); }
    for (final c in _ctrls) { c.dispose(); }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Value equality using Card.== — prevents spurious triggers from toList().
  bool _contentEquals(List<Card> a, List<Card> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _isPrefixOf(List<Card> prefix, List<Card> full) {
    if (full.length < prefix.length) return false;
    for (int i = 0; i < prefix.length; i++) {
      if (prefix[i] != full[i]) return false;
    }
    return true;
  }

  void _stageCards(List<Card> cards, {required int from, required Duration delay}) {
    final gen = _gen;
    for (int i = 0; i < cards.length - from; i++) {
      final card = cards[from + i];
      final t = Timer(
        delay + Duration(milliseconds: i * _kCardStagger.inMilliseconds),
        () {
          if (!mounted || _gen != gen) return;
          final ctrl = AnimationController(vsync: this, duration: _kCardInDuration);
          setState(() {
            _shown.add(card);
            _ctrls.add(ctrl);
          });
          ctrl.forward();
        },
      );
      _timers.add(t);
    }
  }

  void _reset() {
    _gen++;
    for (final t in _timers) { t.cancel(); }
    _timers.clear();
    for (final c in _ctrls) { c.dispose(); }
    _ctrls.clear();
    if (_shown.isNotEmpty) setState(() => _shown.clear());
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = widget.cardScale;
    // LayoutBuilder lets us measure available width so large hands (5+ cards)
    // compress gracefully via overlap instead of horizontal scrolling.
    return LayoutBuilder(
      builder: (context, constraints) => _buildContent(constraints, s),
    );
  }

  Widget _buildContent(BoxConstraints constraints, double s) {
    final cardW = kCardWidth * s;
    final cardH = kCardHeight * s;
    final n = _shown.length;

    if (n == 0) return SizedBox(height: cardH);

    final step = _computeStep(n: n, cardW: cardW, availW: constraints.maxWidth, s: s);
    // Total width: (n−1) steps + the last card's full width.
    final rowW = step * (n - 1) + cardW;

    return SizedBox(
      width: rowW,
      height: cardH,
      child: Stack(
        // Clip.none lets the slide-in animation and win-glow paint outside bounds.
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < n; i++)
            Positioned(
              left: i * step,
              top: 0,
              child: _CardSlot(
                key: ValueKey('${_shown[i]}_$i'),
                card: _shown[i],
                faceDown: widget.hideLast && i == widget.cards.length - 1,
                dealCtrl: i < _ctrls.length ? _ctrls[i] : null,
                highlight: widget.highlight,
                // Stagger each card's win pop so they ripple left→right.
                winDelay: Duration(milliseconds: i * _kWinPopStagger.inMilliseconds),
                cardScale: s,
              ),
            ),
        ],
      ),
    );
  }

  /// Horizontal distance (px) from one card's left edge to the next.
  ///
  /// ≤4 cards: normal spacing (card width + 8 px gap) — no overlap.
  /// 5+ cards: compressed to fit all cards within [availW], with a floor of
  ///           25% card width visible (i.e. 75% max overlap per card).
  double _computeStep({
    required int n,
    required double cardW,
    required double availW,
    required double s,
  }) {
    final normalStep = cardW + 8.0 * s;
    if (n <= 1) return normalStep;
    if (!availW.isFinite || availW <= cardW) return normalStep;
    // Always check whether normal spacing would overflow before skipping compression.
    final normalRowW = normalStep * (n - 1) + cardW;
    if (normalRowW <= availW) return normalStep;
    // Spread n cards across availW: last card takes cardW, others share the rest.
    final fittingStep = (availW - cardW) / (n - 1);
    // Floor: at least 25% of each card must remain visible.
    final minStep = cardW * 0.25;
    return fittingStep.clamp(minStep, normalStep);
  }
}

// ---------------------------------------------------------------------------
// _CardSlot — wraps one PlayingCardWidget with:
//   • deal entrance  (slide-in from above + fade, via dealCtrl)
//   • win pop        (scale 1.0→1.04→1.0, gold glow behind card)
// ---------------------------------------------------------------------------
class _CardSlot extends StatefulWidget {
  final Card card;
  final bool faceDown;
  final AnimationController? dealCtrl;
  final CardHighlight highlight;
  final Duration winDelay;
  final double cardScale;

  const _CardSlot({
    super.key,
    required this.card,
    required this.faceDown,
    this.dealCtrl,
    this.highlight = CardHighlight.none,
    this.winDelay = Duration.zero,
    this.cardScale = 1.0,
  });

  @override
  State<_CardSlot> createState() => _CardSlotState();
}

class _CardSlotState extends State<_CardSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _winCtrl;
  late final Animation<double> _scaleAnim; // 1.0 → 1.04 → 1.0
  late final Listenable _animListenable;
  Timer? _winTimer;

  @override
  void initState() {
    super.initState();
    _winCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    // Bounce: quick scale-up then settle back
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.045), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.045, end: 1.0),  weight: 60),
    ]).animate(CurvedAnimation(parent: _winCtrl, curve: Curves.easeInOut));

    // Merge deal + win into one AnimatedBuilder listener.
    final c = widget.dealCtrl;
    _animListenable = c != null
        ? Listenable.merge([_winCtrl, c])
        : _winCtrl;
  }

  @override
  void didUpdateWidget(covariant _CardSlot old) {
    super.didUpdateWidget(old);
    if (widget.highlight != old.highlight) {
      _winTimer?.cancel();
      if (widget.highlight == CardHighlight.win) {
        _winTimer = Timer(widget.winDelay, () {
          if (mounted) _winCtrl.forward(from: 0);
        });
      } else {
        _winCtrl.reset();
      }
    }
  }

  @override
  void dispose() {
    _winTimer?.cancel();
    _winCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = widget.highlight == CardHighlight.win;
    final s = widget.cardScale;

    // Card child — scaled via FittedBox when cardScale < 1.
    // Cached by AnimatedBuilder so PlayingCardWidget is not rebuilt per frame.
    final cardChild = s == 1.0
        ? PlayingCardWidget(card: widget.card, faceDown: widget.faceDown)
        : SizedBox(
            width: kCardWidth * s,
            height: kCardHeight * s,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: kCardWidth,
                height: kCardHeight,
                child: PlayingCardWidget(card: widget.card, faceDown: widget.faceDown),
              ),
            ),
          );

    return AnimatedBuilder(
      animation: _animListenable,
      child: cardChild,
      builder: (_, cached) {
        // --- Deal entrance ---
        final c = widget.dealCtrl;
        double opacity = 1.0;
        double slideY = 0.0;
        if (c != null) {
          final t = Curves.easeOut.transform(c.value);
          opacity = t;
          slideY = (1.0 - t) * -28.0 * s; // slide scales with card size
        }

        // --- Win scale pop ---
        final scale = isWin ? _scaleAnim.value : 1.0;

        // --- Assemble ---
        // When win and animation has started: render glow BEHIND the card.
        Widget result;
        final winV = _winCtrl.value; // 0 when idle, 0→1 when running

        if (isWin && winV > 0) {
          result = Stack(
            alignment: Alignment.center,
            children: [
              // Gold border + glow — slightly larger than the card.
              Container(
                width:  (kCardWidth  + 5) * s,
                height: (kCardHeight + 5) * s,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8 * s),
                  border: Border.all(
                    color: AppTheme.casinoGold.withValues(alpha: 0.75 * winV),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.casinoGold.withValues(alpha: 0.40 * winV),
                      blurRadius: 12 * winV,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
              // Card on top — face fully visible
              Transform.scale(scale: scale, child: cached!),
            ],
          );
        } else {
          result = Transform.scale(scale: scale, child: cached!);
        }

        if (opacity < 1.0) result = Opacity(opacity: opacity, child: result);
        if (slideY != 0)   result = Transform.translate(offset: Offset(0, slideY), child: result);

        return result;
      },
    );
  }
}
