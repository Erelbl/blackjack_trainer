import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievement_definitions.dart';
import 'challenge_definitions.dart';
import 'rank_system.dart';

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kDailyDate          = 'pm_daily_date';
const _kDailySelected      = 'pm_daily_selected';
const _kDailyProgress      = 'pm_daily_progress';
const _kDailyClaimed       = 'pm_daily_claimed';
const _kRankXp             = 'pm_rank_xp';
const _kAchUnlocked        = 'pm_achievements_unlocked';
const _kAchNew             = 'pm_achievements_new';
const _kLifeHandsPlayed    = 'pm_life_hands_played';
const _kLifeHandsWon       = 'pm_life_hands_won';
const _kLifeTrainerAnswered = 'pm_life_trainer_answered';
const _kLifeTrainerCorrect = 'pm_life_trainer_correct';
const _kLifeTestsPassed    = 'pm_life_tests_passed';
const _kLifeTests85        = 'pm_life_tests_85';
const _kLifeTests95        = 'pm_life_tests_95';
const _kLifeDailiesClaimed = 'pm_life_dailies_claimed';
const _kSessionXpDate      = 'pm_session_xp_date';
const _kSessionXpEarned    = 'pm_session_xp_earned';

const int _kMaxSessionXpPerDay = 20;

/// Reward returned by [ProgressionManager.claimDaily].
/// The caller is responsible for applying coins to the economy.
class ChallengeReward {
  final int coins;
  final int xp;
  const ChallengeReward({required this.coins, required this.xp});
}

/// Standalone singleton for daily challenges, rank XP, and achievements.
///
/// Initialize once at startup:
/// ```dart
/// await ProgressionManager.instance.init();
/// ```
///
/// Then call event hooks from gameplay code:
/// ```dart
/// ProgressionManager.instance.onGameHandPlayed();
/// ProgressionManager.instance.onGameHandWon();
/// ProgressionManager.instance.onTrainerAnswer(correct: true);
/// ProgressionManager.instance.onTrainerTestCompleted(accuracy: 0.9);
/// ```
class ProgressionManager extends ChangeNotifier {
  ProgressionManager._();
  static final ProgressionManager instance = ProgressionManager._();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // ── Daily state ───────────────────────────────────────────────────────────
  String _dailyDate = '';
  List<String> _dailySelected = [];
  Map<String, int> _dailyProgress = {};
  Set<String> _dailyClaimed = {};

  // ── Rank state ─────────────────────────────────────────────────────────────
  int _rankXp = 0;

  // ── Achievement state ─────────────────────────────────────────────────────
  Set<String> _achUnlocked = {};
  Set<String> _achNew = {};

  // ── Lifetime stats (for achievement checks) ───────────────────────────────
  int _lifeHandsPlayed = 0;
  int _lifeHandsWon = 0;
  int _lifeTrainerAnswered = 0;
  int _lifeTrainerCorrect = 0;
  int _lifeTestsPassed = 0;
  int _lifeTests85 = 0;
  int _lifeTests95 = 0;
  int _lifeDailiesClaimed = 0;

  // ── Game session XP cap ───────────────────────────────────────────────────
  String _sessionXpDate = '';
  int _sessionXpEarned = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _load();
    _initialized = true;
  }

  /// Call when the app returns to foreground or Home is revisited.
  ///
  /// Re-runs the daily load/reset routine if the calendar day has changed
  /// since last init or last call.  Idempotent and fast when the day is
  /// unchanged.
  void ensureDailyReset() {
    if (!_initialized) return;
    if (_dailyDate == _todayStr()) return;
    _loadDaily();
    notifyListeners();
  }

  /// Today's 3 selected challenges (1 game, 1 trainer, 1 general).
  List<ChallengeDefinition> get todaysChallenges {
    return _dailySelected
        .map(ChallengeDefinitions.findById)
        .whereType<ChallengeDefinition>()
        .toList();
  }

  int getDailyProgress(String id) => _dailyProgress[id] ?? 0;

  bool isDailyClaimed(String id) => _dailyClaimed.contains(id);

  bool isDailyComplete(String id) {
    final def = ChallengeDefinitions.findById(id);
    if (def == null) return false;
    return getDailyProgress(id) >= def.target;
  }

  int getRankXp() => _rankXp;
  String getRankTier() => RankSystem.getTierName(_rankXp);
  double getRankProgressPercent() => RankSystem.getProgressInTier(_rankXp);

  bool isAchievementUnlocked(String id) => _achUnlocked.contains(id);

  List<String> getNewAchievements() => _achNew.toList();

  void markAchievementSeen(String id) {
    if (_achNew.remove(id)) {
      _prefs?.setStringList(_kAchNew, _achNew.toList());
      notifyListeners();
    }
  }

  /// Claims the daily challenge with [id].
  ///
  /// Returns the reward (coins + XP) on first claim, or null if:
  /// - already claimed (idempotent)
  /// - not yet complete
  /// - not initialized
  ///
  /// The caller must apply [ChallengeReward.coins] to the economy.
  /// Rank XP from [ChallengeReward.xp] is applied internally.
  Future<ChallengeReward?> claimDaily(String id) async {
    if (!_initialized) return null;
    if (_dailyClaimed.contains(id)) return null;
    final def = ChallengeDefinitions.findById(id);
    if (def == null) return null;
    if (getDailyProgress(id) < def.target) return null;

    _dailyClaimed.add(id);
    _lifeDailiesClaimed++;
    _rankXp += def.rewardXp;

    _prefs?.setStringList(_kDailyClaimed, _dailyClaimed.toList());
    _prefs?.setInt(_kLifeDailiesClaimed, _lifeDailiesClaimed);
    _prefs?.setInt(_kRankXp, _rankXp);

    _checkAchievements();
    notifyListeners();
    return ChallengeReward(coins: def.rewardCoins, xp: def.rewardXp);
  }

  // ── Event hooks ───────────────────────────────────────────────────────────

  void onGameHandPlayed() {
    if (!_initialized) return;
    _lifeHandsPlayed++;
    _prefs?.setInt(_kLifeHandsPlayed, _lifeHandsPlayed);
    _maybeAddSessionXp();
    _incrementDailyProgress([
      ChallengeTrackingType.handsPlayed,
      ChallengeTrackingType.anyActivity,
    ]);
    _checkAchievements();
    notifyListeners();
  }

  void onGameHandWon() {
    if (!_initialized) return;
    _lifeHandsWon++;
    _prefs?.setInt(_kLifeHandsWon, _lifeHandsWon);
    _incrementDailyProgress([ChallengeTrackingType.winHands]);
    _checkAchievements();
    notifyListeners();
  }

  void onTrainerAnswer({required bool correct}) {
    if (!_initialized) return;
    _lifeTrainerAnswered++;
    _prefs?.setInt(_kLifeTrainerAnswered, _lifeTrainerAnswered);
    if (correct) {
      _lifeTrainerCorrect++;
      _prefs?.setInt(_kLifeTrainerCorrect, _lifeTrainerCorrect);
      _incrementDailyProgress([ChallengeTrackingType.trainerCorrect]);
    }
    _incrementDailyProgress([
      ChallengeTrackingType.trainerAnswered,
      ChallengeTrackingType.anyActivity,
    ]);
    _checkAchievements();
    notifyListeners();
  }

  void onTrainerTestCompleted({required double accuracy}) {
    if (!_initialized) return;
    _lifeTestsPassed++;
    _prefs?.setInt(_kLifeTestsPassed, _lifeTestsPassed);

    // Rank XP from test: 50 base × multiplier
    final double multiplier = accuracy >= 0.95
        ? 1.5
        : accuracy >= 0.85
            ? 1.25
            : accuracy >= 0.70
                ? 1.0
                : 0.5;
    _rankXp += (50 * multiplier).round();
    _prefs?.setInt(_kRankXp, _rankXp);

    if (accuracy >= 0.70) {
      _incrementDailyProgress([ChallengeTrackingType.testAccuracy70]);
    }
    if (accuracy >= 0.85) {
      _lifeTests85++;
      _prefs?.setInt(_kLifeTests85, _lifeTests85);
      _incrementDailyProgress([ChallengeTrackingType.testAccuracy85]);
    }
    if (accuracy >= 0.95) {
      _lifeTests95++;
      _prefs?.setInt(_kLifeTests95, _lifeTests95);
      _incrementDailyProgress([ChallengeTrackingType.testAccuracy95]);
    }
    _checkAchievements();
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _load() {
    final p = _prefs!;
    _rankXp = p.getInt(_kRankXp) ?? 0;
    _achUnlocked = Set.from(p.getStringList(_kAchUnlocked) ?? []);
    _achNew = Set.from(p.getStringList(_kAchNew) ?? []);
    _lifeHandsPlayed = p.getInt(_kLifeHandsPlayed) ?? 0;
    _lifeHandsWon = p.getInt(_kLifeHandsWon) ?? 0;
    _lifeTrainerAnswered = p.getInt(_kLifeTrainerAnswered) ?? 0;
    _lifeTrainerCorrect = p.getInt(_kLifeTrainerCorrect) ?? 0;
    _lifeTestsPassed = p.getInt(_kLifeTestsPassed) ?? 0;
    _lifeTests85 = p.getInt(_kLifeTests85) ?? 0;
    _lifeTests95 = p.getInt(_kLifeTests95) ?? 0;
    _lifeDailiesClaimed = p.getInt(_kLifeDailiesClaimed) ?? 0;
    _sessionXpDate = p.getString(_kSessionXpDate) ?? '';
    _sessionXpEarned = p.getInt(_kSessionXpEarned) ?? 0;
    _loadDaily();
  }

  /// Loads today's daily state, with full recovery on any format error.
  ///
  /// [recovered] prevents infinite recursion: the catch block re-calls with
  /// recovered=true, which skips the try and just sets fresh state.
  void _loadDaily({bool recovered = false}) {
    final p = _prefs!;
    try {
      final today = _todayStr();
      final storedDate = _safeGetString(p, _kDailyDate) ?? '';

      if (storedDate != today) {
        // New day — previous selected IDs used for rotation (JSON string).
        final prevIds = _safeGetJsonStringList(p, _kDailySelected);
        _selectNewChallenges(prevIds);
        _dailyDate = today;
        _dailyProgress = {};
        _dailyClaimed = {};
        _persistDailySync();
      } else {
        _dailyDate = storedDate;
        _dailySelected = _safeGetJsonStringList(p, _kDailySelected);
        _dailyProgress = _safeGetJsonIntMap(p, _kDailyProgress);
        _dailyClaimed = _safeGetClaimedSet(p);
      }
    } catch (e) {
      if (recovered) return; // safety: never recurse twice
      if (kDebugMode) {
        debugPrint('[Daily] prefs corrupted; resetting pm_daily_*: $e');
      }
      p.remove(_kDailyDate);
      p.remove(_kDailySelected);
      p.remove(_kDailyProgress);
      p.remove(_kDailyClaimed);
      // Initialise fresh state without recursing.
      _selectNewChallenges([]);
      _dailyDate = _todayStr();
      _dailyProgress = {};
      _dailyClaimed = {};
      _persistDailySync();
    }
  }

  // ── Safe SharedPreferences readers (never throw) ───────────────────────────

  /// Returns the raw String value, or null if absent or wrong type.
  String? _safeGetString(SharedPreferences p, String key) {
    final v = p.get(key);
    return v is String ? v : null;
  }

  /// Reads a JSON-encoded list-of-strings; accepts both String and StringList.
  List<String> _safeGetJsonStringList(SharedPreferences p, String key) {
    final v = p.get(key);
    if (v is List) return v.whereType<String>().toList();
    if (v is String) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d.whereType<String>().toList();
      } catch (_) {}
    }
    return [];
  }

  /// Reads a JSON-encoded String→int map; accepts both String and Map.
  Map<String, int> _safeGetJsonIntMap(SharedPreferences p, String key) {
    final v = p.get(key);
    Map<String, dynamic>? m;
    if (v is Map) {
      m = v.map((k, val) => MapEntry(k.toString(), val));
    } else if (v is String) {
      try {
        final d = jsonDecode(v);
        if (d is Map) m = d.map((k, val) => MapEntry(k.toString(), val));
      } catch (_) {}
    }
    if (m == null) return {};
    return m.map((k, val) => MapEntry(k, (val as num).toInt()));
  }

  /// Reads pm_daily_claimed; tolerates StringList or legacy JSON-string.
  Set<String> _safeGetClaimedSet(SharedPreferences p) {
    if (!p.containsKey(_kDailyClaimed)) return {};
    final v = p.get(_kDailyClaimed);
    if (v is List) return v.whereType<String>().toSet();
    if (v is String) {
      try {
        final d = jsonDecode(v);
        if (d is List) return d.whereType<String>().toSet();
      } catch (_) {}
    }
    return {};
  }

  void _selectNewChallenges(List<String> prevIds) {
    final prevSet = prevIds.toSet();

    List<ChallengeDefinition> eligible(List<ChallengeDefinition> pool) {
      final filtered = pool.where((c) => !prevSet.contains(c.id)).toList();
      return filtered.isNotEmpty ? filtered : pool;
    }

    final game = eligible(ChallengeDefinitions.gameList);
    final trainer = eligible(ChallengeDefinitions.trainerList);
    final general = eligible(ChallengeDefinitions.generalList);

    // Seed by days-since-epoch for stable same-day selection.
    final seed = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    _dailySelected = [
      game[seed % game.length].id,
      trainer[(seed + 1) % trainer.length].id,
      general[(seed + 2) % general.length].id,
    ];
  }

  void _persistDailySync() {
    final p = _prefs!;
    p.setString(_kDailyDate, _dailyDate);
    p.setString(_kDailySelected, jsonEncode(_dailySelected));
    p.setString(_kDailyProgress, jsonEncode(_dailyProgress));
    p.setStringList(_kDailyClaimed, _dailyClaimed.toList());
  }

  void _maybeAddSessionXp() {
    final today = _todayStr();
    if (_sessionXpDate != today) {
      _sessionXpDate = today;
      _sessionXpEarned = 0;
    }
    if (_sessionXpEarned < _kMaxSessionXpPerDay) {
      _sessionXpEarned++;
      _rankXp++;
      _prefs?.setInt(_kRankXp, _rankXp);
      _prefs?.setString(_kSessionXpDate, _sessionXpDate);
      _prefs?.setInt(_kSessionXpEarned, _sessionXpEarned);
    }
  }

  void _incrementDailyProgress(List<ChallengeTrackingType> types) {
    bool changed = false;
    for (final c in todaysChallenges) {
      if (_dailyClaimed.contains(c.id)) continue;
      if (!types.contains(c.trackingType)) continue;
      final current = _dailyProgress[c.id] ?? 0;
      if (current < c.target) {
        _dailyProgress[c.id] = current + 1;
        changed = true;
      }
    }
    if (changed) {
      _prefs?.setString(_kDailyProgress, jsonEncode(_dailyProgress));
    }
  }

  void _checkAchievements() {
    final anyTotal = _lifeHandsPlayed + _lifeTrainerAnswered;
    bool anyNew = false;
    for (final ach in AchievementDefinitions.all) {
      if (_achUnlocked.contains(ach.id)) continue;
      final value = _statForCondition(ach.conditionType, anyTotal);
      if (value >= ach.threshold) {
        _achUnlocked.add(ach.id);
        _achNew.add(ach.id);
        anyNew = true;
      }
    }
    if (anyNew) {
      _prefs?.setStringList(_kAchUnlocked, _achUnlocked.toList());
      _prefs?.setStringList(_kAchNew, _achNew.toList());
    }
  }

  int _statForCondition(AchievementConditionType type, int anyTotal) {
    return switch (type) {
      AchievementConditionType.handsPlayed       => _lifeHandsPlayed,
      AchievementConditionType.handsWon          => _lifeHandsWon,
      AchievementConditionType.trainerAnswered   => _lifeTrainerAnswered,
      AchievementConditionType.trainerCorrect    => _lifeTrainerCorrect,
      AchievementConditionType.testsPassed       => _lifeTestsPassed,
      AchievementConditionType.testsAtAccuracy85 => _lifeTests85,
      AchievementConditionType.testsAtAccuracy95 => _lifeTests95,
      AchievementConditionType.dailiesClaimed    => _lifeDailiesClaimed,
      AchievementConditionType.anyTotal          => anyTotal,
    };
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
