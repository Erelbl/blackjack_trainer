import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../app/theme.dart';
import '../../data/providers/economy_providers.dart';
import '../../features/iap/models/iap_state.dart';
import '../../features/iap/providers/iap_providers.dart';
import '../../engine/config/retention_config.dart';
import '../../services/ad_service.dart';
import '../../services/analytics_service.dart';
import '../../shared/widgets/coin_balance.dart';
import '../play/widgets/table_background.dart';
import 'data/theme_catalog.dart';
import 'models/table_theme_item.dart';
import 'providers/store_providers.dart';
import 'state/store_state.dart';

// ── IAP unavailable banner ────────────────────────────────────────────────────

class _IapUnavailableBanner extends ConsumerWidget {
  const _IapUnavailableBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined,
                size: 28, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'In-app purchases unavailable on this device.\n'
                'Use coins to unlock themes.',
                style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ref.invalidate(iapAvailabilityProvider);
                ref.invalidate(iapProductsProvider);
              },
              child: Text(
                'Retry',
                style: AppTheme.bodyStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── StoreScreen ───────────────────────────────────────────────────────────────

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logShopOpen();
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(storeControllerProvider);
    final economyAsync = ref.watch(economyControllerProvider);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final productsAsync = ref.watch(iapProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store'),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CoinBalance(),
          ),
        ],
      ),
      body: storeAsync.when(
        data: (store) => economyAsync.when(
          data: (economy) => _StoreBody(
            store: store,
            coins: economy.coins,
            iapState: iapStateAsync.value ?? const IapState(),
            products: productsAsync.value ?? [],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading economy')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading store')),
      ),
    );
  }
}

// ── _StoreBody ────────────────────────────────────────────────────────────────

class _StoreBody extends ConsumerWidget {
  final StoreState store;
  final int coins;
  final IapState iapState;
  final List<ProductDetails> products;

  const _StoreBody({
    required this.store,
    required this.coins,
    required this.iapState,
    required this.products,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iapAvailableAsync = ref.watch(iapAvailabilityProvider);
    // Show banner only once availability is known to be false.
    final showUnavailableBanner = iapAvailableAsync.value == false;

    return TableBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showUnavailableBanner) ...[
              const _IapUnavailableBanner(),
              const SizedBox(height: 12),
            ],
            // ── Get Coins shortcut ─────────────────────────────────────────
            _GetCoinsCard(coins: coins),
            const SizedBox(height: 8),
            const _WatchAdTile(),
            const SizedBox(height: 24),

          // Section header
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Text(
                  'TABLE THEMES',
                  style: AppTheme.displayStyle(
                    fontSize: 20,
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
          ),

          ...ThemeCatalog.allThemes.map(
            (theme) => _ThemeTile(
              theme: theme,
              store: store,
              coins: coins,
              iapState: iapState,
              products: products,
            ),
          ),
          ],
        ),
      ),    // SingleChildScrollView
    );    // TableBackground
  }
}

// ── _GetCoinsCard ─────────────────────────────────────────────────────────────

/// Shortcut that navigates to the coin purchase (IAP) screen.
/// Always visible at the top of the store — coins are needed to unlock themes.
class _GetCoinsCard extends StatelessWidget {
  final int coins;
  const _GetCoinsCard({required this.coins});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/iap'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: AppTheme.casinoGold.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.casinoGold.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.monetization_on,
                color: AppTheme.casinoGold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'GET COINS',
                    style: AppTheme.displayStyle(
                      fontSize: 14,
                      color: AppTheme.casinoGold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Buy coin packs or watch ads',
                    style: AppTheme.bodyStyle(
                        fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: AppTheme.casinoGold, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── _ThemeTile ────────────────────────────────────────────────────────────────

class _ThemeTile extends ConsumerWidget {
  final TableThemeItem theme;
  final StoreState store;
  final int coins;
  final IapState iapState;
  final List<ProductDetails> products;

  const _ThemeTile({
    required this.theme,
    required this.store,
    required this.coins,
    required this.iapState,
    required this.products,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = theme.isFree || store.ownsTheme(theme.id);
    final applied = store.isThemeSelected(theme.id);
    final isPurchasingThis = store.purchasingItemId == theme.id;
    final isAnyPurchasing =
        store.purchasingItemId != null || iapState.isPurchasing;

    final ProductDetails? iapProduct = theme.iapProductId != null
        ? products.where((p) => p.id == theme.iapProductId).firstOrNull
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: applied ? 8 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: applied
              ? const BorderSide(color: AppTheme.casinoGold, width: 2)
              : owned
                  ? BorderSide(
                      color: AppTheme.casinoGold.withValues(alpha: 0.3))
                  : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ThemePreviewStrip(tokens: theme.tokens, height: 70),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        theme.displayName.toUpperCase(),
                        style: AppTheme.displayStyle(
                          fontSize: 20,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (applied)
                        _Badge(
                          label: '✓ APPLIED',
                          bg: AppTheme.casinoGold,
                          textColor: Colors.black,
                        )
                      else if (owned)
                        _Badge(
                          label: 'OWNED',
                          bg: Colors.white.withValues(alpha: 0.15),
                          textColor: Colors.white70,
                        )
                      else if (theme.isFree)
                        _Badge(
                          label: 'FREE',
                          bg: Colors.green.withValues(alpha: 0.2),
                          textColor: Colors.greenAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    theme.description,
                    style: AppTheme.bodyStyle(
                        fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 14),
                  _ActionRow(
                    theme: theme,
                    owned: owned,
                    applied: applied,
                    coins: coins,
                    isPurchasingThis: isPurchasingThis,
                    isAnyPurchasing: isAnyPurchasing,
                    iapProduct: iapProduct,
                    onCoinBuy: () => _onCoinBuy(context, ref),
                    onIapBuy: iapProduct != null
                        ? () => _onIapBuy(context, ref, iapProduct)
                        : null,
                    onApply: () => ref
                        .read(storeControllerProvider.notifier)
                        .selectTheme(theme.id),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCoinBuy(BuildContext context, WidgetRef ref) async {
    final error = await ref
        .read(storeControllerProvider.notifier)
        .buyThemeWithCoins(theme);
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _onIapBuy(
    BuildContext context,
    WidgetRef ref,
    ProductDetails product,
  ) async {
    await ref.read(iapControllerProvider.notifier).purchaseProduct(product);
  }
}

// ── _ThemePreviewStrip ────────────────────────────────────────────────────────

class _ThemePreviewStrip extends StatelessWidget {
  final TableThemeTokens tokens;
  final double height;

  const _ThemePreviewStrip({required this.tokens, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [tokens.centerGlow, tokens.mid, tokens.darkFelt],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: Center(
          child: Text(
            '♠  ♥  ♦  ♣',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.25),
              letterSpacing: 6,
            ),
          ),
        ),
      ),
    );
  }
}

// ── _ActionRow ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final TableThemeItem theme;
  final bool owned;
  final bool applied;
  final int coins;
  final bool isPurchasingThis;
  final bool isAnyPurchasing;
  final ProductDetails? iapProduct;
  final VoidCallback onCoinBuy;
  final VoidCallback? onIapBuy;
  final VoidCallback onApply;

  const _ActionRow({
    required this.theme,
    required this.owned,
    required this.applied,
    required this.coins,
    required this.isPurchasingThis,
    required this.isAnyPurchasing,
    required this.iapProduct,
    required this.onCoinBuy,
    required this.onIapBuy,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    if (isPurchasingThis) {
      return const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Text(
            'Processing…',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      );
    }

    if (owned) {
      return SizedBox(
        width: double.infinity,
        child: applied
            ? OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  'Applied',
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.casinoGold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.casinoGold),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: isAnyPurchasing ? null : onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.casinoGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Apply',
                  style: AppTheme.bodyStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
      );
    }

    // Not owned — dual CTA
    final canAfford = coins >= theme.coinPrice;
    final product = iapProduct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: (canAfford && !isAnyPurchasing) ? onCoinBuy : null,
          icon: const Icon(Icons.monetization_on, size: 16),
          label: Text(
            canAfford
                ? 'Unlock  •  ${theme.coinPrice} coins'
                : 'Need ${theme.coinPrice - coins} more coins',
            style: AppTheme.bodyStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: canAfford ? Colors.black : Colors.white38,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canAfford
                ? AppTheme.casinoGold
                : Colors.white.withValues(alpha: 0.08),
            foregroundColor: canAfford ? Colors.black : Colors.white38,
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: canAfford ? 4 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        if (product != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isAnyPurchasing ? null : onIapBuy,
            icon: const Icon(Icons.lock_open_rounded, size: 16),
            label: Text(
              'Buy  •  ${product.price}',
              style: AppTheme.bodyStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── _Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTheme.bodyStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── _WatchAdTile ──────────────────────────────────────────────────────────────

class _WatchAdTile extends ConsumerWidget {
  const _WatchAdTile();

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

        final String helperText;
        if (removeAds) {
          helperText = 'Ads removed — thanks for your support!';
        } else if (remaining <= 0) {
          helperText = 'Daily limit reached — come back tomorrow';
        } else {
          helperText =
              '$remaining ${remaining == 1 ? 'ad' : 'ads'} remaining today';
        }

        return Card(
          color: Colors.green.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.green.withValues(alpha: canWatch ? 0.4 : 0.15),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_fill,
                      color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Watch Ad — Earn ${RetentionConfig.kBonusAdRewardCoins} Coins',
                        style: AppTheme.bodyStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(helperText,
                          style: AppTheme.bodyStyle(
                              fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: ElevatedButton(
                    onPressed:
                        canWatch ? () => _handleWatchAd(context, ref) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Watch',
                            style: AppTheme.bodyStyle(
                              fontSize: 12,
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
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<void> _handleWatchAd(BuildContext context, WidgetRef ref) async {
    await ref.read(adNotifierProvider.notifier).showAd(
      onReward: (_) {
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
