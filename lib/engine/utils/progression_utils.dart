import 'dart:math';

// ---------------------------------------------------------------------------
// XP Curve — exponential level thresholds
//
// Single source of truth for all leveling math.  Import this wherever you
// need XP → level or level → display progress.
// ---------------------------------------------------------------------------

/// XP required to advance FROM [level] TO [level + 1].
///
/// Formula: round(200 × 1.28^(level − 1))
///   Level 1 → 2: 200 XP
///   Level 2 → 3: 256 XP
///   Level 5 → 6: 537 XP
///   Level 10 → 11: 1 844 XP
int xpRequiredForLevel(int level) =>
    (200 * pow(1.28, level - 1)).round();

/// Cumulative XP needed to START [level] (i.e. total XP from 0 to first
/// entering that level).
///
/// Equivalent to: Σ xpRequiredForLevel(i) for i = 1 .. (level − 1)
int totalXpToReachLevel(int level) {
  int total = 0;
  for (int i = 1; i < level; i++) {
    total += xpRequiredForLevel(i);
  }
  return total;
}

/// Derives the current level from [totalXp] using the exponential curve.
///
/// O(level) — iterates upward until the cumulative XP budget is exhausted.
int levelFromTotalXp(int totalXp) {
  int level = 1;
  int cumulative = 0;
  while (true) {
    final needed = xpRequiredForLevel(level);
    if (totalXp < cumulative + needed) break;
    cumulative += needed;
    level++;
  }
  return level;
}

/// Coins awarded when the player reaches [level].
///
/// Formula: 150 + (10 × level)
///   Level 2:  170 coins
///   Level 5:  200 coins
///   Level 10: 250 coins
///   Level 20: 350 coins
int levelUpCoins(int level) => 150 + (10 * level);
