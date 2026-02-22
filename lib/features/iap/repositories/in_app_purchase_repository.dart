import 'package:in_app_purchase/in_app_purchase.dart';
import 'iap_repository.dart';

class InAppPurchaseRepository implements IapRepository {
  final InAppPurchase _iapInstance;

  InAppPurchaseRepository({InAppPurchase? iapInstance})
      : _iapInstance = iapInstance ?? InAppPurchase.instance;

  @override
  Future<List<ProductDetails>> getAvailableProducts(
      Set<String> productIds) async {
    final available = await _iapInstance.isAvailable();
    if (!available) {
      throw Exception('In-app purchases not available');
    }

    final response = await _iapInstance.queryProductDetails(productIds);

    if (response.error != null) {
      throw Exception('Failed to load products: ${response.error!.message}');
    }

    return response.productDetails;
  }

  @override
  Future<bool> purchaseProduct(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);

    if (product.id.contains('coins')) {
      return await _iapInstance.buyConsumable(purchaseParam: purchaseParam);
    } else {
      return await _iapInstance.buyNonConsumable(purchaseParam: purchaseParam);
    }
  }

  @override
  Future<void> restorePurchases() async {
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
