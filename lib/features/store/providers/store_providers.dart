import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../data/providers/stats_providers.dart';
import '../data/theme_catalog.dart';
import '../models/table_theme_item.dart';
import '../repositories/shared_prefs_store_repository.dart';
import '../repositories/store_repository.dart';
import '../state/store_state.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) throw Exception('SharedPreferences not initialized');
  return SharedPrefsStoreRepository(prefs);
});

// ── Store controller ──────────────────────────────────────────────────────────

class StoreController extends StateNotifier<AsyncValue<StoreState>> {
  final StoreRepository _repository;
  final Ref _ref;

  StoreController(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repository.load());
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  // ── Coin-based purchase ───────────────────────────────────────────────────

  /// Returns null on success or a human-readable error string on failure.
  Future<String?> buyThemeWithCoins(TableThemeItem theme) async {
    final current = state.value;
    if (current == null) return 'Store not loaded';
    if (!theme.isPremium) return 'This theme is free';
    if (current.ownsTheme(theme.id)) return 'Already owned';
    if (current.purchasingItemId != null) return null; // another in flight

    final economy = _ref.read(economyControllerProvider).value;
    if (economy == null) return 'Economy not loaded';
    if (economy.coins < theme.coinPrice) return 'Not enough coins';

    // Set purchasing flag → UI shows spinner + disables all buy buttons
    state = AsyncValue.data(current.copyWith(purchasingItemId: theme.id));

    try {
      await _ref.read(economyControllerProvider.notifier).addCoins(-theme.coinPrice);
      await _grantTheme(current, theme.id);
      return null; // success
    } catch (e) {
      // Rollback purchasing flag only; economy controller owns coin state
      state = AsyncValue.data(StoreState(
        ownedItemIds: current.ownedItemIds,
        selectedTableTheme: current.selectedTableTheme,
        purchasingItemId: null,
      ));
      return 'Purchase failed. Please try again.';
    }
  }

  // ── IAP-based delivery ────────────────────────────────────────────────────

  /// Grants ownership of [themeId] without deducting coins.
  /// Called by [IapController] after a successful IAP purchase or restore.
  /// Idempotent — safe to call multiple times.
  Future<void> unlockTheme(String themeId) async {
    final current = state.value;
    if (current == null) return;
    if (current.ownsTheme(themeId)) return; // already owned — no-op
    await _grantTheme(current, themeId);
  }

  // ── Theme selection ───────────────────────────────────────────────────────

  /// Applies [themeId] as the active theme. No-op if not owned.
  Future<void> selectTheme(String themeId) async {
    final current = state.value;
    if (current == null || !current.ownsTheme(themeId)) return;

    final newState = current.copyWith(selectedTableTheme: themeId);
    state = AsyncValue.data(newState);
    await _repository.save(newState);
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<void> _grantTheme(StoreState from, String themeId) async {
    final newState = StoreState(
      ownedItemIds: [...from.ownedItemIds, themeId],
      selectedTableTheme: from.selectedTableTheme,
      purchasingItemId: null,
    );
    state = AsyncValue.data(newState);
    await _repository.save(newState);
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final storeControllerProvider =
    StateNotifierProvider<StoreController, AsyncValue<StoreState>>((ref) {
  return StoreController(ref.watch(storeRepositoryProvider), ref);
});

/// The currently active [TableThemeItem]. Guaranteed to return a valid,
/// non-null theme regardless of store/prefs state.
///
/// Fail-safe: if anything in the dependency chain throws (e.g. SharedPrefs
/// not yet ready), falls back to Classic Green so the app never shows a
/// black/empty background.
final selectedThemeProvider = Provider<TableThemeItem>((ref) {
  try {
    final id = ref.watch(storeControllerProvider.select(
      (s) => s.value?.selectedTableTheme ?? 'table_casino_green',
    ));
    final theme = ThemeCatalog.getById(id) ?? ThemeCatalog.defaultTheme;
    debugPrint('[Theme] Active theme: ${theme.id} (from store state)');
    return theme;
  } catch (e) {
    debugPrint('[Theme] selectedThemeProvider error ($e) — falling back to Classic Green');
    return ThemeCatalog.defaultTheme;
  }
});
