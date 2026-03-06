/// Rank tier definitions with exponential XP thresholds.
class RankTier {
  final String name;
  final int xpRequired;
  const RankTier(this.name, this.xpRequired);
}

class RankSystem {
  RankSystem._();

  static const List<RankTier> tiers = [
    RankTier('Bronze I',     0),
    RankTier('Bronze II',    100),
    RankTier('Bronze III',   250),
    RankTier('Silver I',     500),
    RankTier('Silver II',    900),
    RankTier('Silver III',   1400),
    RankTier('Gold I',       2000),
    RankTier('Gold II',      2800),
    RankTier('Gold III',     3800),
    RankTier('Platinum I',   5000),
    RankTier('Platinum II',  6500),
    RankTier('Platinum III', 8200),
    RankTier('Master',       10000),
  ];

  static String getTierName(int xp) {
    String name = tiers.first.name;
    for (final t in tiers) {
      if (xp >= t.xpRequired) name = t.name;
    }
    return name;
  }

  /// Returns 0.0–1.0 progress within the current tier toward the next.
  static double getProgressInTier(int xp) {
    int lo = 0;
    int hi = tiers.last.xpRequired + 2000; // Master overflow segment
    for (int i = 0; i < tiers.length; i++) {
      if (xp >= tiers[i].xpRequired) {
        lo = tiers[i].xpRequired;
        hi = (i + 1 < tiers.length) ? tiers[i + 1].xpRequired : lo + 2000;
      }
    }
    if (hi == lo) return 1.0;
    return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
  }
}
