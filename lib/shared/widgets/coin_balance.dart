import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/economy_providers.dart';

class CoinBalance extends ConsumerWidget {
  const CoinBalance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final economyAsync = ref.watch(economyControllerProvider);

    return economyAsync.when(
      data: (economy) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
          const SizedBox(width: 4),
          Text(
            '${economy.coins}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      loading: () => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Icon(Icons.error, size: 20),
    );
  }
}
