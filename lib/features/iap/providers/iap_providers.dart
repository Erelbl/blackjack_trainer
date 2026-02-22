import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../data/iap_catalog.dart';
import '../models/iap_product.dart';
import '../models/iap_state.dart';
import '../repositories/iap_repository.dart';
import '../repositories/in_app_purchase_repository.dart';
import '../../../data/providers/economy_providers.dart';

final iapRepositoryProvider = Provider<IapRepository>((ref) {
  return InAppPurchaseRepository();
});

final iapProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final repository = ref.watch(iapRepositoryProvider);
  final productIds = IapCatalog.allProducts.map((p) => p.id).toSet();
  return await repository.getAvailableProducts(productIds);
});

class IapController extends StateNotifier<AsyncValue<IapState>> {
  final IapRepository _repository;
  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  IapController(this._repository, this._ref)
      : super(const AsyncValue.data(IapState())) {
    _listenToPurchaseUpdates();
  }

  void _listenToPurchaseUpdates() {
    _subscription = _repository.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          _handlePurchaseUpdate(purchase);
        }
      },
      onError: (error) {
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
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

      state =
          const AsyncValue.data(IapState(isPurchasing: false, lastPurchaseSuccess: true));
    } else if (purchase.status == PurchaseStatus.error) {
      state = AsyncValue.error(
        purchase.error?.message ?? 'Purchase failed',
        StackTrace.current,
      );
    }
  }

  Future<bool> _verifyPurchaseLocally(PurchaseDetails purchase) async {
    // Verify productID matches catalog
    final product = IapCatalog.getProductById(purchase.productID);
    if (product == null) return false;

    // Prevent duplicate delivery
    final economyState = _ref.read(economyControllerProvider).value;
    if (economyState == null) return false;

    if (economyState.deliveredPurchaseIds.contains(purchase.purchaseID)) {
      return true; // Already delivered
    }

    return true; // MVP: trust platform
  }

  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final economyState = _ref.read(economyControllerProvider).value;
    if (economyState == null) return;

    // Prevent duplicate delivery
    if (economyState.deliveredPurchaseIds.contains(purchase.purchaseID)) {
      return;
    }

    final catalogProduct = IapCatalog.getProductById(purchase.productID);
    if (catalogProduct == null) return;

    if (catalogProduct.type == IapProductType.consumable) {
      // Award coins
      await _ref
          .read(economyControllerProvider.notifier)
          .addCoins(catalogProduct.coinAmount ?? 0);

      // Mark as delivered
      final id = purchase.purchaseID;
      if (id == null) return;
      await _ref
          .read(economyControllerProvider.notifier)
          .markPurchaseDelivered(id);
    } else if (purchase.productID == 'com.blackjacktrainer.removeads') {
      // Enable removeAds
      await _ref.read(economyControllerProvider.notifier).setRemoveAds(true);
    }
  }

  Future<void> purchaseProduct(ProductDetails product) async {
    state = const AsyncValue.data(IapState(isPurchasing: true));
    try {
      await _repository.purchaseProduct(product);
      // Purchase result comes through purchaseStream
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> restorePurchases() async {
    state = const AsyncValue.data(IapState(isRestoring: true));
    try {
      await _repository.restorePurchases();
      // Restored purchases come through purchaseStream
      state = const AsyncValue.data(IapState(isRestoring: false));
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
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
