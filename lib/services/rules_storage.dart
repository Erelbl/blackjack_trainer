import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/config/blackjack_rules.dart';

/// Persists [BlackjackRules] to SharedPreferences.
///
/// All methods are static; no instance required.
/// Falls back silently to null / no-op on any error.
abstract final class RulesStorage {
  static const _key = 'blackjack_rules_v1';

  static Future<BlackjackRules?> loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null) return null;
      return BlackjackRules.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRules(BlackjackRules rules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(rules.toJson()));
    } catch (_) {}
  }

  static Future<void> clearRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
