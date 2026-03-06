import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme.dart';
import '../play/widgets/table_background.dart';
import '../trainer/drill/daily_drill_controller.dart';
import '../trainer/trainer_game_tab.dart';
import '../trainer/strategy_tables_tab.dart';

/// Entry point for the Trainer feature, reachable via the existing /training
/// route. Contains four tabs: practice game, strategy reference, card counting
/// trainer, and the Speed/Daily drill launcher.
class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          // Title inherits appBarTheme.titleTextStyle → Bebas Neue with gold glow.
          title: const Text('Trainer'),
          bottom: TabBar(
            indicatorColor: AppTheme.casinoGold,
            labelColor: AppTheme.casinoGold,
            unselectedLabelColor: Colors.white54,
            labelStyle: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
            unselectedLabelStyle: AppTheme.bodyStyle(fontSize: 13),
            tabs: const [
              Tab(text: 'GAME'),
              Tab(text: 'STRATEGY'),
              Tab(text: 'COUNTING'),
              Tab(text: 'DRILL'),
            ],
          ),
        ),
        // TableBackground applies the current theme's felt gradient to the
        // entire body area, matching the play screen and home screen.
        body: const TableBackground(
          child: TabBarView(
            // Disable swipe so it doesn't conflict with card row scroll.
            physics: NeverScrollableScrollPhysics(),
            children: [
              TrainerGameTab(),
              StrategyTablesTab(),
              _CountingTab(),
              _DrillLaunchTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Counting tab ──────────────────────────────────────────────────────────────

class _CountingTab extends StatelessWidget {
  const _CountingTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.style_outlined, size: 56, color: AppTheme.casinoGold),
          const SizedBox(height: 16),
          Text('CARD COUNTING', style: AppTheme.displayStyle(fontSize: 30)),
          const SizedBox(height: 6),
          Text(
            'Hi-Lo  •  Running & True Count',
            style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => context.push('/trainer/counting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casinoGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'START TRAINER',
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Secondary: link to basics screen
          InkWell(
            onTap: () => context.push('/trainer/counting/basics'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.casinoGold.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.casinoGold, size: 26),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Count (Hi-Lo)',
                          style: AppTheme.bodyStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Learn the Hi-Lo system step by step',
                          style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drill launcher tab ────────────────────────────────────────────────────────

class _DrillLaunchTab extends ConsumerWidget {
  const _DrillLaunchTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily    = ref.watch(dailyDrillControllerProvider);
    final notifier = ref.read(dailyDrillControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Speed Drill
          const Icon(Icons.timer_outlined, size: 56, color: AppTheme.casinoGold),
          const SizedBox(height: 16),
          Text('Speed Drill', style: AppTheme.displayStyle(fontSize: 30)),
          const SizedBox(height: 8),
          Text(
            '60-second reaction challenge',
            style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () => context.push('/speed-drill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casinoGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'START DRILL',
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Daily Drill card
          const SizedBox(height: 32),
          _DailyDrillCard(state: daily, onClaim: notifier.claimReward),
        ],
      ),
    );
  }
}

// ── Daily Drill lobby card ────────────────────────────────────────────────────

class _DailyDrillCard extends StatefulWidget {
  final DailyDrillState state;
  final Future<void> Function() onClaim;

  const _DailyDrillCard({required this.state, required this.onClaim});

  @override
  State<_DailyDrillCard> createState() => _DailyDrillCardState();
}

class _DailyDrillCardState extends State<_DailyDrillCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s      = widget.state;
    final reward = DailyDrillState.rewardForScore(s.bestScore);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.casinoGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 32,
            color: AppTheme.casinoGold,
          ),
          const SizedBox(height: 10),
          Text('Daily Drill', style: AppTheme.displayStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            '60 seconds · resets daily',
            style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white38),
          ),
          const SizedBox(height: 16),

          // Best / reward status
          if (s.bestScore > 0) ...[
            Text(
              'Best Today: ${s.bestScore}',
              style: AppTheme.bodyStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.casinoGold,
              ),
            ),
            const SizedBox(height: 6),
            if (s.claimed)
              Text(
                'Reward claimed ✓',
                style: AppTheme.bodyStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4CAF50),
                ),
              )
            else
              Text(
                'Reward: $reward coins',
                style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white54),
              ),
          ] else
            Text(
              'No score yet today',
              style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white38),
            ),

          const SizedBox(height: 16),

          // Start button
          SizedBox(
            width: 180,
            child: ElevatedButton(
              onPressed: () => context.push('/daily-drill'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casinoGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'START DAILY',
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Claim button — only if unclaimed and has a score
          if (!s.claimed && s.bestScore > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: 180,
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        await widget.onClaim();
                        if (mounted) setState(() => _busy = false);
                      },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppTheme.casinoGold.withValues(alpha: 0.6),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.casinoGold,
                        ),
                      )
                    : Text(
                        'Claim $reward Coins',
                        style: AppTheme.bodyStyle(
                          fontSize: 13,
                          color: AppTheme.casinoGold,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
