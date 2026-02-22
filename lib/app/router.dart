import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/play/play_screen.dart';
import '../features/training/training_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/store/store_screen.dart';
import '../features/iap/screens/iap_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/play',
        name: 'play',
        builder: (context, state) => const PlayScreen(),
      ),
      GoRoute(
        path: '/training',
        name: 'training',
        builder: (context, state) => const TrainingScreen(),
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: '/store',
        name: 'store',
        builder: (context, state) => const StoreScreen(),
      ),
      GoRoute(
        path: '/iap',
        name: 'iap',
        builder: (context, state) => const IapScreen(),
      ),
    ],
  );
});
