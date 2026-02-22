import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../data/providers/stats_providers.dart';
import '../models/item_type.dart';
import '../models/store_item.dart';
import '../repositories/shared_prefs_store_repository.dart';
import '../repositories/store_repository.dart';
import '../state/store_state.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    throw Exception('SharedPreferences not initialized');
  }
  return SharedPrefsStoreRepository(prefs);
});

class StoreController extends StateNotifier<AsyncValue<StoreState>> {
  final StoreRepository _repository;
  final Ref _ref;

  StoreController(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _loadStore();
  }

  Future<void> _loadStore() async {
    state = const AsyncValue.loading();
    try {
      final store = await _repository.load();
      state = AsyncValue.data(store);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<String?> buyItem(StoreItem item) async {
    return state.whenData((currentStore) async {
      // Check if already owned
      if (currentStore.ownsItem(item.id)) {
        return 'Already owned';
      }

      // Check if enough coins
      final economyState = _ref.read(economyControllerProvider).value;
      if (economyState == null) {
        return 'Economy not loaded';
      }

      if (economyState.coins < item.price) {
        return 'Insufficient coins';
      }

      // Deduct coins
      await _ref
          .read(economyControllerProvider.notifier)
          .addCoins(-item.price);

      // Add to owned items
      final newOwnedItems = [...currentStore.ownedItemIds, item.id];
      final newStore = currentStore.copyWith(ownedItemIds: newOwnedItems);

      state = AsyncValue.data(newStore);
      await _repository.save(newStore);

      return null; // Success
    }).value;
  }

  Future<void> selectItem(StoreItem item) async {
    state.whenData((currentStore) async {
      // Must own item to select it
      if (!currentStore.ownsItem(item.id)) {
        return;
      }

      StoreState newStore;
      switch (item.type) {
        case ItemType.cardSkin:
          newStore = currentStore.copyWith(selectedCardSkin: item.id);
          break;
        case ItemType.tableTheme:
          newStore = currentStore.copyWith(selectedTableTheme: item.id);
          break;
        case ItemType.dealerSkin:
          newStore = currentStore.copyWith(selectedDealerSkin: item.id);
          break;
      }

      state = AsyncValue.data(newStore);
      await _repository.save(newStore);
    });
  }
}

final storeControllerProvider =
    StateNotifierProvider<StoreController, AsyncValue<StoreState>>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  return StoreController(repository, ref);
});
