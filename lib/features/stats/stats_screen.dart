import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme.dart';
import '../../data/models/progression_state.dart';
import '../../data/providers/stats_providers.dart';
import '../../data/providers/progression_providers.dart';
import '../play/widgets/table_background.dart';
import '../trainer/drill/drill_controller.dart';
import 'achievements_tab.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync       = ref.watch(statsControllerProvider);
    final progressionAsync = ref.watch(progressionControllerProvider);
    final drillPb          = ref.watch(drillBestScoreProvider).valueOrNull ?? 0;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stats'),
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
              Tab(text: 'STATS'),
              Tab(text: 'ACHIEVEMENTS'),
            ],
          ),
        ),
        body: TableBackground(
          child: TabBarView(
            children: [
              // ── Tab 0: existing stats ───────────────────────────────
              statsAsync.when(
                data: (stats) => progressionAsync.when(
                  data: (progression) =>
                      _buildStatsContent(context, ref, stats, progression, drillPb),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Center(child: Text('Error loading progression')),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
              // ── Tab 1: achievements grid ────────────────────────────
              const AchievementsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsContent(BuildContext context, WidgetRef ref, stats, progression, int drillPb) {
    final pbWinStreak =
        ref.watch(sharedPreferencesProvider).valueOrNull?.getInt('pb_win_streak') ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressionSection(progression),
          const Divider(height: 32),
          _buildStatRow('Hands Played', stats.handsPlayed.toString()),
          const SizedBox(height: 8),
          _buildStatRow(
            'Player Wins',
            '${stats.playerWins} (${stats.winRate.toStringAsFixed(1)}%)',
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            'Dealer Wins',
            '${stats.dealerWins} (${stats.lossRate.toStringAsFixed(1)}%)',
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            'Pushes',
            '${stats.pushes} (${stats.pushRate.toStringAsFixed(1)}%)',
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            'Best Win Streak',
            pbWinStreak == 0 ? '—' : '$pbWinStreak',
          ),
          const Divider(height: 32),
          _buildStatRow('Blackjacks', stats.playerBlackjacks.toString()),
          const SizedBox(height: 8),
          _buildStatRow('Player Busts', stats.playerBusts.toString()),
          const SizedBox(height: 8),
          _buildStatRow('Dealer Busts', stats.dealerBusts.toString()),
          const Divider(height: 32),
          _buildStatRow('Speed Drill PB', drillPb == 0 ? '—' : '$drillPb'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showResetDialog(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Stats'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildProgressionSection(ProgressionState progression) {
    // Use the same within-level values as the play screen's XP bar so both
    // screens show identical numbers.
    final xpIn = progression.xpInCurrentLevel;
    final xpNeeded = progression.xpNeededForCurrentLevel;
    final progress = progression.levelProgress; // clamped 0.0–1.0

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LV ${progression.level}',
              style: AppTheme.displayStyle(
                fontSize: 22,
                color: AppTheme.casinoGold,
              ),
            ),
            Text(
              '$xpIn / $xpNeeded XP',
              style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.casinoGold),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Streak: ${progression.currentStreak} day${progression.currentStreak != 1 ? 's' : ''}',
              style: AppTheme.bodyStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Next daily reward: ${progression.dailyRewardCoins} coins',
          style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
        ),
      ],
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Stats'),
        content: const Text('Are you sure you want to reset all statistics?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(statsControllerProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
