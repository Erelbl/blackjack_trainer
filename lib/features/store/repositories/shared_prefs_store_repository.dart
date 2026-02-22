import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/store_state.dart';
import 'store_repository.dart';

class SharedPrefsStoreRepository implements StoreRepository {
  static const String _key = 'store_state';
  final SharedPreferences _prefs;

  SharedPrefsStoreRepository(this._prefs);

  @override
  Future<StoreState> load() async {
    try {
      final jsonString = _prefs.getString(_key);
      if (jsonString == null) {
        return StoreState.initial();
      }
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return StoreState.fromJson(json);
    } catch (e) {
      return StoreState.initial();
    }
  }

  @override
  Future<void> save(StoreState store) async {
    try {
      final jsonString = jsonEncode(store.toJson());
      await _prefs.setString(_key, jsonString);
    } catch (e) {
      // Log error but don't crash
    }
  }
}
