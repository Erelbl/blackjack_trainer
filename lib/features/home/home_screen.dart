import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers/progression_providers.dart';
import '../../shared/widgets/coin_balance.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressionAsync = ref.watch(progressionControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blackjack Trainer'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CoinBalance(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            progressionAsync.whenOrNull(
              data: (progression) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Level ${progression.level}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ) ?? const SizedBox.shrink(),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.push('/play'),
              child: const Text('Play'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/training'),
              child: const Text('Training'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/stats'),
              child: const Text('Stats'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/store'),
              child: const Text('Store'),
            ),
          ],
        ),
      ),
    );
  }
}
