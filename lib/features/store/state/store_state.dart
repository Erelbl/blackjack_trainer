// Sentinel used by copyWith to distinguish "caller passed null explicitly"
// from "caller did not pass the field" — required for nullable ephemeral fields.
const _keep = Object();

class StoreState {
  final List<String> ownedItemIds;
  final String selectedTableTheme;

  /// Non-null while a coin-based theme purchase is in flight.
  /// Ephemeral — NOT persisted to disk.
  final String? purchasingItemId;

  const StoreState({
    required this.ownedItemIds,
    required this.selectedTableTheme,
    this.purchasingItemId,
  });

  // ── Free items every install starts with ────────────────────────────────
  // Includes legacy card/dealer skin IDs for backward compat with existing
  // saves; they are harmless and ignored by the new store UI.
  static const List<String> _freeDefaults = [
    'table_casino_green',   // Classic theme — always free
    'card_classic_red',     // legacy; kept for backward compat
    'dealer_default',       // legacy; kept for backward compat
  ];

  factory StoreState.initial() {
    return const StoreState(
      ownedItemIds: _freeDefaults,
      selectedTableTheme: 'table_casino_green',
    );
  }

  factory StoreState.fromJson(Map<String, dynamic> json) {
    final saved = (json['ownedItemIds'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    // Always guarantee free defaults are present, even if the persisted list
    // predates this schema version.
    final merged = <String>{..._freeDefaults, ...saved}.toList();

    return StoreState(
      ownedItemIds: merged,
      selectedTableTheme:
          json['selectedTableTheme'] as String? ?? 'table_casino_green',
    );
  }

  Map<String, dynamic> toJson() => {
        'ownedItemIds': ownedItemIds,
        'selectedTableTheme': selectedTableTheme,
        // purchasingItemId is intentionally excluded — ephemeral.
      };

  StoreState copyWith({
    List<String>? ownedItemIds,
    String? selectedTableTheme,
    Object? purchasingItemId = _keep,
  }) {
    return StoreState(
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      selectedTableTheme: selectedTableTheme ?? this.selectedTableTheme,
      purchasingItemId: identical(purchasingItemId, _keep)
          ? this.purchasingItemId
          : purchasingItemId as String?,
    );
  }

  bool ownsTheme(String themeId) => ownedItemIds.contains(themeId);
  bool isThemeSelected(String themeId) => themeId == selectedTableTheme;
}
