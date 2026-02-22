import 'package:in_app_purchase/in_app_purchase.dart';

abstract class IapRepository {
  Future<List<ProductDetails>> getAvailableProducts(Set<String> productIds);
  Future<bool> purchaseProduct(ProductDetails product);
  Future<void> restorePurchases();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<void> completePurchase(PurchaseDetails purchase);
}
