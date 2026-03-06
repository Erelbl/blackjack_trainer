enum IapProductType { consumable, nonConsumable }

class IapProduct {
  final String id;
  final String name;
  final String description;
  final double price;
  final String currencyCode;
  final IapProductType type;
  final int? coinAmount;
  final bool isBestValue;
  /// Non-null when this product unlocks a table theme.
  /// Value matches [TableThemeItem.id] in ThemeCatalog.
  final String? themeId;

  const IapProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currencyCode,
    required this.type,
    this.coinAmount,
    this.isBestValue = false,
    this.themeId,
  });
}
