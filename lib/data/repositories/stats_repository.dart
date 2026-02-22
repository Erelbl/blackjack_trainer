import '../stats_state.dart';

abstract class StatsRepository {
  Future<StatsState> load();
  Future<void> save(StatsState stats);
  Future<void> reset();
}
