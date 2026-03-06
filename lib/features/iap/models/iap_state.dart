class IapState {
  final bool isPurchasing;
  final bool isRestoring;
  final bool lastPurchaseSuccess;
  final String? errorMessage;

  /// True when the billing service reported it is not available on this
  /// device/build. UI shows a friendly "unavailable" message; no purchase
  /// buttons are shown.
  final bool isUnavailable;

  const IapState({
    this.isPurchasing = false,
    this.isRestoring = false,
    this.lastPurchaseSuccess = false,
    this.errorMessage,
    this.isUnavailable = false,
  });

  const IapState.initial() : this();

  const IapState.unavailable()
      : isPurchasing = false,
        isRestoring = false,
        lastPurchaseSuccess = false,
        errorMessage = null,
        isUnavailable = true;

  IapState copyWith({
    bool? isPurchasing,
    bool? isRestoring,
    bool? lastPurchaseSuccess,
    String? errorMessage,
    bool? isUnavailable,
  }) {
    return IapState(
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      lastPurchaseSuccess: lastPurchaseSuccess ?? this.lastPurchaseSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      isUnavailable: isUnavailable ?? this.isUnavailable,
    );
  }
}
