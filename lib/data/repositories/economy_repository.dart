import '../models/economy_state.dart';

abstract class EconomyRepository {
  Future<EconomyState> load();
  Future<void> save(EconomyState economy);
}
