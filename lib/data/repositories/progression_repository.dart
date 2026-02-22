import '../models/progression_state.dart';

abstract class ProgressionRepository {
  Future<ProgressionState> load();
  Future<void> save(ProgressionState progression);
}
