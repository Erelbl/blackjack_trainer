import 'package:flutter/painting.dart';
import '../../../engine/models/rank.dart';
import '../../../engine/models/suit.dart';

// ---------------------------------------------------------------------------
// Card size — single source of truth.
// Change these two values to resize every card on every screen at once.
// ---------------------------------------------------------------------------

/// Logical-pixel width of a rendered playing card  (was 70 → +8.6 %).
const double kCardWidth  = 76.0;

/// Logical-pixel height of a rendered playing card (was 100 → +8.0 %).
const double kCardHeight = 108.0;

/// Scale factor applied to cards when two hands are shown side-by-side (split
/// mode).  At 0.80× two cards fit in each slot on an iPhone SE (375 px wide).
const double kSplitCardScale = 0.80;

/// Maps Rank/Suit to asset paths and creates correctly-sized image providers.
///
/// Using the SAME provider (ResizeImage wrapping AssetImage with identical
/// width/height) for both precaching and rendering ensures cache hits.
abstract final class CardAssets {
  CardAssets._();

  static const String back = 'assets/cards/back.png';

  static String pathFor(Rank rank, Suit suit) =>
      'assets/cards/${_rankSegment(rank)}_of_${suit.name}.png';

  /// All 52 card paths + card back — pass to precacheImage at startup.
  static List<String> get allPaths => [
        back,
        for (final suit in Suit.values)
          for (final rank in Rank.values) pathFor(rank, suit),
      ];

  /// ResizeImage provider decoded to [decodeW]×[decodeH] physical pixels.
  /// Use this provider in BOTH precacheImage and Image() so they share the
  /// same cache key.
  static ImageProvider provider(
    String path, {
    required int decodeW,
    required int decodeH,
  }) =>
      ResizeImage(AssetImage(path), width: decodeW, height: decodeH);

  static String _rankSegment(Rank rank) => switch (rank) {
        Rank.ace => 'ace',
        Rank.two => '2',
        Rank.three => '3',
        Rank.four => '4',
        Rank.five => '5',
        Rank.six => '6',
        Rank.seven => '7',
        Rank.eight => '8',
        Rank.nine => '9',
        Rank.ten => '10',
        Rank.jack => 'jack',
        Rank.queen => 'queen',
        Rank.king => 'king',
      };
}
