import 'package:flutter/material.dart' hide Card;
import '../../../engine/models/card.dart';
import 'card_assets.dart';

// ---------------------------------------------------------------------------
// PlayingCardWidget — shows a single card face or back.
// When [faceDown] transitions true→false the card plays a horizontal flip
// animation (scale-X collapse then expand) without any layout changes.
// ---------------------------------------------------------------------------
class PlayingCardWidget extends StatefulWidget {
  final Card? card;
  final bool faceDown;
  final bool animate;

  const PlayingCardWidget({
    super.key,
    this.card,
    this.faceDown = false,
    this.animate = true,
  });

  @override
  State<PlayingCardWidget> createState() => _PlayingCardWidgetState();
}

class _PlayingCardWidgetState extends State<PlayingCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // easeInOut: the card slows at start/end, speeds through the midpoint.
    _flipAnim = CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant PlayingCardWidget old) {
    super.didUpdateWidget(old);
    // Animate only on face-down → face-up transition (dealer hole card reveal).
    if (old.faceDown && !widget.faceDown && widget.animate) {
      _flipCtrl.forward(from: 0);
    } else if (!old.faceDown && widget.faceDown) {
      // Snap instantly back to face-down (e.g. game reset).
      _flipCtrl.reset();
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.card == null) {
      return const SizedBox(width: kCardWidth, height: kCardHeight);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = (kCardWidth  * dpr).ceil();
    final decodeH = (kCardHeight * dpr).ceil();

    return RepaintBoundary(
      child: SizedBox(
        width: kCardWidth,
        height: kCardHeight,
        child: Center(
          child: AspectRatio(
            aspectRatio: 2.5 / 3.5,
            child: AnimatedBuilder(
              animation: _flipAnim,
              builder: (context, _) {
                final t = _flipAnim.value;

                // Determine which face to render:
                //   • While animating (0 < t < 1): show back in first half,
                //     face in second half — mirrors a physical card rotation.
                //   • Not animating (t == 0): follow widget.faceDown directly.
                final showBack = (t > 0 && t < 1.0) ? (t < 0.5) : widget.faceDown;

                // Horizontal scale: 1→0 (first half), 0→1 (second half).
                final scaleX = t < 0.5 ? (1.0 - t * 2.0) : ((t - 0.5) * 2.0);

                final path = showBack
                    ? CardAssets.back
                    : CardAssets.pathFor(widget.card!.rank, widget.card!.suit);

                return Transform.scale(
                  scaleX: scaleX,
                  alignment: Alignment.center,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x28000000), // ~16 % black
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Image(
                      image: CardAssets.provider(
                        path,
                        decodeW: decodeW,
                        decodeH: decodeH,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
