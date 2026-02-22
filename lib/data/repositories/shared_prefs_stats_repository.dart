import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../stats_state.dart';
import 'stats_repository.dart';

class SharedPrefsStatsRepository implements StatsRepository {
  static const String _key = 'stats_state';
  final SharedPreferences _prefs;

  SharedPrefsStatsRepository(this._prefs);

  @override
  Future<StatsState> load() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) {
        return StatsState.initial();
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return StatsState.fromJson(json);
    } catch (e) {
      return StatsState.initial();
    }
  }

  @override
  Future<void> save(StatsState stats) async {
    try {
      final jsonString = jsonEncode(stats.toJson());
      await _prefs.setString(_key, jsonString);
    } catch (e) {
      // Log error but don't crash
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _prefs.remove(_key);
    } catch (e) {
      // Log error but don't crash
    }
  }
}
