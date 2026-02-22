import '../state/store_state.dart';

abstract class StoreRepository {
  Future<StoreState> load();
  Future<void> save(StoreState store);
}
