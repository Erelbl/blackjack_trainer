import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/economy_providers.dart';
import '../../services/ad_service.dart';
import '../../shared/widgets/coin_balance.dart';
import 'data/store_catalog.dart';
import 'models/item_type.dart';
import 'models/store_item.dart';
import 'providers/store_providers.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final AdService _adService = AdService();

  @override
  void initState() {
    super.initState();
    // Preload ad when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final economyAsync = ref.read(economyControllerProvider);
      economyAsync.whenData((economy) {
        _adService.setRemoveAds(economy.removeAds);
        _adService.loadRewardedAd();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeControllerProvider);
    final economyAsync = ref.watch(economyControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.amber),
            label: const Text('Get Coins', style: TextStyle(color: Colors.white)),
            onPressed: () => context.push('/iap'),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CoinBalance(),
          ),
        ],
      ),
      body: storeAsync.when(
        data: (store) => economyAsync.when(
          data: (economy) => _buildStoreContent(context, ref, store, economy.coins),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading economy')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading store')),
      ),
    );
  }

  Widget _buildStoreContent(
    BuildContext context,
    WidgetRef ref,
    store,
    int coins,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWatchAdButton(context, ref),
          const SizedBox(height: 24),
          _buildSection(
            context,
            ref,
            'Card Skins',
            StoreCatalog.getItemsByType(ItemType.cardSkin),
            store,
            coins,
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            ref,
            'Table Themes',
            StoreCatalog.getItemsByType(ItemType.tableTheme),
            store,
            coins,
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            ref,
            'Dealer Skins',
            StoreCatalog.getItemsByType(ItemType.dealerSkin),
            store,
            coins,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<StoreItem> items,
    store,
    int coins,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _buildItemCard(context, ref, item, store, coins)),
      ],
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    WidgetRef ref,
    StoreItem item,
    store,
    int coins,
  ) {
    final owned = store.ownsItem(item.id);
    final selected = store.isSelected(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  if (!owned) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.monetization_on,
                            color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${item.price}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildActionButton(context, ref, item, owned, selected, coins),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    StoreItem item,
    bool owned,
    bool selected,
    int coins,
  ) {
    if (!owned) {
      // Show Buy button
      final canAfford = coins >= item.price;
      return ElevatedButton(
        onPressed: canAfford
            ? () => _handleBuy(context, ref, item)
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canAfford ? Colors.green : null,
        ),
        child: const Text('Buy'),
      );
    } else if (selected) {
      // Show Selected (disabled)
      return ElevatedButton(
        onPressed: null,
        child: const Text('Selected'),
      );
    } else {
      // Show Select button
      return ElevatedButton(
        onPressed: () => _handleSelect(ref, item),
        child: const Text('Select'),
      );
    }
  }

  Future<void> _handleBuy(
    BuildContext context,
    WidgetRef ref,
    StoreItem item,
  ) async {
    final error =
        await ref.read(storeControllerProvider.notifier).buyItem(item);

    if (context.mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchased ${item.name}!')),
        );
      }
    }
  }

  Future<void> _handleSelect(WidgetRef ref, StoreItem item) async {
    await ref.read(storeControllerProvider.notifier).selectItem(item);
  }

  Widget _buildWatchAdButton(BuildContext context, WidgetRef ref) {
    final economyAsync = ref.watch(economyControllerProvider);

    return economyAsync.when(
      data: (economy) {
        final isAdReady = _adService.isAdReady;
        final isLoading = _adService.isLoading;
        final remaining = _adService.remainingAds;
        final removeAds = economy.removeAds;

        String helperText;
        if (removeAds) {
          helperText = 'Ads removed';
        } else if (remaining <= 0) {
          helperText = 'Daily limit reached';
        } else {
          helperText = '$remaining ads remaining today';
        }

        return Card(
          color: Colors.green.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Watch Ad',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            'Earn ',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                          const Text(
                            ' 30 coins',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        helperText,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: isAdReady && !removeAds && remaining > 0
                      ? () => _handleWatchAd(context, ref)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Watch'),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleWatchAd(BuildContext context, WidgetRef ref) async {
    await _adService.showRewardedAd(
      onReward: (amount) {
        // Award 30 coins (ignoring the reward amount from ad)
        ref.read(economyControllerProvider.notifier).addCoins(30);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Earned 30 coins!')),
          );
        }
      },
    );
  }
}
