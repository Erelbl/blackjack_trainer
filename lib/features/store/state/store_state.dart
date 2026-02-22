class StoreState {
  final List<String> ownedItemIds;
  final String selectedCardSkin;
  final String selectedTableTheme;
  final String selectedDealerSkin;

  const StoreState({
    required this.ownedItemIds,
    required this.selectedCardSkin,
    required this.selectedTableTheme,
    required this.selectedDealerSkin,
  });

  factory StoreState.initial() {
    return const StoreState(
      ownedItemIds: [
        'card_classic_red',
        'table_casino_green',
        'dealer_default',
      ],
      selectedCardSkin: 'card_classic_red',
      selectedTableTheme: 'table_casino_green',
      selectedDealerSkin: 'dealer_default',
    );
  }

  factory StoreState.fromJson(Map<String, dynamic> json) {
    return StoreState(
      ownedItemIds: (json['ownedItemIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      selectedCardSkin: json['selectedCardSkin'] as String? ?? 'card_classic_red',
      selectedTableTheme:
          json['selectedTableTheme'] as String? ?? 'table_casino_green',
      selectedDealerSkin: json['selectedDealerSkin'] as String? ?? 'dealer_default',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownedItemIds': ownedItemIds,
      'selectedCardSkin': selectedCardSkin,
      'selectedTableTheme': selectedTableTheme,
      'selectedDealerSkin': selectedDealerSkin,
    };
  }

  StoreState copyWith({
    List<String>? ownedItemIds,
    String? selectedCardSkin,
    String? selectedTableTheme,
    String? selectedDealerSkin,
  }) {
    return StoreState(
      ownedItemIds: ownedItemIds ?? this.ownedItemIds,
      selectedCardSkin: selectedCardSkin ?? this.selectedCardSkin,
      selectedTableTheme: selectedTableTheme ?? this.selectedTableTheme,
      selectedDealerSkin: selectedDealerSkin ?? this.selectedDealerSkin,
    );
  }

  bool ownsItem(String itemId) => ownedItemIds.contains(itemId);
  bool isSelected(String itemId) =>
      itemId == selectedCardSkin ||
      itemId == selectedTableTheme ||
      itemId == selectedDealerSkin;
}
