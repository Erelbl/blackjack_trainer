import 'item_type.dart';

class StoreItem {
  final String id;
  final String name;
  final int price;
  final ItemType type;
  final String description;

  const StoreItem({
    required this.id,
    required this.name,
    required this.price,
    required this.type,
    required this.description,
  });

  bool get isFree => price == 0;
}
