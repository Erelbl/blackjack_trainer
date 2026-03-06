import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../engine/config/blackjack_rules.dart';
import '../../play/state/blackjack_controller.dart';

// ── Preset helpers ─────────────────────────────────────────────────────────────

enum _Preset { vegas, european, custom }

const _kVegas    = BlackjackRules();
const _kEuropean = BlackjackRules(dealerStandsSoft17: false);
const _kDecks    = [1, 2, 4, 6, 8];

_Preset _presetFor(BlackjackRules r) {
  if (r.deckCount == 6 && r.dealerStandsSoft17 && r.blackjackPayout == 1.5) {
    return _Preset.vegas;
  }
  if (r.deckCount == 6 && !r.dealerStandsSoft17 && r.blackjackPayout == 1.5) {
    return _Preset.european;
  }
  return _Preset.custom;
}

// ── Public entry point ─────────────────────────────────────────────────────────

/// Shows a modal bottom sheet that lets the user change the active
/// [BlackjackRules] via preset chips or custom controls.
///
/// On apply the controller's [setRules] is called immediately.
void showRulesPickerSheet(BuildContext context, WidgetRef ref) {
  final current = ref.read(blackjackControllerProvider).rules;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RulesPickerSheet(
      initial: current,
      onApply: (rules) =>
          ref.read(blackjackControllerProvider.notifier).setRules(rules),
    ),
  );
}

// ── Sheet widget ───────────────────────────────────────────────────────────────

class _RulesPickerSheet extends StatefulWidget {
  const _RulesPickerSheet({
    required this.initial,
    required this.onApply,
  });

  final BlackjackRules initial;
  final void Function(BlackjackRules) onApply;

  @override
  State<_RulesPickerSheet> createState() => _RulesPickerSheetState();
}

class _RulesPickerSheetState extends State<_RulesPickerSheet> {
  late _Preset _preset;
  late int _deckCount;
  late bool _standSoft17;
  late double _bjPayout;

  @override
  void initState() {
    super.initState();
    final r    = widget.initial;
    _preset    = _presetFor(r);
    _deckCount  = r.deckCount;
    _standSoft17 = r.dealerStandsSoft17;
    _bjPayout   = r.blackjackPayout;
  }

  BlackjackRules get _custom => BlackjackRules(
        deckCount: _deckCount,
        dealerStandsSoft17: _standSoft17,
        blackjackPayout: _bjPayout,
      );

  void _applyAndClose() {
    final rules = switch (_preset) {
      _Preset.vegas    => _kVegas,
      _Preset.european => _kEuropean,
      _Preset.custom   => _custom,
    };
    widget.onApply(rules);
    Navigator.of(context).pop();
  }

  void _selectPreset(_Preset p) {
    if (p == _Preset.vegas) {
      setState(() {
        _preset = p;
        _deckCount = 6;
        _standSoft17 = true;
        _bjPayout = 1.5;
      });
    } else if (p == _Preset.european) {
      setState(() {
        _preset = p;
        _deckCount = 6;
        _standSoft17 = false;
        _bjPayout = 1.5;
      });
    } else {
      setState(() => _preset = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D3B1D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Table Rules', style: AppTheme.displayStyle(fontSize: 22)),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset chips
          Row(
            children: _Preset.values.map((p) {
              final label = switch (p) {
                _Preset.vegas    => 'Vegas',
                _Preset.european => 'European',
                _Preset.custom   => 'Custom',
              };
              final isSelected = _preset == p;
              final isLast = p == _Preset.custom;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _selectPreset(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: isLast ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.casinoGold.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.casinoGold.withValues(alpha: 0.70)
                            : Colors.white12,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.casinoGold
                            : Colors.white54,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Custom controls
          if (_preset == _Preset.custom) ...[
            const SizedBox(height: 16),
            _PickerRow(
              label: 'Decks',
              child: DropdownButton<int>(
                value: _deckCount,
                dropdownColor: const Color(0xFF0D3B1D),
                underline: const SizedBox(),
                isDense: true,
                style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white),
                items: _kDecks
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _deckCount = v);
                },
              ),
            ),
            const SizedBox(height: 10),
            _PickerRow(
              label: 'Dealer 17',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleChip(
                    label: 'S17',
                    active: _standSoft17,
                    onTap: () => setState(() => _standSoft17 = true),
                  ),
                  const SizedBox(width: 6),
                  _ToggleChip(
                    label: 'H17',
                    active: !_standSoft17,
                    onTap: () => setState(() => _standSoft17 = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _PickerRow(
              label: 'BJ Pays',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToggleChip(
                    label: '3:2',
                    active: _bjPayout >= 1.5,
                    onTap: () => setState(() => _bjPayout = 1.5),
                  ),
                  const SizedBox(width: 6),
                  _ToggleChip(
                    label: '6:5',
                    active: _bjPayout < 1.5,
                    onTap: () => setState(() => _bjPayout = 1.2),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _applyAndClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.casinoGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Apply Rules',
                style: AppTheme.bodyStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Local helpers ──────────────────────────────────────────────────────────────

class _PickerRow extends StatelessWidget {
  const _PickerRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white70),
        ),
        child,
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.casinoGold.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? AppTheme.casinoGold.withValues(alpha: 0.70)
                : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppTheme.casinoGold : Colors.white38,
          ),
        ),
      ),
    );
  }
}
