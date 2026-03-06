import '../../engine/config/retention_config.dart';
import '../../engine/utils/progression_utils.dart';

// ---------------------------------------------------------------------------
// LevelUpInfo — ephemeral value emitted when the player levels up.
// Not persisted; used only to trigger the level-up toast in the UI.
// ---------------------------------------------------------------------------

/// Details of a level-up event, emitted as [ProgressionState.pendingLevelUpInfo].
///
/// [isMilestone] is true when [level] is divisible by the milestone interval,
/// meaning an extra coin bonus was awarded on top of the standard amount.
class LevelUpInfo {
  final int level;
  final int totalCoins;
  final bool isMilestone;

  const LevelUpInfo({
    required this.level,
    required this.totalCoins,
    required this.isMilestone,
  });
}

class ProgressionState {
  final int xp;
  final int level;
  final int currentStreak;
  final String? lastLoginDate; // ISO 8601 format (YYYY-MM-DD)
  final List<int> milestonesUnlocked; // List of milestone hand counts
  /// Non-null for one frame after a daily login awards coins — used to trigger
  /// the reward dialog.  Cleared by [ProgressionController.clearDailyReward].
  final int? pendingDailyReward;

  /// Non-null immediately after a level-up — used to trigger the level-up toast.
  /// Ephemeral: never persisted.  Cleared by [ProgressionController.clearLevelUp].
  final LevelUpInfo? pendingLevelUpInfo;

  const ProgressionState({
    required this.xp,
    required this.level,
    required this.currentStreak,
    this.lastLoginDate,
    required this.milestonesUnlocked,
    this.pendingDailyReward,
    this.pendingLevelUpInfo,
  });

  factory ProgressionState.initial() {
    return const ProgressionState(
      xp: 0,
      level: 1,
      currentStreak: 0,
      lastLoginDate: null,
      milestonesUnlocked: [],
      pendingDailyReward: null,
      pendingLevelUpInfo: null,
    );
  }

  factory ProgressionState.fromJson(Map<String, dynamic> json) {
    return ProgressionState(
      xp: json['xp'] as int? ?? 0,
      level: json['level'] as int? ?? 1,
      currentStreak: json['currentStreak'] as int? ?? 0,
      lastLoginDate: json['lastLoginDate'] as String?,
      milestonesUnlocked: (json['milestonesUnlocked'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      // Ephemeral fields — never persisted.
      pendingDailyReward: null,
      pendingLevelUpInfo: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp': xp,
      'level': level,
      'currentStreak': currentStreak,
      'lastLoginDate': lastLoginDate,
      'milestonesUnlocked': milestonesUnlocked,
      // pendingDailyReward and pendingLevelUpInfo are ephemeral — omitted.
    };
  }

  ProgressionState copyWith({
    int? xp,
    int? level,
    int? currentStreak,
    String? lastLoginDate,
    List<int>? milestonesUnlocked,
    int? pendingDailyReward,
    // pendingLevelUpInfo intentionally absent — managed via direct construction
    // in ProgressionController (same pattern as pendingDailyReward clearing).
  }) {
    return ProgressionState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      milestonesUnlocked: milestonesUnlocked ?? this.milestonesUnlocked,
      pendingDailyReward: pendingDailyReward ?? this.pendingDailyReward,
      // pendingLevelUpInfo is always preserved by copyWith; clear it with
      // direct construction in the controller.
      pendingLevelUpInfo: pendingLevelUpInfo,
    );
  }

  // ---------------------------------------------------------------------------
  // Level-progress helpers — all backed by progression_utils.dart
  // ---------------------------------------------------------------------------

  /// Progress within the current level (0.0 → 1.0).
  double get levelProgress {
    final start = totalXpToReachLevel(level);
    final end = totalXpToReachLevel(level + 1);
    final range = end - start;
    if (range <= 0) return 0;
    return ((xp - start) / range).clamp(0.0, 1.0);
  }

  /// XP earned within the current level (display: "42 XP").
  int get xpInCurrentLevel =>
      (xp - totalXpToReachLevel(level)).clamp(0, 999999);

  /// XP needed to complete the current level (display: "/ 150 XP").
  int get xpNeededForCurrentLevel {
    final start = totalXpToReachLevel(level);
    final end = totalXpToReachLevel(level + 1);
    return (end - start).clamp(1, 999999);
  }

  // ---------------------------------------------------------------------------
  // Daily reward
  // ---------------------------------------------------------------------------

  /// Coins awarded for the current streak day (index into 7-day cycle).
  ///
  /// Works correctly with both capped streaks (1–7) and legacy data where
  /// [currentStreak] may exceed 7 — modulo keeps it in range.
  int get dailyRewardCoins {
    if (currentStreak == 0) return RetentionConfig.kDailyRewards[0];
    final index = (currentStreak - 1) % 7; // 0-based, safe for any streak value
    return RetentionConfig.kDailyRewards[index];
  }

  bool hasMilestone(int handCount) => milestonesUnlocked.contains(handCount);
}
