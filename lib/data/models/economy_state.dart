class EconomyState {
  final int coins;
  final bool removeAds;
  final Set<String> deliveredPurchaseIds;

  const EconomyState({
    required this.coins,
    this.removeAds = false,
    this.deliveredPurchaseIds = const {},
  });

  factory EconomyState.initial() {
    return const EconomyState(
      coins: 1000, // Starting balance
      removeAds: false,
      deliveredPurchaseIds: {},
    );
  }

  factory EconomyState.fromJson(Map<String, dynamic> json) {
    return EconomyState(
      coins: json['coins'] as int? ?? 0,
      removeAds: json['removeAds'] as bool? ?? false,
      deliveredPurchaseIds: (json['deliveredPurchaseIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'coins': coins,
      'removeAds': removeAds,
      'deliveredPurchaseIds': deliveredPurchaseIds.toList(),
    };
  }

  EconomyState copyWith({
    int? coins,
    bool? removeAds,
    Set<String>? deliveredPurchaseIds,
  }) {
    return EconomyState(
      coins: coins ?? this.coins,
      removeAds: removeAds ?? this.removeAds,
      deliveredPurchaseIds: deliveredPurchaseIds ?? this.deliveredPurchaseIds,
    );
  }
}
