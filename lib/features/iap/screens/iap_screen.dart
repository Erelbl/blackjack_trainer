import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../shared/widgets/coin_balance.dart';
import '../data/iap_catalog.dart';
import '../providers/iap_providers.dart';

class IapScreen extends ConsumerStatefulWidget {
  const IapScreen({super.key});

  @override
  ConsumerState<IapScreen> createState() => _IapScreenState();
}

class _IapScreenState extends ConsumerState<IapScreen> {
  @override
  void initState() {
    super.initState();
    // Silent restore on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(iapControllerProvider.notifier).restorePurchases();
    });

    // Listen for purchase results
    ref.listenManual(iapControllerProvider, (previous, next) {
      next.when(
        data: (iapState) {
          if (iapState.lastPurchaseSuccess && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Purchase successful! Coins added.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        loading: () {},
        error: (error, _) {
          if (mounted) {
            final errorMsg = error.toString();
            if (errorMsg.isNotEmpty && !errorMsg.contains('cancel')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMsg),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(iapProductsProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final economyAsync = ref.watch(economyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Coins'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restore, color: Colors.white),
            label: const Text('Restore', style: TextStyle(color: Colors.white)),
            onPressed: iapStateAsync.value?.isRestoring ?? false
                ? null
                : () {
                    ref.read(iapControllerProvider.notifier).restorePurchases();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Restoring purchases...')),
                    );
                  },
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CoinBalance(),
          ),
        ],
      ),
      body: Stack(
        children: [
          productsAsync.when(
            data: (products) => economyAsync.when(
              data: (economy) =>
                  _buildProductList(products, economy, iapStateAsync.value),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading economy')),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Unable to load products',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(e.toString(),
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
          // Loading overlay
          if (iapStateAsync.value?.isPurchasing ?? false)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing purchase...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductList(
      List<ProductDetails> products, economy, iapState) {
    final coinPacks = products
        .where((p) => p.id.contains('coins'))
        .toList();
    final removeAdsProduct = products
        .firstWhere((p) => p.id == 'com.blackjacktrainer.removeads',
            orElse: () => products.first);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coin Packs',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Purchase coins to unlock cosmetics faster',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...coinPacks.map((product) => _buildCoinPackCard(product)),
          const SizedBox(height: 24),
          _buildRemoveAdsCard(removeAdsProduct, economy.removeAds),
        ],
      ),
    );
  }

  Widget _buildCoinPackCard(ProductDetails product) {
    final catalogProduct = IapCatalog.getProductById(product.id);
    final isBestValue = catalogProduct?.isBestValue ?? false;

    return Card(
      elevation: isBestValue ? 8 : 2,
      color: isBestValue ? Colors.amber.withOpacity(0.1) : null,
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          if (isBestValue)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Colors.amber, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        catalogProduct?.name ?? product.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${catalogProduct?.coinAmount ?? 0} coins',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        catalogProduct?.description ?? product.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _handlePurchase(product),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBestValue ? Colors.amber : Colors.green,
                    minimumSize: const Size(80, 44),
                  ),
                  child: Text(
                    product.price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveAdsCard(ProductDetails product, bool owned) {
    return Card(
      color: owned ? Colors.green.withOpacity(0.2) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.block,
              size: 48,
              color: owned ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Remove Ads',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Disable all ads permanently',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            owned
                ? const Chip(
                    label: Text('OWNED'),
                    backgroundColor: Colors.green,
                  )
                : ElevatedButton(
                    onPressed: () => _handlePurchase(product),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(80, 44),
                    ),
                    child: Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase(ProductDetails product) async {
    await ref.read(iapControllerProvider.notifier).purchaseProduct(product);
  }
}
