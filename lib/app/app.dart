import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/progression_providers.dart';
import 'router.dart';
import 'theme.dart';

class BlackjackTrainerApp extends ConsumerStatefulWidget {
  const BlackjackTrainerApp({super.key});

  @override
  ConsumerState<BlackjackTrainerApp> createState() => _BlackjackTrainerAppState();
}

class _BlackjackTrainerAppState extends ConsumerState<BlackjackTrainerApp> {
  @override
  void initState() {
    super.initState();
    // Trigger daily login check on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(progressionControllerProvider.notifier).onLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Blackjack Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
