import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../data/iap_catalog.dart';
import '../models/iap_product.dart';
import '../models/iap_state.dart';
import '../repositories/iap_repository.dart';
import '../repositories/in_app_purchase_repository.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../features/store/providers/store_providers.dart';

// ── Availability ──────────────────────────────────────────────────────────────

/// Single source of truth for whether the billing service is reachable.
///
/// Checked once per session. Returns false (not error) on any failure so that
/// nothing in the UI ever needs to handle an error state for this provider.
/// Invalidate with [ref.invalidate] to retry.
final iapAvailabilityProvider = FutureProvider<bool>((ref) async {
  try {
    final available = await InAppPurchase.instance.isAvailable();
    debugPrint('[IAP] isAvailable = $available');
    return available;
  } catch (e) {
    debugPrint('[IAP] isAvailable threw: $e — treating as unavailable');
    return false;
  }
});

// ── Repository ────────────────────────────────────────────────────────────────

final iapRepositoryProvider = Provider<IapRepository>((ref) {
  return InAppPurchaseRepository();
});

// ── Products ─────────────────────────────────────────────────────────────────

/// Always returns [AsyncData] — never [AsyncError].
/// Returns an empty list when the store is unavailable so callers never need
/// to guard against error state.
final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final available = await ref.watch(iapAvailabilityProvider.future);
  if (!available) {
    debugPrint('[IAP] Product query skipped — store unavailable');
    return [];
  }

  try {
    final repository = ref.watch(iapRepositoryProvider);
    final productIds = IapCatalog.queryableProductIds;
    final products = await repository.getAvailableProducts(productIds);
    debugPrint('[IAP] Loaded ${products.length} products');
    return products;
  } catch (e) {
    debugPrint('[IAP] getAvailableProducts threw: $e — returning empty list');
    return [];
  }
});

// ── Controller ────────────────────────────────────────────────────────────────

class IapController extends StateNotifier<AsyncValue<IapState>> {
  final IapRepository _repository;
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  IapController(this._repository, this._ref)
      : super(const AsyncValue.data(IapState())) {
    _listenToPurchaseUpdates();
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  /// Returns true if the billing service is reachable. Checks the cached
  /// [iapAvailabilityProvider] value; re-checks if the provider hasn't
  /// resolved yet. Never throws.
  Future<bool> _checkAvailable() async {
    try {
      // Use cached result when available so we don't re-query on every call.
      final cached = _ref.read(iapAvailabilityProvider).value;
      if (cached != null) return cached;
      return await _ref.read(iapAvailabilityProvider.future);
    } catch (_) {
      return false;
    }
  }

  void _listenToPurchaseUpdates() {
    try {
      _subscription = _repository.purchaseStream.listen(
        (purchases) {
          for (final purchase in purchases) {
            _handlePurchaseUpdate(purchase);
          }
        },
        onError: (error) {
          debugPrint('[IAP] Purchase stream error: $error');
          // Don't crash — just mark idle. The specific operation that
          // triggered this (restore, purchase) has its own try/catch.
          state = const AsyncValue.data(IapState());
        },
      );
      debugPrint('[IAP] Purchase stream subscribed');
    } catch (e) {
      // purchaseStream.listen() can throw synchronously on some simulator
      // configurations. Catching here prevents the IapController constructor
      // from throwing, which would crash every widget that watches
      // iapControllerProvider.
      debugPrint('[IAP] Could not subscribe to purchase stream: $e');
      state = const AsyncValue.data(IapState.unavailable());
    }
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      state = const AsyncValue.data(IapState(isPurchasing: true));
    } else if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
      final isValid = await _verifyPurchaseLocally(purchase);
      if (isValid) {
        await _deliverProduct(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _repository.completePurchase(purchase);
      }

      state = const AsyncValue.data(
        IapState(isPurchasing: false, lastPurchaseSuccess: true),
      );
    } else if (purchase.status == PurchaseStatus.error) {
      final msg = purchase.error?.message ?? 'Purchase failed';
      debugPrint('[IAP] Purchase error: $msg');
      state = AsyncValue.error(msg, StackTrace.current);
    }
  }

  Future<bool> _verifyPurchaseLocally(PurchaseDetails purchase) async {
    final product = IapCatalog.getProductById(purchase.productID);
    if (product == null) return false;

    if (product.type == IapProductType.consumable) {
      final economy = _ref.read(economyControllerProvider).value;
      if (economy == null) return false;
    }

    return true; // trust platform for MVP
  }

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final catalogProduct = IapCatalog.getProductById(purchase.productID);
    if (catalogProduct == null) {
      debugPrint('[IAP] _deliverProduct: unknown productID ${purchase.productID}');
      return;
    }

    if (catalogProduct.type == IapProductType.consumable) {
      // ── Coin pack ──────────────────────────────────────────────────────
      final economy = _ref.read(economyControllerProvider).value;
      if (economy == null) return;
      if (economy.deliveredPurchaseIds.contains(purchase.purchaseID)) {
        debugPrint('[IAP] Duplicate delivery skipped: ${purchase.purchaseID}');
        return;
      }

      final amount = catalogProduct.coinAmount ?? 0;
      await _ref
          .read(economyControllerProvider.notifier)
          .addCoins(amount);
      debugPrint('[IAP] Granted $amount coins for ${purchase.productID}');

      final id = purchase.purchaseID;
      if (id != null) {
        await _ref
            .read(economyControllerProvider.notifier)
            .markPurchaseDelivered(id);
        debugPrint('[IAP] Marked delivered: $id');
      }
    } else if (purchase.productID == IapCatalog.kRemoveAdsId) {
      // ── Remove Ads ─────────────────────────────────────────────────────
      await _ref.read(economyControllerProvider.notifier).setRemoveAds(true);
      debugPrint('[IAP] remove_ads entitlement applied');
    } else if (catalogProduct.themeId != null) {
      // ── Per-theme IAP (purchase or restore) ────────────────────────────
      await _ref
          .read(storeControllerProvider.notifier)
          .unlockTheme(catalogProduct.themeId!);
      debugPrint('[IAP] Theme delivered: ${catalogProduct.themeId}');
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> purchaseProduct(ProductDetails product) async {
    if (!await _checkAvailable()) {
      debugPrint('[IAP] purchaseProduct skipped — store unavailable');
      state = const AsyncValue.data(IapState.unavailable());
      return;
    }

    state = const AsyncValue.data(IapState(isPurchasing: true));
    try {
      await _repository.purchaseProduct(product);
      // Result arrives through purchaseStream
    } catch (e) {
      debugPrint('[IAP] purchaseProduct threw: $e');
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> restorePurchases() async {
    if (!await _checkAvailable()) {
      debugPrint('[IAP] restorePurchases skipped — store unavailable');
      // Silent no-op on unavailable devices. Don't set error state —
      // this is called silently on every launch and shouldn't alarm the UI.
      return;
    }

    state = const AsyncValue.data(IapState(isRestoring: true));
    try {
      await _repository.restorePurchases();
      debugPrint('[IAP] restorePurchases triggered (results via stream)');
      state = const AsyncValue.data(IapState(isRestoring: false));
    } catch (e) {
      debugPrint('[IAP] restorePurchases threw: $e');
      state = const AsyncValue.data(IapState(isRestoring: false));
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final iapControllerProvider =
    StateNotifierProvider<IapController, AsyncValue<IapState>>((ref) {
  final repository = ref.watch(iapRepositoryProvider);
  return IapController(repository, ref);
});
