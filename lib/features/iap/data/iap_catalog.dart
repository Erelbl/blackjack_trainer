import '../models/iap_product.dart';
import 'iap_product_ids.dart';

class IapCatalog {
  // ── Product ID constants (single source of truth) ─────────────────────────
  static const String kCoinsSmallId = coinsSmall;
  static const String kCoinsMediumId = coinsMedium;
  static const String kCoinsLargeId = coinsLarge;
  static const String kCoinsMegaId = 'com.blackjacktrainer.coins.mega';
  static const String kRemoveAdsId = 'com.blackjacktrainer.removeads';

  // Theme product IDs — keep for restore compatibility
  static const String kThemeNeonBlueId = 'com.blackjacktrainer.theme.neonblue';
  static const String kThemeVegasRedId = 'com.blackjacktrainer.theme.vegasred';
  static const String kThemeDarkEliteId = 'com.blackjacktrainer.theme.darkelite';

  // ── All products ───────────────────────────────────────────────────────────
  static const List<IapProduct> allProducts = [
    // ── Coin Packs (consumable) ──────────────────────────────────────────────
    IapProduct(
      id: kCoinsSmallId,
      name: 'Coin Pack',
      description: '2,500 coins',
      price: 1.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 2500,
    ),
    IapProduct(
      id: kCoinsMediumId,
      name: 'Coin Pack',
      description: '8,000 coins',
      price: 4.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 8000,
    ),
    IapProduct(
      id: kCoinsLargeId,
      name: 'Coin Pack',
      description: '20,000 coins — Best Value',
      price: 9.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 20000,
      isBestValue: true,
    ),
    IapProduct(
      id: kCoinsMegaId,
      name: 'Coin Pack',
      description: '60,000 coins',
      price: 19.99,
      currencyCode: 'USD',
      type: IapProductType.consumable,
      coinAmount: 60000,
    ),

    // ── Premium (non-consumable) ─────────────────────────────────────────────
    IapProduct(
      id: kRemoveAdsId,
      name: 'Remove Ads',
      description: 'Disable all ads permanently',
      price: 4.99,
      currencyCode: 'USD',
      type: IapProductType.nonConsumable,
    ),

    // ── Table Themes (non-consumable, per-theme) ─────────────────────────────
    IapProduct(
      id: kThemeNeonBlueId,
      name: 'Neon Blue Theme',
      description: 'Midnight blue with cool neon edge lighting',
      price: 0.99,
      currencyCode: 'USD',
      type: IapProductType.nonConsumable,
      themeId: 'table_midnight_blue',
    ),
    IapProduct(
      id: kThemeVegasRedId,
      name: 'Vegas Red Theme',
      description: 'Warm red felt — high-roller vibes',
      price: 0.99,
      currencyCode: 'USD',
      type: IapProductType.nonConsumable,
      themeId: 'table_sunset_red',
    ),
    IapProduct(
      id: kThemeDarkEliteId,
      name: 'Dark Elite Theme',
      description: 'Ultra-dark deep purple — exclusive VIP look',
      price: 0.99,
      currencyCode: 'USD',
      type: IapProductType.nonConsumable,
      themeId: 'table_dark_elite',
    ),
  ];

  // ── Convenience getters ────────────────────────────────────────────────────

  static Set<String> get allProductIds =>
      allProducts.map((p) => p.id).toSet();

  /// Product IDs to query from the store — excludes remove_ads (temporarily
  /// not offered; kept in catalog for restore-compatibility).
  static Set<String> get queryableProductIds =>
      allProducts
          .where((p) => p.id != kRemoveAdsId)
          .map((p) => p.id)
          .toSet();

  static List<IapProduct> get coinPacks =>
      allProducts.where((p) => p.type == IapProductType.consumable).toList();

  static IapProduct get removeAdsProduct =>
      allProducts.firstWhere((p) => p.id == kRemoveAdsId);

  static IapProduct? getProductById(String id) {
    for (final p in allProducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Coin amount to grant for a given product ID. Returns 0 if not a coin pack.
  static int coinAmountFor(String productId) =>
      getProductById(productId)?.coinAmount ?? 0;
}
