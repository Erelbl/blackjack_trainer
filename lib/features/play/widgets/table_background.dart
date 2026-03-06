import 'package:flutter/material.dart';
import '../../../features/store/models/table_theme_item.dart';

/// Full-screen radial gradient that wraps every game screen.
///
/// Colors are read from the ambient [TableThemeTokens] ThemeExtension.
/// When the user switches themes, [MaterialApp] animates the full [ThemeData]
/// via [AnimatedTheme] (500 ms easeInOut) which calls [TableThemeTokens.lerp]
/// every frame — this widget crossfades automatically, no extra code needed.
class TableBackground extends StatelessWidget {
  final Widget child;

  const TableBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<TableThemeTokens>() ?? TableThemeTokens.green;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [
            tokens.centerGlow,
            tokens.mid,
            tokens.darkFelt,
            tokens.edge,
          ],
          stops: const [0.0, 0.3, 0.68, 1.0],
        ),
      ),
      child: child,
    );
  }
}
