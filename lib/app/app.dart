import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/iap/providers/iap_providers.dart';
import '../features/store/providers/store_providers.dart';
import '../services/ad_service.dart';
import '../services/audio_service.dart';
import 'router.dart';
import 'theme.dart';

class BlackjackTrainerApp extends ConsumerStatefulWidget {
  const BlackjackTrainerApp({super.key});

  @override
  ConsumerState<BlackjackTrainerApp> createState() =>
      _BlackjackTrainerAppState();
}

class _BlackjackTrainerAppState extends ConsumerState<BlackjackTrainerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Warm up ads so they preload before the store is opened.
      ref.read(adNotifierProvider);

      // Warm up audio; BGM auto-starts once SharedPreferences resolves.
      try {
        ref.read(audioServiceProvider);
      } catch (_) {}

      // Silent restore on every launch so theme purchases made on another
      // device are reflected without the user opening the coins screen first.
      try {
        ref.read(iapControllerProvider.notifier).restorePurchases();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    try {
      final audio = ref.read(audioServiceProvider.notifier);
      if (appState == AppLifecycleState.paused ||
          appState == AppLifecycleState.detached) {
        audio.pauseBgm();
      } else if (appState == AppLifecycleState.resumed) {
        audio.resumeBgm();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);

    // Watch the selected theme — rebuilds MaterialApp when the user switches
    // themes. Flutter's AnimatedTheme (inside MaterialApp) automatically lerps
    // between the old and new ThemeData, crossfading every screen's background
    // colour and AppBar tint over 300 ms.
    final themeItem = ref.watch(selectedThemeProvider);

    return MaterialApp.router(
      title: 'Blackjack Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.withTableTheme(themeItem.tokens),
      themeAnimationDuration: const Duration(milliseconds: 500),
      themeAnimationCurve: Curves.easeInOut,
      routerConfig: router,
    );
  }
}
