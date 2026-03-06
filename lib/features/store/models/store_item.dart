import 'item_type.dart';

class StoreItem {
  final String id;
  final String name;
  final int price;
  final ItemType type;
  final String description;
  /// False for items whose in-game effect is not yet implemented.
  /// These show a "Coming Soon" badge and cannot be purchased.
  final bool isAvailable;

  const StoreItem({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    required this.description,
    this.isAvailable = true,
  });

  bool get isFree => price == 0;
}
