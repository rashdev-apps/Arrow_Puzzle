/// Abstraction layer for in-app purchases (coin packs, premium, …).
/// Stub implementation ships with the game; integrate StoreKit/Play Billing
/// behind this interface when going live with monetisation.
abstract interface class IapService {
  /// Product ids offered by the store.
  List<String> get coinPackProductIds;

  /// Launch the purchase flow. Returns the number of coins granted, 0 on
  /// failure/cancel.
  Future<int> buyCoins(String productId);

  /// Restore previous purchases. Returns coins granted, 0 if none.
  Future<int> restorePurchases();
}

class StubIapService implements IapService {
  const StubIapService();

  @override
  List<String> get coinPackProductIds => const [
        'coins_small',
        'coins_medium',
        'coins_large',
      ];

  @override
  Future<int> buyCoins(String productId) async => 0;

  @override
  Future<int> restorePurchases() async => 0;
}
