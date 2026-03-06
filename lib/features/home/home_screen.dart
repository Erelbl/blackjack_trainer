import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme.dart';
import '../../data/models/progression_state.dart';
import '../../data/providers/economy_providers.dart';
import '../../data/providers/progression_providers.dart';
import '../../engine/config/retention_config.dart';
import '../../engine/progression/progression_manager.dart';
import '../../services/audio_service.dart';
import '../../shared/widgets/coin_balance.dart';
import '../play/widgets/table_background.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  static const _kOnboardingKey = 'onboarding_popup_seen';

  /// True once the onboarding check has run this session.
  bool _onboardingChecked = false;

  /// Prevents stacking a second dialog if one is already visible.
  bool _dailyDialogOpen = false;

  /// Tracks the last date for which the daily tick was completed.
  String? _lastDailyTickDate;

  /// Prevents re-entrant calls to [_runDailyTickIfNeeded].
  bool _dailyTickInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer to post-frame so ref.read is safe (not inside build).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOnboardingThenDaily();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning from background; guard prevents spam.
    if (state == AppLifecycleState.resumed && mounted) {
      _runDailyTickIfNeeded();
    }
  }

  /// Runs the daily tick (challenge reset + streak award) at most once per
  /// calendar day. Re-entrant calls and same-day repeats are no-ops.
  void _runDailyTickIfNeeded() {
    if (_dailyTickInFlight) return;
    final today = _todayKey();
    if (_lastDailyTickDate == today) return;
    _dailyTickInFlight = true;
    _lastDailyTickDate = today;
    ProgressionManager.instance.ensureDailyReset();
    ref.read(progressionControllerProvider.notifier).onLogin();
    _dailyTickInFlight = false;
  }

  Future<void> _checkOnboardingThenDaily() async {
    if (_onboardingChecked) {
      _runDailyTickIfNeeded();
      return;
    }
    _onboardingChecked = true;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kOnboardingKey) ?? false)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _OnboardingDialog(),
      );
      await prefs.setBool(_kOnboardingKey, true);
    }
    if (mounted) _runDailyTickIfNeeded();
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void _showDailyChallengesDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => _DailyChallengesDialog(
        onClaimId: (id) async {
          final reward = await ProgressionManager.instance.claimDaily(id);
          if (reward != null && mounted) {
            await ref
                .read(economyControllerProvider.notifier)
                .addCoins(reward.coins);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show the daily reward dialog whenever pendingDailyReward becomes non-null.
    ref.listen<AsyncValue<ProgressionState>>(progressionControllerProvider,
        (_, next) {
      final reward = next.valueOrNull?.pendingDailyReward;
      final streak = next.valueOrNull?.currentStreak ?? 1;
      if (reward != null && mounted && !_dailyDialogOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_dailyDialogOpen) {
            _showDailyRewardDialog(reward, streak);
          }
        });
      }
    });

    final progressionAsync = ref.watch(progressionControllerProvider);
    final progression = progressionAsync.valueOrNull;
    final streak = progression?.currentStreak ?? 0;
    final pending = progression?.pendingDailyReward;

    return Scaffold(
      body: TableBackground(
        child: SafeArea(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Coin HUD strip: streak badge · settings · balance ─────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Streak badge — left side
                  _StreakBadge(
                    streak: streak,
                    isPending: pending != null,
                    onTap: pending != null
                        ? () => _showDailyRewardDialog(pending, streak)
                        : null,
                  ),
                  // Settings + coin balance — right side
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(audioServiceProvider.notifier)
                              .playSfx(SfxType.click);
                          context.push('/settings');
                        },
                        child: const Icon(
                          Icons.settings,
                          color: Colors.white38,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const CoinBalance(),
                      const SizedBox(width: 6),
                      // Get Coins shortcut — navigates to the coin IAP screen.
                      GestureDetector(
                        onTap: () => context.push('/iap'),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.casinoGold.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.casinoGold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppTheme.casinoGold,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Hero: suits / title / level badge ────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decorative card suits
                  const Text(
                    '♠  ♥  ♦  ♣',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0x40FFFFFF),
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Primary title
                  Text(
                    'BLACKJACK',
                    style: AppTheme.displayStyle(
                      fontSize: 80,
                      letterSpacing: 4,
                      shadows: AppTheme.goldGlow,
                    ),
                  ),
                  Text(
                    'TRAINER',
                    style: AppTheme.displayStyle(
                      fontSize: 36,
                      color: const Color(0x99FFFFFF),
                      letterSpacing: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── Navigation buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Daily challenges progress pill ───────────────────────
                  Center(
                    child: _DailyPill(
                      onTap: () => _showDailyChallengesDialog(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.casino, size: 22),
                      label: const Text('PLAY'),
                      onPressed: () {
                        ref
                            .read(audioServiceProvider.notifier)
                            .playSfx(SfxType.click);
                        context.push('/play');
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Secondary row
                  Row(
                    children: [
                      Expanded(
                        child: _NavButton(
                          label: 'TRAINING',
                          icon: Icons.school,
                          route: '/training',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NavButton(
                          label: 'STATS',
                          icon: Icons.bar_chart,
                          route: '/stats',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: _NavButton(
                      label: 'STORE',
                      icon: Icons.store,
                      route: '/store',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),    // SafeArea
      ),    // TableBackground
    );
  }

  void _showDailyRewardDialog(int coins, int streak) {
    if (!mounted || _dailyDialogOpen) return;
    _dailyDialogOpen = true;
    final dayIndex = (streak - 1) % 7; // 0-based index into 7-day cycle

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _DailyRewardDialog(
        coins: coins,
        dayIndex: dayIndex,
        streak: streak,
        onClaim: () => Navigator.of(ctx).pop(),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _dailyDialogOpen = false);
        ref.read(progressionControllerProvider.notifier).clearDailyReward();
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak Badge — compact pill showing current daily-streak progress.
// ─────────────────────────────────────────────────────────────────────────────

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({
    required this.streak,
    required this.isPending,
    this.onTap,
  });

  final int streak;
  final bool isPending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (streak == 0 && !isPending) return const SizedBox.shrink();

    final dayInCycle = streak == 0 ? 1 : ((streak - 1) % 7) + 1;
    final label = isPending ? '🎁 Daily Ready' : '🔥 Day $dayInCycle/7';
    final borderColor = isPending
        ? AppTheme.casinoGold.withValues(alpha: 0.8)
        : Colors.white24;
    final bgColor = isPending
        ? AppTheme.casinoGold.withValues(alpha: 0.12)
        : Colors.white10;
    final textColor = isPending ? AppTheme.casinoGold : Colors.white60;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Text(
          label,
          style: AppTheme.bodyStyle(fontSize: 11, color: textColor),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Reward Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DailyRewardDialog extends StatelessWidget {
  const _DailyRewardDialog({
    required this.coins,
    required this.dayIndex,
    required this.streak,
    required this.onClaim,
  });

  final int coins;
  final int dayIndex; // 0-based, 0–6
  final int streak;
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
            // Title
            Text(
              'DAILY REWARD',
              style: AppTheme.displayStyle(
                fontSize: 26,
                shadows: AppTheme.goldGlow,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Day ${dayIndex + 1} of 7',
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 20),
            // 7-day streak row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final isEarned = i <= dayIndex;
                final isCurrent = i == dayIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _DayPill(
                    day: i + 1,
                    reward: RetentionConfig.kDailyRewards[i],
                    isEarned: isEarned,
                    isCurrent: isCurrent,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Reward amount
            Text(
              '+$coins',
              style: AppTheme.displayStyle(
                fontSize: 48,
                color: AppTheme.casinoGold,
                shadows: AppTheme.goldGlow,
              ),
            ),
            Text(
              'COINS',
              style: AppTheme.displayStyle(
                fontSize: 16,
                color: AppTheme.casinoGold.withValues(alpha: 0.7),
                letterSpacing: 4,
              ),
            ),
            if (streak >= 7) ...[
              const SizedBox(height: 8),
              Text(
                'Streak complete! Restarting tomorrow.',
                style: AppTheme.bodyStyle(
                  fontSize: 11,
                  color: Colors.white38,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Claim button
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

/// Compact label for the day-pill reward amount.
/// Examples: 100→"100", 600→"600", 1000→"1k", 1500→"1.5k", 3000→"3k".
String _fmtReward(int coins) {
  if (coins >= 1000) {
    final whole = coins ~/ 1000;
    final rem = coins % 1000;
    return rem == 0 ? '${whole}k' : '$whole.${rem ~/ 100}k';
  }
  return '$coins';
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.day,
    required this.reward,
    required this.isEarned,
    required this.isCurrent,
  });

  final int day;
  final int reward;
  final bool isEarned;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final bg = isCurrent
        ? AppTheme.casinoGold
        : isEarned
            ? AppTheme.casinoGold.withValues(alpha: 0.3)
            : Colors.white10;
    final borderColor = isEarned
        ? AppTheme.casinoGold.withValues(alpha: 0.7)
        : Colors.white12;
    final textColor = isCurrent
        ? Colors.black
        : isEarned
            ? AppTheme.casinoGold
            : Colors.white38;

    return Container(
      width: 34,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$day',
            style: AppTheme.displayStyle(fontSize: 13, color: textColor),
          ),
          Text(
            _fmtReward(reward),
            style: AppTheme.bodyStyle(fontSize: 8, color: textColor),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Progress Pill — "Daily: X/3"; opens missions popup on tap.
// ─────────────────────────────────────────────────────────────────────────────

class _DailyPill extends StatelessWidget {
  const _DailyPill({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mgr = ProgressionManager.instance;
    return ListenableBuilder(
      listenable: mgr,
      builder: (context, _) {
        if (!mgr.isInitialized) return const SizedBox.shrink();
        final challenges = mgr.todaysChallenges;
        if (challenges.isEmpty) return const SizedBox.shrink();
        final completed =
            challenges.where((c) => mgr.isDailyComplete(c.id)).length;
        final total = challenges.length;
        final isDone = completed == total;
        final label = isDone ? 'Daily: $total/$total ✓' : 'Daily: $completed/$total';
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDone
                  ? AppTheme.casinoGold.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDone
                    ? AppTheme.casinoGold.withValues(alpha: 0.5)
                    : Colors.white24,
              ),
            ),
            child: Text(
              label,
              style: AppTheme.bodyStyle(
                fontSize: 12,
                color: isDone ? AppTheme.casinoGold : Colors.white60,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Challenges Dialog — themed missions popup.
// ─────────────────────────────────────────────────────────────────────────────

class _DailyChallengesDialog extends StatelessWidget {
  const _DailyChallengesDialog({required this.onClaimId});

  final Future<void> Function(String id) onClaimId;

  @override
  Widget build(BuildContext context) {
    final themeColor = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).colorScheme.surface;
    final mgr = ProgressionManager.instance;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: ListenableBuilder(
          listenable: mgr,
          builder: (context, _) {
            final challenges = mgr.todaysChallenges;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "TODAY'S CHALLENGES",
                  style: AppTheme.displayStyle(fontSize: 20, color: themeColor),
                ),
                const SizedBox(height: 16),
                ...challenges.map((c) {
                  final current = mgr.getDailyProgress(c.id);
                  final done = mgr.isDailyComplete(c.id);
                  final claimed = mgr.isDailyClaimed(c.id);
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: themeColor.withValues(alpha: 0.35)),
                      color: claimed
                          ? themeColor.withValues(alpha: 0.07)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                style: AppTheme.bodyStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: claimed
                                      ? Colors.white38
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$current / ${c.target}',
                                style: AppTheme.bodyStyle(
                                  fontSize: 11,
                                  color: claimed
                                      ? Colors.white24
                                      : themeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (claimed)
                          Icon(Icons.check_circle,
                              color: themeColor, size: 20)
                        else if (done)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: themeColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              onClaimId(c.id);
                              Navigator.of(context).pop();
                            },
                            child: Text(
                              'CLAIM +${c.rewardCoins}',
                              style: AppTheme.bodyStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Dialog — shown once on first ever Home entry.
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingDialog extends StatelessWidget {
  const _OnboardingDialog();

  @override
  Widget build(BuildContext context) {
    const bullets = [
      'Play full blackjack with real casino rules.',
      'Train basic strategy & card counting.',
      'Complete daily drills and earn rewards.',
    ];
    return Dialog(
      backgroundColor: const Color(0xFF0D2B1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WELCOME TO\nBLACKJACK TRAINER PRO',
              style: AppTheme.displayStyle(
                fontSize: 24,
                shadows: AppTheme.goldGlow,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: AppTheme.bodyStyle(color: AppTheme.casinoGold),
                    ),
                    Expanded(
                      child: Text(b, style: AppTheme.bodyStyle(fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Start Playing'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Skip',
                style: AppTheme.bodyStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends ConsumerWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18, color: AppTheme.casinoGold),
      label: Text(
        label,
        style: AppTheme.bodyStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),
      onPressed: () {
        ref.read(audioServiceProvider.notifier).playSfx(SfxType.click);
        context.push(route);
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: AppTheme.casinoGold, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}
