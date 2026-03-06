import '../models/table_theme_item.dart';

/// Authoritative list of all table themes.
///
/// IDs intentionally match the keys already stored in users' SharedPreferences
/// (`ownedItemIds` / `selectedTableTheme`) so that no migration is needed.
class ThemeCatalog {
  ThemeCatalog._();

  /// Every premium theme costs the same number of coins.
  static const int premiumCoinPrice = 500;

  static const List<TableThemeItem> allThemes = [
    // ── Free ────────────────────────────────────────────────────────────────
    TableThemeItem(
      id: 'table_casino_green',
      displayName: 'Classic',
      description: 'The timeless casino green felt',
      isPremium: false,
      coinPrice: 0,
      tokens: TableThemeTokens.green,
    ),

    // ── Premium ──────────────────────────────────────────────────────────────
    // IAP product IDs are submitted as non-consumable products in App Store /
    // Google Play under these identifiers.
    TableThemeItem(
      id: 'table_midnight_blue',
      displayName: 'Neon Blue',
      description: 'Midnight blue with cool neon edge lighting',
      isPremium: true,
      coinPrice: premiumCoinPrice,
      iapProductId: 'com.blackjacktrainer.theme.neonblue',
      tokens: TableThemeTokens.neonBlue,
    ),
    TableThemeItem(
      id: 'table_sunset_red',
      displayName: 'Vegas Red',
      description: 'Warm red felt — high-roller vibes',
      isPremium: true,
      coinPrice: premiumCoinPrice,
      iapProductId: 'com.blackjacktrainer.theme.vegasred',
      tokens: TableThemeTokens.vegasRed,
    ),
    TableThemeItem(
      id: 'table_dark_elite',
      displayName: 'Dark Elite',
      description: 'Ultra-dark deep purple — exclusive VIP look',
      isPremium: true,
      coinPrice: premiumCoinPrice,
      iapProductId: 'com.blackjacktrainer.theme.darkelite',
      tokens: TableThemeTokens.darkElite,
    ),
  ];

  static TableThemeItem get defaultTheme => allThemes.first;

  static TableThemeItem? getById(String id) {
    for (final theme in allThemes) {
      if (theme.id == id) return theme;
    }
    return null;
  }

  /// Returns the theme whose IAP product ID matches [productId], or null.
  static TableThemeItem? getByIapProductId(String productId) {
    for (final theme in allThemes) {
      if (theme.iapProductId == productId) return theme;
    }
    return null;
  }
}
