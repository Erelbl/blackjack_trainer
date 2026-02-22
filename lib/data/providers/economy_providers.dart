import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/economy_state.dart';
import '../repositories/economy_repository.dart';
import '../repositories/shared_prefs_economy_repository.dart';
import 'stats_providers.dart';

final economyRepositoryProvider = Provider<EconomyRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) {
    throw Exception('SharedPreferences not initialized');
  }
  return SharedPrefsEconomyRepository(prefs);
});

class EconomyController extends StateNotifier<AsyncValue<EconomyState>> {
  final EconomyRepository _repository;

  EconomyController(this._repository) : super(const AsyncValue.loading()) {
    _loadEconomy();
  }

  Future<void> _loadEconomy() async {
    state = const AsyncValue.loading();
    try {
      final economy = await _repository.load();
      state = AsyncValue.data(economy);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCoins(int amount) async {
    state.whenData((currentEconomy) async {
      final newEconomy = currentEconomy.copyWith(
        coins: currentEconomy.coins + amount,
      );
      state = AsyncValue.data(newEconomy);
      await _repository.save(newEconomy);
    });
  }

  Future<void> setRemoveAds(bool value) async {
    state.whenData((currentEconomy) async {
      final newEconomy = currentEconomy.copyWith(removeAds: value);
      state = AsyncValue.data(newEconomy);
      await _repository.save(newEconomy);
    });
  }

  Future<void> markPurchaseDelivered(String purchaseId) async {
    state.whenData((currentEconomy) async {
      final newEconomy = currentEconomy.copyWith(
        deliveredPurchaseIds: {
          ...currentEconomy.deliveredPurchaseIds,
          purchaseId
        },
      );
      state = AsyncValue.data(newEconomy);
      await _repository.save(newEconomy);
    });
  }
}

final economyControllerProvider =
    StateNotifierProvider<EconomyController, AsyncValue<EconomyState>>((ref) {
  final repository = ref.watch(economyRepositoryProvider);
  return EconomyController(repository);
});
