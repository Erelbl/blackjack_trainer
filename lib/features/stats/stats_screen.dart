import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/stats_providers.dart';
import '../../data/providers/progression_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsControllerProvider);
    final progressionAsync = ref.watch(progressionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: statsAsync.when(
        data: (stats) => progressionAsync.when(
          data: (progression) => _buildStatsContent(context, ref, stats, progression),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading progression')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildStatsContent(BuildContext context, WidgetRef ref, stats, progression) {
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
          const Divider(height: 32),
          _buildStatRow('Blackjacks', stats.playerBlackjacks.toString()),
          const SizedBox(height: 8),
          _buildStatRow('Player Busts', stats.playerBusts.toString()),
          const SizedBox(height: 8),
          _buildStatRow('Dealer Busts', stats.dealerBusts.toString()),
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

  Widget _buildProgressionSection(progression) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Level ${progression.level}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              '${progression.xp} / ${progression.xpForNextLevel} XP',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progression.progressToNextLevel,
            minHeight: 12,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              'Streak: ${progression.currentStreak} day${progression.currentStreak != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Next daily reward: ${progression.dailyRewardCoins} coins',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
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
