import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/config/retention_config.dart';
import '../models/weekly_goal_state.dart';
import '../repositories/shared_prefs_weekly_goal_repository.dart';
import '../repositories/weekly_goal_repository.dart';
import 'economy_providers.dart';
import 'progression_providers.dart';
import 'stats_providers.dart'; // for sharedPreferencesProvider

final weeklyGoalRepositoryProvider = Provider<WeeklyGoalRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) throw Exception('SharedPreferences not initialized');
  return SharedPrefsWeeklyGoalRepository(prefs);
});

class WeeklyGoalController
    extends StateNotifier<AsyncValue<WeeklyGoalState>> {
  final WeeklyGoalRepository _repository;
  final Ref _ref;

  WeeklyGoalController(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final s = await _repository.load();
      state = AsyncValue.data(s);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Call once per completed hand. Resets count if a new week has started.
  void recordHand() {
    state.whenData((current) async {
      final now = DateTime.now();
      final monday = _mondayOfWeek(now);

      final bool newWeek = current.weekStartDate != monday;

      // Reset on new week; cap at target to avoid runaway counts.
      final newHands = newWeek
          ? 1
          : (current.handsThisWeek + 1)
              .clamp(0, RetentionConfig.kWeeklyHandTarget);

      final updated = WeeklyGoalState(
        handsThisWeek: newHands,
        weekStartDate: monday,
        rewardClaimed: newWeek ? false : current.rewardClaimed,
      );

      state = AsyncValue.data(updated);
      await _repository.save(updated);
    });
  }

  /// Awards the weekly reward. No-op if not eligible.
  Future<void> claimReward() async {
    state.whenData((current) async {
      if (!current.canClaim) return;

      final claimed = current.copyWith(rewardClaimed: true);
      state = AsyncValue.data(claimed);
      await _repository.save(claimed);

      await _ref
          .read(economyControllerProvider.notifier)
          .addCoins(RetentionConfig.kWeeklyRewardCoins);
      await _ref
          .read(progressionControllerProvider.notifier)
          .awardXP(RetentionConfig.kWeeklyRewardXP);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns the ISO YYYY-MM-DD string for the Monday of [date]'s week.
  String _mondayOfWeek(DateTime date) {
    // DateTime.weekday: Monday=1 … Sunday=7
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return _dateStr(monday);
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final weeklyGoalControllerProvider = StateNotifierProvider<WeeklyGoalController,
    AsyncValue<WeeklyGoalState>>((ref) {
  final repo = ref.watch(weeklyGoalRepositoryProvider);
  return WeeklyGoalController(repo, ref);
});
