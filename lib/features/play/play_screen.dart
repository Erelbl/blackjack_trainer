import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../engine/game/game_state.dart';
import '../../engine/utils/hand_evaluator.dart';
import '../../shared/widgets/coin_balance.dart';
import '../../app/theme.dart';
import 'state/blackjack_controller.dart';
import 'widgets/table_background.dart';
import 'widgets/card_row.dart';

// Debug performance (set to true to enable logging)
const bool _kLogRebuilds = false;

class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Blackjack', style: GoogleFonts.playfairDisplay()),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CoinBalance(),
          ),
        ],
      ),
      body: const TableBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: 16),
                      _DealerHandView(),
                      SizedBox(height: 40),
                      _ResultBannerView(),
                      _PlayerHandView(),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _ActionBar(),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// Dealer hand - only rebuilds when dealer cards or game state changes
class _DealerHandView extends ConsumerWidget {
  const _DealerHandView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_kLogRebuilds && kDebugMode) {
      debugPrint('[DealerHandView] Rebuild');
    }

    final dealerCards = ref.watch(
      blackjackControllerProvider.select((s) => s.dealerCards),
    );
    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );

    final hideSecondCard = gameState == GameState.playerTurn && dealerCards.length >= 2;
    String totalDisplay = '—';
    if (dealerCards.isNotEmpty && !hideSecondCard) {
      final eval = HandEvaluator.evaluate(dealerCards);
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
    }

    return Column(
      children: [
        Text(
          'DEALER',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.casinoGold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        if (dealerCards.isNotEmpty)
          RepaintBoundary(
            child: Center(
              child: CardRow(
                cards: dealerCards,
                hideLast: hideSecondCard,
              ),
            ),
          )
        else
          const SizedBox(height: 100),
        const SizedBox(height: 8),
        if (!hideSecondCard)
          Text(
            totalDisplay,
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}

// Player hand - only rebuilds when player cards change
class _PlayerHandView extends ConsumerWidget {
  const _PlayerHandView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_kLogRebuilds && kDebugMode) {
      debugPrint('[PlayerHandView] Rebuild');
    }

    final playerCards = ref.watch(
      blackjackControllerProvider.select((s) => s.playerCards),
    );

    String totalDisplay = '—';
    if (playerCards.isNotEmpty) {
      final eval = HandEvaluator.evaluate(playerCards);
      totalDisplay = '${eval.total}${eval.isSoft ? ' (soft)' : ''}';
      if (eval.isBlackjack) {
        totalDisplay += ' - BLACKJACK!';
      }
    }

    return Column(
      children: [
        if (playerCards.isNotEmpty)
          RepaintBoundary(
            child: Center(
              child: CardRow(cards: playerCards),
            ),
          )
        else
          const SizedBox(height: 100),
        const SizedBox(height: 8),
        Text(
          totalDisplay,
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'YOUR HAND',
          style: GoogleFonts.playfairDisplay(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.casinoGold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// Result banner - only rebuilds when result message changes
class _ResultBannerView extends ConsumerWidget {
  const _ResultBannerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultMessage = ref.watch(
      blackjackControllerProvider.select((s) => s.resultMessage),
    );

    if (resultMessage == null) return const SizedBox.shrink();

    final isWin = resultMessage.toLowerCase().contains('win') ||
        resultMessage.toLowerCase().contains('blackjack');
    final color = isWin ? Colors.green : Colors.red;

    // Wrap in IgnorePointer to ensure banner doesn't block button taps
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            resultMessage.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

// Action buttons - only rebuilds when game state changes
class _ActionBar extends ConsumerWidget {
  const _ActionBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_kLogRebuilds && kDebugMode) {
      debugPrint('[ActionBar] Rebuild');
    }

    final gameState = ref.watch(
      blackjackControllerProvider.select((s) => s.gameState),
    );
    final controller = ref.read(blackjackControllerProvider.notifier);

    final isPlayerTurn = gameState == GameState.playerTurn;
    final canStartNewRound = gameState == GameState.idle ||
        gameState == GameState.playerBust ||
        gameState == GameState.dealerBust ||
        gameState == GameState.playerBlackjack ||
        gameState == GameState.push ||
        gameState == GameState.playerWin ||
        gameState == GameState.dealerWin;

    if (kDebugMode) {
      debugPrint('[ActionBar] State: $gameState, isPlayerTurn: $isPlayerTurn, canDeal: $canStartNewRound');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.darkFelt,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (isPlayerTurn) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: controller.hit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                  ),
                  child: const Text('HIT'),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: controller.stand,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.chipRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                  ),
                  child: const Text('STAND'),
                ),
              ),
            ),
          ] else if (canStartNewRound)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () {
                    if (kDebugMode) {
                      debugPrint('[ActionBar] DEAL button pressed - calling startNewRound()');
                    }
                    controller.startNewRound();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                  ),
                  child: const Text('DEAL'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
