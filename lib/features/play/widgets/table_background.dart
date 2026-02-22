import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class TableBackground extends StatelessWidget {
  final Widget child;

  const TableBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            AppTheme.feltGreen,
            AppTheme.darkFelt,
            AppTheme.darkFelt.withValues(alpha: 0.95),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: child,
    );
  }
}
