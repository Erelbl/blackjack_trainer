import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/progression_state.dart';
import 'progression_repository.dart';

class SharedPrefsProgressionRepository implements ProgressionRepository {
  static const String _key = 'progression_state';
  final SharedPreferences _prefs;

  SharedPrefsProgressionRepository(this._prefs);

  @override
  Future<ProgressionState> load() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) {
        return ProgressionState.initial();
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ProgressionState.fromJson(json);
    } catch (e) {
      return ProgressionState.initial();
    }
  }

  @override
  Future<void> save(ProgressionState progression) async {
    try {
      final jsonString = jsonEncode(progression.toJson());
      await _prefs.setString(_key, jsonString);
    } catch (e) {
      // Log error but don't crash
    }
  }
}
