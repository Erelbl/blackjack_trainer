import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/config/blackjack_rules.dart';
import 'simulator_engine.dart';

// ── State ──────────────────────────────────────────────────────────────────────

class SimulatorState {
  const SimulatorState({
    this.running = false,
    this.result,
    this.error,
    this.selectedHands = 50000,
    this.lastRunRules,
  });

  final bool running;
  final SimResult? result;
  final String? error;

  /// One of 10000, 50000, 100000.
  final int selectedHands;

  /// The [BlackjackRules] that produced [result].  Null until the first
  /// successful run.  Used to display "Last run: …" and detect staleness.
  final BlackjackRules? lastRunRules;
}

// ── Controller ─────────────────────────────────────────────────────────────────

class SimulatorController extends StateNotifier<SimulatorState> {
  SimulatorController() : super(const SimulatorState());

  void setHands(int hands) {
    if (state.running) return;
    state = SimulatorState(
      selectedHands: hands,
      result: state.result,
      error: state.error,
      lastRunRules: state.lastRunRules,
    );
  }

  /// Clears results when the active rules have changed, so the UI can prompt
  /// the user to re-run.  Does nothing if a simulation is in progress.
  void resetForRulesChange() {
    if (state.running) return;
    state = SimulatorState(selectedHands: state.selectedHands);
  }

  Future<void> run(BlackjackRules rules) async {
    if (state.running) return;
    state = SimulatorState(running: true, selectedHands: state.selectedHands);
    try {
      final result = await SimulatorEngine.estimate(
        rules,
        hands: state.selectedHands,
      );
      if (!mounted) return;
      state = SimulatorState(
        result: result,
        selectedHands: state.selectedHands,
        lastRunRules: rules,
      );
    } catch (_) {
      if (!mounted) return;
      state = SimulatorState(
        error: 'Simulation failed. Please try again.',
        selectedHands: state.selectedHands,
      );
    }
  }
}

// ── Provider ───────────────────────────────────────────────────────────────────

final simulatorControllerProvider =
    StateNotifierProvider<SimulatorController, SimulatorState>(
  (ref) => SimulatorController(),
);
