/// Central constants for retention UX: weekly goals, level-up rewards, and
/// daily streak rewards.
///
/// Keep all tunable values here so they're easy to adjust without hunting
/// through multiple files.
class RetentionConfig {
  RetentionConfig._();

  // ---------------------------------------------------------------------------
  // Daily streak reward
  // ---------------------------------------------------------------------------

  /// Coins awarded each day of the 7-day daily streak cycle.
  /// Index 0 = Day 1, index 6 = Day 7.
  static const List<int> kDailyRewards = [
    150,  // Day 1
    200,  // Day 2
    275,  // Day 3
    350,  // Day 4
    450,  // Day 5
    575,  // Day 6
    700,  // Day 7
  ];

  // ---------------------------------------------------------------------------
  // Weekly goal
  // ---------------------------------------------------------------------------

  /// Hands the player must play in a calendar week to earn the weekly reward.
  static const int kWeeklyHandTarget = 80;

  /// Coins awarded on weekly goal claim.
  static const int kWeeklyRewardCoins = 1500;

  /// XP awarded on weekly goal claim.
  static const int kWeeklyRewardXP = 50;

  // ---------------------------------------------------------------------------
  // Level-up reward
  // ---------------------------------------------------------------------------

  // kLevelUpCoins removed — replaced by progression_utils.levelUpCoins(level)
  // which uses the formula 150 + (10 × level) for inflation control.

  /// Every N levels the player earns an extra milestone bonus on top of the
  /// per-level award.  Set to 0 to disable milestone bonuses.
  static const int kMilestoneLevelInterval = 5;

  /// Extra coins awarded at milestone levels (in addition to the per-level
  /// amount from progression_utils.levelUpCoins).
  static const int kMilestoneLevelBonusCoins = 500;

  // ---------------------------------------------------------------------------
  // Ad rewards
  // ---------------------------------------------------------------------------

  /// Coins granted by the optional bonus ad (Store / IAP screen).
  static const int kBonusAdRewardCoins = 30;

  /// Coins granted by a "revive" ad when the player has 0 coins.
  /// Covers at least 20 minimum-bet hands (min bet = 5).
  static const int kReviveAdRewardCoins = 100;

  /// Maximum number of revive ads the player may watch per calendar day.
  static const int kMaxRevivesPerDay = 3;
}
