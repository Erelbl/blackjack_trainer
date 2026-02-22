import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/economy_state.dart';
import 'economy_repository.dart';

class SharedPrefsEconomyRepository implements EconomyRepository {
  static const String _key = 'economy_state';
  final SharedPreferences _prefs;

  SharedPrefsEconomyRepository(this._prefs);

  @override
  Future<EconomyState> load() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) {
        return EconomyState.initial();
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return EconomyState.fromJson(json);
    } catch (e) {
      return EconomyState.initial();
    }
  }

  @override
  Future<void> save(EconomyState economy) async {
    try {
      final jsonString = jsonEncode(economy.toJson());
      await _prefs.setString(_key, jsonString);
    } catch (e) {
      // Log error but don't crash
    }
  }
}
