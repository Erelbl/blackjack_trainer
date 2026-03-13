import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper around FirebaseAnalytics.
///
/// All event names are hard-coded snake_case constants to satisfy Firebase's
/// 40-char / alphanumeric+underscore constraint.  Parameter values are
/// int, double, or String only (JSON-safe primitives).
///
/// Usage:
///   AnalyticsService.instance.logGameStart();
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  // ---------------------------------------------------------------------------
  // App lifecycle
  // ---------------------------------------------------------------------------

  Future<void> logAppOpen() => _fa.logAppOpen();

  Future<void> logHomeOpen() => _log('home_open');

  // ---------------------------------------------------------------------------
  // Play screen
  // ---------------------------------------------------------------------------

  Future<void> logGameStart() => _log('game_start');

  Future<void> logGameEnd({
    required int handsPlayed,
    required int coinsDelta,
    required double winRate,
  }) =>
      _log('game_end', {
        'hands_played': handsPlayed,
        'coins_delta': coinsDelta,
        'win_rate': winRate,
      });

  // ---------------------------------------------------------------------------
  // Trainer screen
  // ---------------------------------------------------------------------------

  Future<void> logTrainerOpen() => _log('trainer_open');

  Future<void> logStrategyTableOpen() => _log('strategy_table_open');

  // ---------------------------------------------------------------------------
  // Counting screen
  // ---------------------------------------------------------------------------

  Future<void> logCountingSessionStart({required int durationSeconds}) =>
      _log('counting_session_start', {'duration_seconds': durationSeconds});

  Future<void> logCountingSessionEnd({
    required int durationSeconds,
    required int score,
  }) =>
      _log('counting_session_end', {
        'duration_seconds': durationSeconds,
        'score': score,
      });

  // ---------------------------------------------------------------------------
  // Speed Drill
  // ---------------------------------------------------------------------------

  Future<void> logSpeedDrillStart() => _log('speed_drill_start');

  Future<void> logSpeedDrillEnd({
    required int score,
    required int durationSeconds,
    required int correctAnswers,
    required int totalAnswers,
  }) =>
      _log('speed_drill_end', {
        'score': score,
        'duration_seconds': durationSeconds,
        'correct_answers': correctAnswers,
        'total_answers': totalAnswers,
      });

  // ---------------------------------------------------------------------------
  // Daily Drill
  // ---------------------------------------------------------------------------

  Future<void> logDailyDrillStart() => _log('daily_drill_start');

  Future<void> logDailyDrillEnd({
    required int score,
    required int durationSeconds,
    required int completed,
  }) =>
      _log('daily_drill_end', {
        'score': score,
        'duration_seconds': durationSeconds,
        'completed': completed,
      });

  // ---------------------------------------------------------------------------
  // Stats / Achievements
  // ---------------------------------------------------------------------------

  Future<void> logAchievementsOpen() => _log('achievements_open');

  // ---------------------------------------------------------------------------
  // Play session
  // ---------------------------------------------------------------------------

  Future<void> logSessionSummaryShown() => _log('session_summary_shown');

  // ---------------------------------------------------------------------------
  // Daily challenges
  // ---------------------------------------------------------------------------

  Future<void> logDailyChallengesOpen() => _log('daily_challenges_open');

  // ---------------------------------------------------------------------------
  // Store / monetisation
  // ---------------------------------------------------------------------------

  Future<void> logShopOpen() => _log('shop_open');

  Future<void> logRewardedAdAttempt() => _log('rewarded_ad_attempt');

  Future<void> logRewardedAdRewarded() => _log('rewarded_ad_rewarded');

  Future<void> logIapPurchaseSuccess({required String productId}) =>
      _log('iap_purchase_success', {'product_id': productId});

  // ---------------------------------------------------------------------------
  // Internal helper
  // ---------------------------------------------------------------------------

  Future<void> _log(
    String eventName, [
    Map<String, Object>? parameters,
  ]) =>
      _fa.logEvent(name: eventName, parameters: parameters);
}
