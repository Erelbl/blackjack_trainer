class IapState {
  final bool isPurchasing;
  final bool isRestoring;
  final bool lastPurchaseSuccess;
  final String? errorMessage;

  const IapState({
    this.isPurchasing = false,
    this.isRestoring = false,
    this.lastPurchaseSuccess = false,
    this.errorMessage,
  });

  const IapState.initial() : this();

  IapState copyWith({
    bool? isPurchasing,
    bool? isRestoring,
    bool? lastPurchaseSuccess,
    String? errorMessage,
  }) {
    return IapState(
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      lastPurchaseSuccess: lastPurchaseSuccess ?? this.lastPurchaseSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
