import '../../engine/config/retention_config.dart';

/// Tracks the player's weekly hand-count goal.
///
/// Resets every Monday (local time). Persisted via SharedPreferences.
class WeeklyGoalState {
  /// Hands played since the start of the current calendar week.
  final int handsThisWeek;

  /// ISO date string (YYYY-MM-DD) of the Monday that started this week.
  final String weekStartDate;

  /// True once the player has claimed this week's completion reward.
  final bool rewardClaimed;

  const WeeklyGoalState({
    required this.handsThisWeek,
    required this.weekStartDate,
    required this.rewardClaimed,
  });

  factory WeeklyGoalState.initial() {
    return const WeeklyGoalState(
      handsThisWeek: 0,
      weekStartDate: '',
      rewardClaimed: false,
    );
  }

  factory WeeklyGoalState.fromJson(Map<String, dynamic> json) {
    return WeeklyGoalState(
      handsThisWeek: json['handsThisWeek'] as int? ?? 0,
      weekStartDate: json['weekStartDate'] as String? ?? '',
      rewardClaimed: json['rewardClaimed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'handsThisWeek': handsThisWeek,
        'weekStartDate': weekStartDate,
        'rewardClaimed': rewardClaimed,
      };

  WeeklyGoalState copyWith({
    int? handsThisWeek,
    String? weekStartDate,
    bool? rewardClaimed,
  }) {
    return WeeklyGoalState(
      handsThisWeek: handsThisWeek ?? this.handsThisWeek,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }

  // ---------------------------------------------------------------------------
  // Computed helpers
  // ---------------------------------------------------------------------------

  /// True when the target has been reached.
  bool get isComplete => handsThisWeek >= RetentionConfig.kWeeklyHandTarget;

  /// True when the reward is available to claim (complete but not yet claimed).
  bool get canClaim => isComplete && !rewardClaimed;

  /// Progress as a 0.0–1.0 fraction toward [RetentionConfig.kWeeklyHandTarget].
  double get progress =>
      (handsThisWeek / RetentionConfig.kWeeklyHandTarget).clamp(0.0, 1.0);
}
