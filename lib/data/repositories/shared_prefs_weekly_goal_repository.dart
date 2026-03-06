import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weekly_goal_state.dart';
import 'weekly_goal_repository.dart';

class SharedPrefsWeeklyGoalRepository implements WeeklyGoalRepository {
  static const String _key = 'weekly_goal_state';
  final SharedPreferences _prefs;

  SharedPrefsWeeklyGoalRepository(this._prefs);

  @override
  Future<WeeklyGoalState> load() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) return WeeklyGoalState.initial();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return WeeklyGoalState.fromJson(json);
    } catch (_) {
      return WeeklyGoalState.initial();
    }
  }

  @override
  Future<void> save(WeeklyGoalState state) async {
    try {
      await _prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {
      // Fail silently — never crash on persistence errors.
    }
  }
}
