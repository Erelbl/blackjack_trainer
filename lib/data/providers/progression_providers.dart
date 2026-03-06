import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progression_state.dart';
import '../repositories/progression_repository.dart';
import '../repositories/shared_prefs_progression_repository.dart';
import '../../engine/config/retention_config.dart';
import '../../engine/utils/progression_utils.dart';
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
      final stored = await _repository.load();
      // Recompute level from totalXp using the new exponential curve so that
      // any stale persisted level is corrected on startup.
      final recomputedLevel = levelFromTotalXp(stored.xp);
      final progression = recomputedLevel == stored.level
          ? stored
          : stored.copyWith(level: recomputedLevel);
      if (recomputedLevel != stored.level) {
        if (kDebugMode) {
          debugPrint(
            '[Progression] level migrated on load: '
            '${stored.level} → $recomputedLevel (xp=${stored.xp})',
          );
        }
        await _repository.save(progression);
      }
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

      if (kDebugMode) {
        debugPrint(
          '[Progression] awardXP +$amount XP  '
          'xp: ${currentProgression.xp} → $newXP  '
          'level: ${currentProgression.level} → $newLevel'
          '${leveledUp ? '  (LEVEL UP)' : ''}',
        );
      }

      var newProgression = currentProgression.copyWith(
        xp: newXP,
        level: newLevel,
      );

      state = AsyncValue.data(newProgression);
      await _repository.save(newProgression);

      // Award coins on level up and emit pendingLevelUpInfo.
      if (leveledUp) {
        final isMilestone = RetentionConfig.kMilestoneLevelInterval > 0 &&
            newLevel % RetentionConfig.kMilestoneLevelInterval == 0;
        // Sum levelUpCoins(l) for each level gained (handles multi-level skips).
        int totalLevelCoins = 0;
        for (int l = currentProgression.level + 1; l <= newLevel; l++) {
          totalLevelCoins += levelUpCoins(l);
        }
        if (isMilestone) totalLevelCoins += RetentionConfig.kMilestoneLevelBonusCoins;

        if (kDebugMode) {
          debugPrint(
            '[Progression] levelUp ${currentProgression.level} → $newLevel  '
            'coins: +$totalLevelCoins'
            '${isMilestone ? "  (milestone bonus +${RetentionConfig.kMilestoneLevelBonusCoins})'" : ""}',
          );
        }

        await _ref.read(economyControllerProvider.notifier).addCoins(totalLevelCoins);

        // Emit level-up info so the UI can show a toast.
        // Must use direct construction to set pendingLevelUpInfo (copyWith
        // preserves the existing value and cannot clear nullable fields).
        final levelInfo = LevelUpInfo(
          level: newLevel,
          totalCoins: totalLevelCoins,
          isMilestone: isMilestone,
        );
        state = AsyncValue.data(ProgressionState(
          xp: newXP,
          level: newLevel,
          currentStreak: newProgression.currentStreak,
          lastLoginDate: newProgression.lastLoginDate,
          milestonesUnlocked: newProgression.milestonesUnlocked,
          pendingDailyReward: newProgression.pendingDailyReward,
          pendingLevelUpInfo: levelInfo,
        ));
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

      // Cap streak at 7 and loop: Day 7 → Day 1 the next consecutive day.
      final rawStreak = isConsecutive ? currentProgression.currentStreak + 1 : 1;
      final newStreak = ((rawStreak - 1) % 7) + 1; // always 1–7
      final coinReward = _getDailyRewardCoins(newStreak);

      if (kDebugMode) {
        final nextStreakDay = (newStreak % 7) + 1;
        final nextReward = RetentionConfig.kDailyRewards[newStreak % 7];
        debugPrint(
          '[Retention] onLogin\n'
          '  lastLoginDate : ${currentProgression.lastLoginDate ?? "never"}\n'
          '  today         : $today\n'
          '  consecutive   : $isConsecutive\n'
          '  streak        : ${currentProgression.currentStreak} → $newStreak\n'
          '  todayReward   : +$coinReward coins\n'
          '  nextStreakDay : $nextStreakDay  nextReward: $nextReward coins',
        );
      }

      final newProgression = currentProgression.copyWith(
        currentStreak: newStreak,
        lastLoginDate: today,
        pendingDailyReward: coinReward,
      );

      state = AsyncValue.data(newProgression);
      await _repository.save(newProgression);

      // Award daily login coins
      await _ref.read(economyControllerProvider.notifier).addCoins(coinReward);
    });
  }

  /// Clears the pending daily reward flag after the dialog has been shown.
  /// Uses direct construction (not copyWith) to explicitly set nullable to null.
  Future<void> clearDailyReward() async {
    state.whenData((current) async {
      final cleared = ProgressionState(
        xp: current.xp,
        level: current.level,
        currentStreak: current.currentStreak,
        lastLoginDate: current.lastLoginDate,
        milestonesUnlocked: current.milestonesUnlocked,
        pendingDailyReward: null,
        pendingLevelUpInfo: current.pendingLevelUpInfo,
      );
      state = AsyncValue.data(cleared);
      // pendingDailyReward is ephemeral — no need to persist
    });
  }

  /// Clears the pending level-up info after the toast has been shown.
  /// Uses direct construction (not copyWith) to explicitly set nullable to null.
  Future<void> clearLevelUp() async {
    state.whenData((current) async {
      final cleared = ProgressionState(
        xp: current.xp,
        level: current.level,
        currentStreak: current.currentStreak,
        lastLoginDate: current.lastLoginDate,
        milestonesUnlocked: current.milestonesUnlocked,
        pendingDailyReward: current.pendingDailyReward,
        pendingLevelUpInfo: null,
      );
      state = AsyncValue.data(cleared);
      // pendingLevelUpInfo is ephemeral — no need to persist
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

  int _calculateLevel(int xp) => levelFromTotalXp(xp);

  int _getDailyRewardCoins(int streak) {
    // streak is already capped 1–7 by onLogin(); clamp guards legacy calls.
    final index = (streak - 1).clamp(0, 6);
    return RetentionConfig.kDailyRewards[index];
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
