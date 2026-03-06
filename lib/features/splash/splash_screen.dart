import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _glow = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1F2A),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glow halo behind logo
                AnimatedBuilder(
                  animation: _glow,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Radial glow
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.casinoGold
                                    .withValues(alpha: 0.18 * _glow.value),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        // Logo — square, no circular crop
                        SizedBox(
                          width: 160,
                          height: 160,
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'BLACKJACK TRAINER',
                  style: AppTheme.displayStyle(
                    fontSize: 28,
                    color: AppTheme.casinoGold,
                    letterSpacing: 3,
                    shadows: AppTheme.goldGlow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
