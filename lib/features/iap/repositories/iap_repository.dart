import 'package:in_app_purchase/in_app_purchase.dart';

/// Thrown when the billing service reports it is not available on this device
/// (emulator without Play Store, not signed in, parental controls, etc.).
class IapUnavailableException implements Exception {
  const IapUnavailableException();
}

abstract class IapRepository {
  Future<List<ProductDetails>> getAvailableProducts(Set<String> productIds);
  Future<bool> purchaseProduct(ProductDetails product);
  Future<void> restorePurchases();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<void> completePurchase(PurchaseDetails purchase);
}
