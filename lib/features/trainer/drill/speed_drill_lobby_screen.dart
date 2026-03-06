import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../play/widgets/table_background.dart';
import 'drill_controller.dart';

/// Pre-start lobby for the Speed Drill.
///
/// Shows the personal best prominently and lets the player choose when to
/// start. Navigates to [SpeedDrillScreen] at "/speed-drill/run" on tap.
class SpeedDrillLobbyScreen extends ConsumerWidget {
  const SpeedDrillLobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pbAsync = ref.watch(drillBestScoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Drill'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: TableBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 72,
                    color: AppTheme.casinoGold,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SPEED DRILL',
                    style: AppTheme.displayStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '60 seconds  ·  Hit / Stand only',
                    style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score = Correct − Wrong',
                    style: AppTheme.bodyStyle(fontSize: 12, color: Colors.white30),
                    textAlign: TextAlign.center,
                  ),

                  // ── Personal Best card ─────────────────────────────────────
                  const SizedBox(height: 32),
                  pbAsync.when(
                    data:    (pb) => _PbCard(pb: pb),
                    loading: ()   => const SizedBox(height: 72),
                    error:   (_, __) => const SizedBox(height: 72),
                  ),

                  // ── Start button ───────────────────────────────────────────
                  const SizedBox(height: 36),
                  SizedBox(
                    width: 220,
                    child: ElevatedButton(
                      onPressed: () => context.push('/speed-drill/run'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.casinoGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'START',
                        style: AppTheme.bodyStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Personal Best card ────────────────────────────────────────────────────────

class _PbCard extends StatelessWidget {
  final int pb;

  const _PbCard({required this.pb});

  @override
  Widget build(BuildContext context) {
    if (pb <= 0) {
      return Text(
        'No personal best yet — set one!',
        style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white38),
        textAlign: TextAlign.center,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.casinoGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.casinoGold.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(
            'PERSONAL BEST',
            style: AppTheme.bodyStyle(
              fontSize: 11,
              color: AppTheme.casinoGold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pb',
            style: AppTheme.displayStyle(
              fontSize: 52,
              color: AppTheme.casinoGold,
              shadows: AppTheme.goldGlow,
            ),
          ),
        ],
      ),
    );
  }
}
