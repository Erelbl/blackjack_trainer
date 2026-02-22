import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../engine/game/game_state.dart';
import '../repositories/shared_prefs_stats_repository.dart';
import '../repositories/stats_repository.dart';
import '../stats_state.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    throw Exception('SharedPreferences not initialized');
  }
  return SharedPrefsStatsRepository(prefs);
});

class StatsController extends StateNotifier<AsyncValue<StatsState>> {
  final StatsRepository _repository;

  StatsController(this._repository) : super(const AsyncValue.loading()) {
    _loadStats();
  }

  Future<void> _loadStats() async {
    state = const AsyncValue.loading();
    try {
      final stats = await _repository.load();
      state = AsyncValue.data(stats);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> recordRound(GameState outcome) async {
    state.whenData((currentStats) async {
      StatsState newStats = currentStats.copyWith(
        handsPlayed: currentStats.handsPlayed + 1,
      );

      switch (outcome) {
        case GameState.playerBlackjack:
          newStats = newStats.copyWith(
            playerBlackjacks: currentStats.playerBlackjacks + 1,
            playerWins: currentStats.playerWins + 1,
          );
          break;
        case GameState.playerWin:
          newStats = newStats.copyWith(
            playerWins: currentStats.playerWins + 1,
          );
          break;
        case GameState.dealerWin:
          newStats = newStats.copyWith(
            dealerWins: currentStats.dealerWins + 1,
          );
          break;
        case GameState.playerBust:
          newStats = newStats.copyWith(
            playerBusts: currentStats.playerBusts + 1,
            dealerWins: currentStats.dealerWins + 1,
          );
          break;
        case GameState.dealerBust:
          newStats = newStats.copyWith(
            dealerBusts: currentStats.dealerBusts + 1,
            playerWins: currentStats.playerWins + 1,
          );
          break;
        case GameState.push:
          newStats = newStats.copyWith(
            pushes: currentStats.pushes + 1,
          );
          break;
        default:
          return; // Not a terminal state
      }

      state = AsyncValue.data(newStats);
      await _repository.save(newStats);
    });
  }

  Future<void> reset() async {
    await _repository.reset();
    state = AsyncValue.data(StatsState.initial());
  }
}

final statsControllerProvider =
    StateNotifierProvider<StatsController, AsyncValue<StatsState>>((ref) {
  final repository = ref.watch(statsRepositoryProvider);
  return StatsController(repository);
});
