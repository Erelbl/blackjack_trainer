import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/play/play_screen.dart';
import '../features/training/training_screen.dart';
import '../features/stats/stats_screen.dart';
import '../features/store/store_screen.dart';
import '../features/iap/screens/iap_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/trainer/drill/daily_drill_screen.dart';
import '../features/trainer/drill/speed_drill_lobby_screen.dart';
import '../features/trainer/drill/speed_drill_screen.dart';
import '../features/trainer/counting/counting_basics_screen.dart';
import '../features/trainer/counting/counting_trainer_screen.dart';
import '../features/trainer/house_edge/house_edge_screen.dart';
import '../features/trainer/simulator/simulator_screen.dart';

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
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/house-edge',
        name: 'house-edge',
        builder: (context, state) => const HouseEdgeScreen(),
      ),
      GoRoute(
        path: '/simulator',
        name: 'simulator',
        builder: (context, state) => const SimulatorScreen(),
      ),
      GoRoute(
        path: '/daily-drill',
        name: 'daily-drill',
        builder: (context, state) => const DailyDrillScreen(),
      ),
      GoRoute(
        path: '/trainer/counting',
        name: 'counting',
        builder: (context, state) => const CountingTrainerScreen(),
        routes: [
          GoRoute(
            path: 'basics',
            name: 'counting-basics',
            builder: (context, state) => const CountingBasicsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/speed-drill',
        name: 'speed-drill',
        builder: (context, state) => const SpeedDrillLobbyScreen(),
        routes: [
          GoRoute(
            path: 'run',
            name: 'speed-drill-run',
            builder: (context, state) => const SpeedDrillScreen(),
          ),
        ],
      ),
    ],
  );
});
