import '../models/item_type.dart';
import '../models/store_item.dart';

class StoreCatalog {
  static const List<StoreItem> allItems = [
    // ── Card Skins ──────────────────────────────────────────────────────────
    StoreItem(
      id: 'card_classic_red',
      name: 'Classic Red',
      price: 0,
      type: ItemType.cardSkin,
      description: 'Traditional red card back',
    ),
    // Card skin assets not yet shipped — keep in catalog for future release.
    StoreItem(
      id: 'card_casino_gold',
      name: 'Casino Gold',
      price: 500,
      type: ItemType.cardSkin,
      description: 'Luxury gold pattern',
      isAvailable: false,
    ),
    StoreItem(
      id: 'card_neon_glow',
      name: 'Neon Glow',
      price: 800,
      type: ItemType.cardSkin,
      description: 'Modern cyberpunk theme',
      isAvailable: false,
    ),

    // ── Table Themes ─────────────────────────────────────────────────────────
    StoreItem(
      id: 'table_casino_green',
      name: 'Casino Green',
      price: 0,
      type: ItemType.tableTheme,
      description: 'Classic green felt',
    ),
    StoreItem(
      id: 'table_midnight_blue',
      name: 'Midnight Blue',
      price: 300,
      type: ItemType.tableTheme,
      description: 'Dark blue felt, easy on the eyes',
    ),
    StoreItem(
      id: 'table_sunset_red',
      name: 'Sunset Red',
      price: 400,
      type: ItemType.tableTheme,
      description: 'Warm red gradient',
    ),

    // ── Dealer Skins ─────────────────────────────────────────────────────────
    StoreItem(
      id: 'dealer_default',
      name: 'Default Dealer',
      price: 0,
      type: ItemType.dealerSkin,
      description: 'Standard dealer',
    ),
    StoreItem(
      id: 'dealer_premium',
      name: 'Premium Dealer',
      price: 999,
      type: ItemType.dealerSkin,
      description: 'Animated dealer persona',
      isAvailable: false,
    ),
  ];

  static List<StoreItem> getItemsByType(ItemType type) {
    return allItems.where((item) => item.type == type).toList();
  }

  static StoreItem? getItemById(String id) {
    try {
      return allItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}
