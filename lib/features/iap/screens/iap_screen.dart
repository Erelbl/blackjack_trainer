import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../app/theme.dart';
import '../../../data/providers/economy_providers.dart';
import '../../../engine/config/retention_config.dart';
import '../../../services/ad_service.dart';
import '../../../shared/widgets/coin_balance.dart';
import '../data/iap_catalog.dart';
import '../models/iap_product.dart';
import '../providers/iap_providers.dart';
import '../repositories/iap_repository.dart';
import '../../play/widgets/table_background.dart';
import '../../store/models/table_theme_item.dart';

// ── Helpers ─────────────────────────────────────────────────────────────────

String _formatCoins(int coins) {
  if (coins < 1000) return '$coins';
  if (coins % 1000 == 0) return '${coins ~/ 1000}k';
  return '${(coins / 1000).toStringAsFixed(1)}k';
}

String _packTitle(String productId) {
  if (productId == IapCatalog.kCoinsSmallId) return 'Small';
  if (productId == IapCatalog.kCoinsMediumId) return 'Medium';
  if (productId == IapCatalog.kCoinsLargeId) return 'Large';
  return 'Coin Pack';
}


// ── Screen ───────────────────────────────────────────────────────────────────

class IapScreen extends ConsumerStatefulWidget {
  const IapScreen({super.key});

  @override
  ConsumerState<IapScreen> createState() => _IapScreenState();
}

class _IapScreenState extends ConsumerState<IapScreen> {
  @override
  void initState() {
    super.initState();
    // Silent restore on screen load — wrapped in try/catch so that if the
    // iapControllerProvider failed to build (e.g. on simulator), accessing
    // .notifier doesn't propagate an unhandled exception.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(iapControllerProvider.notifier).restorePurchases();
      } catch (_) {}
    });

    // Listen for purchase results → snackbars
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
            final msg = error.toString();
            if (msg.isNotEmpty && !msg.contains('cancel')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: Colors.red),
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
    final isPurchasing = iapStateAsync.value?.isPurchasing ?? false;
    final isRestoring = iapStateAsync.value?.isRestoring ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Coins'),
        actions: [
          TextButton.icon(
            icon: isRestoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.restore, color: Colors.white),
            label: Text(
              'Restore',
              style: AppTheme.bodyStyle(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            onPressed: isRestoring
                ? null
                : () {
                    ref
                        .read(iapControllerProvider.notifier)
                        .restorePurchases();
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
      body: TableBackground(
        child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Balance hero
                const _CoinHeader(),

                // 2. Free Coins
                const _SectionLabel('FREE COINS'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _WatchAdCard(),
                ),
                const SizedBox(height: 8),

                // 3. Coin Packs
                const _SectionLabel('COIN PACKS'),
                productsAsync.when(
                  data: (products) {
                    final coinPacks = products
                        .where((p) =>
                            IapCatalog.getProductById(p.id)?.type ==
                            IapProductType.consumable)
                        .toList();
                    return _PacksList(
                      products: coinPacks,
                      isPurchasing: isPurchasing,
                      onPurchase: _handlePurchase,
                    );
                  },
                  loading: () => const _PacksSkeleton(),
                  error: (e, _) => e is IapUnavailableException
                      ? _StoreUnavailableCard(
                          onRetry: () =>
                              ref.invalidate(iapProductsProvider),
                        )
                      : _ProductsError(
                          onRetry: () =>
                              ref.invalidate(iapProductsProvider),
                        ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // Purchase overlay
          if (isPurchasing) const _PurchaseOverlay(),
        ],
      ),
      ), // TableBackground
    );
  }

  Future<void> _handlePurchase(ProductDetails product) async {
    await ref.read(iapControllerProvider.notifier).purchaseProduct(product);
  }
}

// ── _CoinHeader ──────────────────────────────────────────────────────────────

class _CoinHeader extends StatelessWidget {
  const _CoinHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<TableThemeTokens>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens?.mid ?? const Color(0xFF0D4A25),
            tokens?.darkFelt ?? const Color(0xFF083D1F),
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'YOUR BALANCE',
            style: AppTheme.displayStyle(
              fontSize: 12,
              color: AppTheme.casinoGold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 10),
          const CoinBalance(),
          const SizedBox(height: 6),
          Text(
            'Earn coins free or unlock more below',
            style: AppTheme.bodyStyle(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _SectionLabel ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Row(
        children: [
          Text(
            text,
            style: AppTheme.displayStyle(
              fontSize: 18,
              color: AppTheme.casinoGold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: AppTheme.casinoGold.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _WatchAdCard ─────────────────────────────────────────────────────────────

class _WatchAdCard extends ConsumerWidget {
  const _WatchAdCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final economyAsync = ref.watch(economyControllerProvider);
    final adState = ref.watch(adNotifierProvider);

    return economyAsync.when(
      data: (economy) {
        final removeAds = economy.removeAds;
        final isReady = adState.isReady && !removeAds;
        final isLoading = adState.isLoading && !removeAds;
        final remaining = adState.remainingAds;
        final canWatch = isReady && remaining > 0;

        String helperText;
        if (removeAds) {
          helperText = 'Ads removed — thanks for supporting!';
        } else if (remaining <= 0) {
          helperText = 'Daily limit reached — come back tomorrow';
        } else {
          helperText = '$remaining free ${remaining == 1 ? 'ad' : 'ads'} remaining today';
        }

        return Card(
          color: Colors.green.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.green.withValues(alpha: canWatch ? 0.5 : 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch Ad',
                        style: AppTheme.bodyStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Earn ',
                            style: AppTheme.bodyStyle(
                                fontSize: 13, color: Colors.white70),
                          ),
                          const Icon(Icons.monetization_on,
                              color: AppTheme.casinoGold, size: 14),
                          Text(
                            ' ${RetentionConfig.kBonusAdRewardCoins} coins',
                            style: AppTheme.bodyStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.casinoGold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        helperText,
                        style: AppTheme.bodyStyle(
                            fontSize: 11, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: ElevatedButton(
                    onPressed: canWatch
                        ? () => _handleWatchAd(context, ref)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Watch',
                            style: AppTheme.bodyStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 88,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleWatchAd(BuildContext context, WidgetRef ref) async {
    await ref.read(adNotifierProvider.notifier).showAd(
      onReward: (amount) {
        ref.read(economyControllerProvider.notifier)
            .addCoins(RetentionConfig.kBonusAdRewardCoins);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Earned ${RetentionConfig.kBonusAdRewardCoins} coins!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }
}

// ── _PacksList ────────────────────────────────────────────────────────────────

class _PacksList extends StatelessWidget {
  final List<ProductDetails> products;
  final bool isPurchasing;
  final void Function(ProductDetails) onPurchase;

  const _PacksList({
    required this.products,
    required this.isPurchasing,
    required this.onPurchase,
  });

  static const _kOrder = {
    IapCatalog.kCoinsSmallId: 0,
    IapCatalog.kCoinsMediumId: 1,
    IapCatalog.kCoinsLargeId: 2,
  };

  @override
  Widget build(BuildContext context) {
    final sorted = [...products]
      ..sort((a, b) =>
          (_kOrder[a.id] ?? 99).compareTo(_kOrder[b.id] ?? 99));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: sorted.map((product) {
          final cat = IapCatalog.getProductById(product.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CoinPackCard(
              product: product,
              title: _packTitle(product.id),
              coinAmount: cat?.coinAmount ?? 0,
              isPurchasing: isPurchasing,
              onTap: () => onPurchase(product),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── _CoinPackCard ─────────────────────────────────────────────────────────────

class _CoinPackCard extends StatelessWidget {
  final ProductDetails product;
  final String title;
  final int coinAmount;
  final bool isPurchasing;
  final VoidCallback onTap;

  const _CoinPackCard({
    required this.product,
    required this.title,
    required this.coinAmount,
    required this.isPurchasing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Coin icon
            const Icon(Icons.monetization_on,
                size: 40, color: AppTheme.casinoGold),
            const SizedBox(width: 16),

            // Title + amount
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTheme.displayStyle(
                        fontSize: 16,
                        color: Colors.white,
                        letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatCoins(coinAmount)} coins',
                    style: AppTheme.bodyStyle(
                        fontSize: 13, color: AppTheme.casinoGold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Price + BUY
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.price,
                  style: AppTheme.bodyStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: isPurchasing ? null : onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'BUY',
                    style: AppTheme.bodyStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── _PacksSkeleton ────────────────────────────────────────────────────────────

class _PacksSkeleton extends StatelessWidget {
  const _PacksSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── _StoreUnavailableCard ─────────────────────────────────────────────────────

class _StoreUnavailableCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _StoreUnavailableCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            children: [
              Icon(Icons.storefront_outlined,
                  size: 52, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 14),
              Text(
                'Store not available',
                style: AppTheme.displayStyle(
                    fontSize: 18, color: Colors.white70, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Text(
                'Coin packs aren\'t available on this device right now.\n'
                'Make sure you\'re signed in to the Play Store or App Store,\n'
                'then tap Try again.',
                style: AppTheme.bodyStyle(
                    fontSize: 12, color: Colors.white38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── _ProductsError ────────────────────────────────────────────────────────────

class _ProductsError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProductsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            'Couldn\'t load products',
            style: AppTheme.displayStyle(
                fontSize: 16, color: Colors.white, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            'Something went wrong connecting to the store.\nPlease try again.',
            style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

// ── _PurchaseOverlay ──────────────────────────────────────────────────────────

class _PurchaseOverlay extends StatelessWidget {
  const _PurchaseOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Processing purchase...',
                  style: AppTheme.bodyStyle(
                      fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
