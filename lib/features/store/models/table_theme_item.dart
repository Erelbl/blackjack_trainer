import 'package:flutter/material.dart';

// ── Color tokens for one table theme ─────────────────────────────────────────
//
// Also implements ThemeExtension so any widget can read the current tokens via
//   Theme.of(context).extension<TableThemeTokens>()
//
// Flutter's AnimatedTheme (inside MaterialApp) automatically lerps between
// theme instances on change — no manual AnimatedContainer needed.

class TableThemeTokens extends ThemeExtension<TableThemeTokens> {
  final Color centerGlow;   // brightest felt at center of radial gradient
  final Color mid;          // mid-tone felt
  final Color darkFelt;     // darker ring / AppBar background
  final Color edge;         // near-black outer edge + scaffold background
  final Color previewSwatch; // small swatch shown in the store tile

  const TableThemeTokens({
    required this.centerGlow,
    required this.mid,
    required this.darkFelt,
    required this.edge,
    required this.previewSwatch,
  });

  // ── Preset palettes ───────────────────────────────────────────────────────

  static const green = TableThemeTokens(
    centerGlow:    Color(0xFF14783C),
    mid:           Color(0xFF0B5C2C),
    darkFelt:      Color(0xFF083D1F),
    edge:          Color(0xFF020E07),
    previewSwatch: Color(0xFF0D4A25),
  );

  static const neonBlue = TableThemeTokens(
    centerGlow:    Color(0xFF1A4E8C),
    mid:           Color(0xFF0D2E5C),
    darkFelt:      Color(0xFF071A3A),
    edge:          Color(0xFF02070F),
    previewSwatch: Color(0xFF0D2E5C),
  );

  static const vegasRed = TableThemeTokens(
    centerGlow:    Color(0xFF8C2020),
    mid:           Color(0xFF4A1010),
    darkFelt:      Color(0xFF1F0707),
    edge:          Color(0xFF0E0202),
    previewSwatch: Color(0xFF4A1010),
  );

  static const darkElite = TableThemeTokens(
    centerGlow:    Color(0xFF2A2340),
    mid:           Color(0xFF161428),
    darkFelt:      Color(0xFF0D0B1A),
    edge:          Color(0xFF050410),
    previewSwatch: Color(0xFF1A1830),
  );

  // ── ThemeExtension ────────────────────────────────────────────────────────

  @override
  TableThemeTokens copyWith({
    Color? centerGlow,
    Color? mid,
    Color? darkFelt,
    Color? edge,
    Color? previewSwatch,
  }) {
    return TableThemeTokens(
      centerGlow:    centerGlow    ?? this.centerGlow,
      mid:           mid           ?? this.mid,
      darkFelt:      darkFelt      ?? this.darkFelt,
      edge:          edge          ?? this.edge,
      previewSwatch: previewSwatch ?? this.previewSwatch,
    );
  }

  /// Called by Flutter's AnimatedTheme to smoothly interpolate between
  /// two themes. TableBackground rebuilds each frame with the interpolated
  /// colors, giving a buttery gradient crossfade for free.
  @override
  TableThemeTokens lerp(TableThemeTokens? other, double t) {
    if (other == null) return this;
    return TableThemeTokens(
      centerGlow:    Color.lerp(centerGlow,    other.centerGlow,    t)!,
      mid:           Color.lerp(mid,           other.mid,           t)!,
      darkFelt:      Color.lerp(darkFelt,      other.darkFelt,      t)!,
      edge:          Color.lerp(edge,          other.edge,          t)!,
      previewSwatch: Color.lerp(previewSwatch, other.previewSwatch, t)!,
    );
  }
}

// ── A purchasable table theme entry in the store ──────────────────────────────

class TableThemeItem {
  final String id;
  final String displayName;
  final String description;
  final bool isPremium;
  final int coinPrice;          // 0 for free themes
  final String? iapProductId;  // null for free themes
  final TableThemeTokens tokens;

  const TableThemeItem({
    required this.id,
    required this.displayName,
    required this.description,
    required this.isPremium,
    required this.coinPrice,
    required this.tokens,
    this.iapProductId,
  });

  bool get isFree => !isPremium;
}
