import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progression_state.dart';
import '../repositories/progression_repository.dart';
import '../repositories/shared_prefs_progression_repository.dart';
import 'economy_providers.dart';
import 'stats_providers.dart';

final progressionRepositoryProvider = Provider<ProgressionRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    throw Exception('SharedPreferences not initialized');
  }
  return SharedPrefsProgressionRepository(prefs);
});

class ProgressionController extends StateNotifier<AsyncValue<ProgressionState>> {
  final ProgressionRepository _repository;
  final Ref _ref;

  ProgressionController(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _loadProgression();
  }

  Future<void> _loadProgression() async {
    state = const AsyncValue.loading();
    try {
      final progression = await _repository.load();
      state = AsyncValue.data(progression);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> awardXP(int amount) async {
    state.whenData((currentProgression) async {
      final newXP = currentProgression.xp + amount;
      final newLevel = _calculateLevel(newXP);

      // Check if leveled up
      final leveledUp = newLevel > currentProgression.level;

      var newProgression = currentProgression.copyWith(
        xp: newXP,
        level: newLevel,
      );

      state = AsyncValue.data(newProgression);
      await _repository.save(newProgression);

      // Award coins on level up
      if (leveledUp) {
        final levelsGained = newLevel - currentProgression.level;
        final coinReward = levelsGained * 500; // 500 coins per level
        await _ref.read(economyControllerProvider.notifier).addCoins(coinReward);
      }
    });
  }

  Future<void> onLogin() async {
    state.whenData((currentProgression) async {
      final now = DateTime.now();
      final today = _dateToString(now);

      // Check if already logged in today
      if (currentProgression.lastLoginDate == today) {
        return; // Already got daily bonus
      }

      // Check if streak continues (yesterday's login)
      final yesterday = _dateToString(now.subtract(const Duration(days: 1)));
      final isConsecutive = currentProgression.lastLoginDate == yesterday;

      final newStreak = isConsecutive ? currentProgression.currentStreak + 1 : 1;
      final coinReward = _getDailyRewardCoins(newStreak);

      final newProgression = currentProgression.copyWith(
        currentStreak: newStreak,
        lastLoginDate: today,
      );

      state = AsyncValue.data(newProgression);
      await _repository.save(newProgression);

      // Award daily login coins
      await _ref.read(economyControllerProvider.notifier).addCoins(coinReward);
    });
  }

  Future<void> checkMilestones(int handsPlayed) async {
    state.whenData((currentProgression) async {
      final milestones = [100, 500, 1000];
      var newMilestones = List<int>.from(currentProgression.milestonesUnlocked);
      var coinsToAward = 0;

      for (final milestone in milestones) {
        if (handsPlayed >= milestone &&
            !currentProgression.hasMilestone(milestone)) {
          newMilestones.add(milestone);
          coinsToAward += _getMilestoneReward(milestone);
        }
      }

      if (newMilestones.length > currentProgression.milestonesUnlocked.length) {
        final newProgression = currentProgression.copyWith(
          milestonesUnlocked: newMilestones,
        );

        state = AsyncValue.data(newProgression);
        await _repository.save(newProgression);

        // Award milestone coins
        await _ref.read(economyControllerProvider.notifier).addCoins(coinsToAward);
      }
    });
  }

  int _calculateLevel(int xp) {
    int level = 1;
    while (_xpRequiredForLevel(level + 1) <= xp) {
      level++;
    }
    return level;
  }

  int _xpRequiredForLevel(int level) {
    // Sum of XP required for all previous levels
    int total = 0;
    for (int i = 2; i <= level; i++) {
      total += (100 * (i * 1.5)).toInt();
    }
    return total;
  }

  int _getDailyRewardCoins(int streak) {
    final day = (streak % 7); // 0-6
    return switch (day) {
      0 => 500, // Day 7 (streak % 7 == 0)
      1 => 100,
      2 => 150,
      3 => 200,
      4 => 250,
      5 => 300,
      6 => 400,
      _ => 100,
    };
  }

  int _getMilestoneReward(int milestone) {
    return switch (milestone) {
      100 => 250,
      500 => 1000,
      1000 => 2500,
      _ => 0,
    };
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

final progressionControllerProvider =
    StateNotifierProvider<ProgressionController, AsyncValue<ProgressionState>>(
        (ref) {
  final repository = ref.watch(progressionRepositoryProvider);
  return ProgressionController(repository, ref);
});
