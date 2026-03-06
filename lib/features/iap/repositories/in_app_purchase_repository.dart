import 'package:in_app_purchase/in_app_purchase.dart';
import '../data/iap_catalog.dart';
import '../models/iap_product.dart';
import 'iap_repository.dart';

class InAppPurchaseRepository implements IapRepository {
  final InAppPurchase _iapInstance;

  InAppPurchaseRepository({InAppPurchase? iapInstance})
      : _iapInstance = iapInstance ?? InAppPurchase.instance;

  /// Checks availability, wrapping any platform exceptions in
  /// [IapUnavailableException]. This prevents PlatformException from
  /// propagating to callers who only need to know available/not.
  Future<bool> _safeIsAvailable() async {
    try {
      return await _iapInstance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ProductDetails>> getAvailableProducts(
      Set<String> productIds) async {
    final available = await _safeIsAvailable();
    if (!available) {
      throw const IapUnavailableException();
    }

    final response = await _iapInstance.queryProductDetails(productIds);

    if (response.error != null) {
      throw Exception('Failed to load products: ${response.error!.message}');
    }

    return response.productDetails;
  }

  @override
  Future<bool> purchaseProduct(ProductDetails product) async {
    final available = await _safeIsAvailable();
    if (!available) {
      throw const IapUnavailableException();
    }

    final purchaseParam = PurchaseParam(productDetails: product);

    final catalogProduct = IapCatalog.getProductById(product.id);
    if (catalogProduct?.type == IapProductType.consumable) {
      return await _iapInstance.buyConsumable(purchaseParam: purchaseParam);
    } else {
      return await _iapInstance.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  @override
  Future<void> restorePurchases() async {
    final available = await _safeIsAvailable();
    if (!available) {
      throw const IapUnavailableException();
    }
    await _iapInstance.restorePurchases();
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _iapInstance.purchaseStream;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    await _iapInstance.completePurchase(purchase);
  }
}
