import 'dart:math';

class ProgressionState {
  final int xp;
  final int level;
  final int currentStreak;
  final String? lastLoginDate; // ISO 8601 format (YYYY-MM-DD)
  final List<int> milestonesUnlocked; // List of milestone hand counts

  const ProgressionState({
    required this.xp,
    required this.level,
    required this.currentStreak,
    this.lastLoginDate,
    required this.milestonesUnlocked,
  });

  factory ProgressionState.initial() {
    return const ProgressionState(
      xp: 0,
      level: 1,
      currentStreak: 0,
      lastLoginDate: null,
      milestonesUnlocked: [],
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'xp': xp,
      'level': level,
      'currentStreak': currentStreak,
      'lastLoginDate': lastLoginDate,
      'milestonesUnlocked': milestonesUnlocked,
    };
  }

  ProgressionState copyWith({
    int? xp,
    int? level,
    int? currentStreak,
    String? lastLoginDate,
    List<int>? milestonesUnlocked,
  }) {
    return ProgressionState(
      xp: xp ?? this.xp,
      level: level ?? this.level,
      currentStreak: currentStreak ?? this.currentStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      milestonesUnlocked: milestonesUnlocked ?? this.milestonesUnlocked,
    );
  }

  // Calculate XP required for next level
  int get xpForNextLevel => (100 * pow(level + 1, 1.5)).toInt();

  // Progress to next level (0.0 to 1.0)
  double get progressToNextLevel {
    if (xpForNextLevel == 0) return 0;
    return xp / xpForNextLevel;
  }

  // Get daily reward based on streak (7-day cycle)
  int get dailyRewardCoins {
    final day = (currentStreak % 7) + 1; // 1-7
    return switch (day) {
      1 => 100,
      2 => 150,
      3 => 200,
      4 => 250,
      5 => 300,
      6 => 400,
      7 => 500,
      _ => 100,
    };
  }

  bool hasMilestone(int handCount) => milestonesUnlocked.contains(handCount);
}
