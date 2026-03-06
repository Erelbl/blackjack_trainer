import '../models/weekly_goal_state.dart';

abstract class WeeklyGoalRepository {
  Future<WeeklyGoalState> load();
  Future<void> save(WeeklyGoalState state);
}
