import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/providers/economy_providers.dart';

/// Gold pill HUD showing the current coin balance with:
/// - AnimatedSwitcher on the number (fade+scale on value change)
/// - Floating "+X" / "-X" delta chip that slides up and fades out
class CoinBalance extends ConsumerStatefulWidget {
  const CoinBalance({super.key});

  @override
  ConsumerState<CoinBalance> createState() => _CoinBalanceState();
}

class _CoinBalanceState extends ConsumerState<CoinBalance>
    with SingleTickerProviderStateMixin {
  int? _delta;
  // Generation counter: prevents a stale async callback from clearing a newer delta.
  int _gen = 0;
  late AnimationController _ctrl;
  late Animation<double> _fadeOut;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Fade starts at 40 % of the animation, ramps out to the end.
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    // Slide up by 1.5× the chip's own height.
    _slideUp = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.5),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerDelta(int delta) {
    if (!mounted) return;
    final gen = ++_gen;
    setState(() => _delta = delta);
    _ctrl.forward(from: 0).then((_) {
      if (mounted && _gen == gen) setState(() => _delta = null);
    });
  }

  /// Compact display: ≥ 10 000 → "10k" / "15.5k", otherwise raw integer.
  static String _fmt(int coins) {
    if (coins >= 10000) {
      final isWhole = coins % 1000 == 0;
      return isWhole
          ? '${coins ~/ 1000}k'
          : '${(coins / 1000).toStringAsFixed(1)}k';
    }
    return '$coins';
  }

  @override
  Widget build(BuildContext context) {
    // Fires only when the economy value actually changes — not on every rebuild.
    ref.listen(economyControllerProvider, (prev, next) {
      final prevCoins = prev?.valueOrNull?.coins;
      final nextCoins = next.valueOrNull?.coins;
      if (prevCoins != null && nextCoins != null && prevCoins != nextCoins) {
        _triggerDelta(nextCoins - prevCoins);
      }
    });

    final economyAsync = ref.watch(economyControllerProvider);
    return economyAsync.when(
      data: (economy) => _buildPill(economy.coins),
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPill(int coins) {
    final delta = _delta;

    // CoinBalance is a purely visual HUD widget — it must never win the gesture
    // arena.  IgnorePointer makes this unconditional and measurable.
    Widget pill = IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── Pill: coin icon + animated number ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.casinoGold.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: AppTheme.casinoGold,
                  size: 18,
                ),
                const SizedBox(width: 5),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.75,
                        end: 1.0,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _fmt(coins),
                    // Key change drives the switcher animation.
                    key: ValueKey(coins),
                    style: AppTheme.bodyStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Delta chip: floats upward and fades out ─────────────────────────
          if (delta != null)
            Positioned(
              top: -20,
              child: FadeTransition(
                opacity: _fadeOut,
                child: SlideTransition(
                  position: _slideUp,
                  child: Text(
                    delta > 0 ? '+$delta' : '$delta',
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: delta > 0 ? Colors.greenAccent : AppTheme.chipRed,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return pill;
  }
}
