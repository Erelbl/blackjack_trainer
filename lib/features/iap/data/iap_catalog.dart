import '../models/iap_product.dart';

class IapCatalog {
  static const List<IapProduct> allProducts = [
    IapProduct(
      id: 'com.blackjacktrainer.coins.small',
      name: 'Small Coin Pack',
      description: '500 coins to unlock cosmetics',
      price: 2.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 500,
    ),
    IapProduct(
      id: 'com.blackjacktrainer.coins.medium',
      name: 'Medium Coin Pack',
      description: '1,500 coins - Best Value!',
      price: 4.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 1500,
      isBestValue: true,
    ),
    IapProduct(
      id: 'com.blackjacktrainer.coins.large',
      name: 'Large Coin Pack',
      description: '4,000 coins for serious collectors',
      price: 9.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 4000,
    ),
    IapProduct(
      id: 'com.blackjacktrainer.removeads',
      name: 'Remove Ads',
      description: 'Disable all ads permanently',
      price: 4.99,
      currencyCode: 'USD',
      type: IapProductType.nonConsumable,
    ),
  ];

  static List<IapProduct> get coinPacks =>
      allProducts.where((p) => p.type == IapProductType.consumable).toList();

  static IapProduct? get removeAdsProduct => allProducts.firstWhere(
        (p) => p.id == 'com.blackjacktrainer.removeads',
      );

  static IapProduct? getProductById(String id) {
    try {
      return allProducts.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}
