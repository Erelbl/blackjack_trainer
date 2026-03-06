import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_constants.dart';
import '../../app/theme.dart';
import '../../engine/config/blackjack_rules.dart';
import '../../features/iap/providers/iap_providers.dart';
import '../../services/audio_service.dart';
import '../play/state/blackjack_controller.dart';

// ── Constants — update before release ────────────────────────────────────────

const _kSupportEmail = 'blackjacktrainer.app@gmail.com';
const _kAppVersion = '1.0.0';

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audio = ref.watch(audioServiceProvider);
    final service = ref.read(audioServiceProvider.notifier);
    final iapStateAsync = ref.watch(iapControllerProvider);
    final isRestoring = iapStateAsync.value?.isRestoring ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          // ── MUSIC ────────────────────────────────────────────────────────
          _SectionLabel('MUSIC'),
          _ToggleRow(
            label: 'Background Music',
            value: audio.bgmEnabled,
            onChanged: service.setBgmEnabled,
          ),
          _SliderRow(
            label: 'Music Volume',
            value: audio.bgmVolume,
            enabled: audio.bgmEnabled,
            onChanged: (v) {
              service.setBgmVolume(v);
            },
          ),
          const SizedBox(height: 28),

          // ── SOUND EFFECTS ─────────────────────────────────────────────────
          _SectionLabel('SOUND EFFECTS'),
          _ToggleRow(
            label: 'Sound Effects',
            value: audio.sfxEnabled,
            onChanged: service.setSfxEnabled,
          ),
          _SliderRow(
            label: 'SFX Volume',
            value: audio.sfxVolume,
            enabled: audio.sfxEnabled,
            onChanged: (v) {
              service.setSfxVolume(v);
            },
          ),
          const SizedBox(height: 28),

          // ── TABLE RULES ───────────────────────────────────────────────────
          _SectionLabel('TABLE RULES'),
          const _TableRulesSection(),
          const SizedBox(height: 28),

          // ── PURCHASES ─────────────────────────────────────────────────────
          _SectionLabel('PURCHASES'),
          _ActionRow(
            label: 'Restore Purchases',
            icon: Icons.restore,
            trailing: isRestoring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: isRestoring
                ? null
                : () {
                    ref
                        .read(iapControllerProvider.notifier)
                        .restorePurchases();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Restoring purchases…'),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 28),

          // ── LEGAL ─────────────────────────────────────────────────────────
          _SectionLabel('LEGAL'),
          _LinkRow(
            label: 'Privacy Policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () => _launchUrl(privacyPolicyUrl, context),
          ),
          _LinkRow(
            label: 'Terms of Service',
            icon: Icons.description_outlined,
            onTap: () => _launchUrl(termsOfServiceUrl, context),
          ),
          _LinkRow(
            label: 'Contact Support',
            icon: Icons.email_outlined,
            onTap: () =>
                _launchUrl('mailto:$_kSupportEmail', context),
          ),
          const SizedBox(height: 28),

          // ── ABOUT ─────────────────────────────────────────────────────────
          _SectionLabel('ABOUT'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Version',
                  style: AppTheme.bodyStyle(
                      fontSize: 15, color: Colors.white),
                ),
                Text(
                  _kAppVersion,
                  style: AppTheme.bodyStyle(
                      fontSize: 15, color: Colors.white54),
                ),
              ],
            ),
          ),

          // Gambling / simulation disclaimer — required for store compliance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              'This app is a simulation only. No real money gambling. '
              'In-game coins have no monetary value and cannot be '
              'exchanged for real currency or prizes.',
              style: AppTheme.bodyStyle(
                  fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Unable to open link. Please check your internet connection.')),
        );
      }
    }
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppTheme.displayStyle(
          fontSize: 18,
          letterSpacing: 3,
          color: AppTheme.casinoGold,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodyStyle(fontSize: 15, color: Colors.white),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppTheme.casinoGold
                : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppTheme.casinoGold.withValues(alpha: 0.45)
                : null,
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: enabled ? Colors.white70 : Colors.white30,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.casinoGold
                  .withValues(alpha: enabled ? 1.0 : 0.35),
              thumbColor: enabled ? AppTheme.casinoGold : Colors.white30,
              inactiveTrackColor: Colors.white12,
              overlayColor:
                  AppTheme.casinoGold.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: value,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// A tappable row with an icon, label, and optional trailing widget.
/// Used for actions like "Restore Purchases".
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: onTap != null
                    ? AppTheme.casinoGold
                    : Colors.white30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyStyle(
                  fontSize: 15,
                  color:
                      onTap != null ? Colors.white : Colors.white38,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right,
                    size: 18,
                    color: onTap != null
                        ? Colors.white38
                        : Colors.white12),
          ],
        ),
      ),
    );
  }
}

/// A tappable row that opens an external URL.
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white54),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyStyle(
                    fontSize: 15, color: Colors.white),
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ── Table Rules ───────────────────────────────────────────────────────────────

enum _Preset { vegas, european, custom }

const _kVegasRules    = BlackjackRules();
const _kEuropeanRules = BlackjackRules(dealerStandsSoft17: false);
const _kDecks         = [1, 2, 4, 6, 8];

_Preset _presetFor(BlackjackRules r) {
  if (r.deckCount == 6 && r.dealerStandsSoft17 && r.blackjackPayout == 1.5) {
    return _Preset.vegas;
  }
  if (r.deckCount == 6 && !r.dealerStandsSoft17 && r.blackjackPayout == 1.5) {
    return _Preset.european;
  }
  return _Preset.custom;
}

class _TableRulesSection extends ConsumerStatefulWidget {
  const _TableRulesSection();

  @override
  ConsumerState<_TableRulesSection> createState() =>
      _TableRulesSectionState();
}

class _TableRulesSectionState extends ConsumerState<_TableRulesSection> {
  late _Preset _preset;
  late int _deckCount;
  late bool _standSoft17;
  late double _bjPayout;

  @override
  void initState() {
    super.initState();
    final rules = ref.read(blackjackControllerProvider).rules;
    _preset     = _presetFor(rules);
    _deckCount  = rules.deckCount;
    _standSoft17 = rules.dealerStandsSoft17;
    _bjPayout   = rules.blackjackPayout;
  }

  void _apply(BlackjackRules rules) {
    ref.read(blackjackControllerProvider.notifier).setRules(rules);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Rules applied',
            style: AppTheme.bodyStyle(fontSize: 13, color: Colors.white),
          ),
          duration: const Duration(milliseconds: 1500),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
  }

  void _selectPreset(_Preset preset) {
    if (_preset == preset) return;
    if (preset == _Preset.vegas) {
      setState(() {
        _preset = preset;
        _deckCount = 6; _standSoft17 = true; _bjPayout = 1.5;
      });
      _apply(_kVegasRules);
    } else if (preset == _Preset.european) {
      setState(() {
        _preset = preset;
        _deckCount = 6; _standSoft17 = false; _bjPayout = 1.5;
      });
      _apply(_kEuropeanRules);
    } else {
      // Custom: reveal controls, no immediate apply.
      setState(() => _preset = preset);
    }
  }

  BlackjackRules get _customRules => BlackjackRules(
        deckCount: _deckCount,
        dealerStandsSoft17: _standSoft17,
        blackjackPayout: _bjPayout,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Applies to Game + Trainer',
          style: AppTheme.bodyStyle(fontSize: 11, color: Colors.white38),
        ),
        const SizedBox(height: 10),

        // ── Preset chips ──────────────────────────────────────────────
        Row(
          children: _Preset.values.map((p) {
            final label = switch (p) {
              _Preset.vegas    => 'Vegas',
              _Preset.european => 'European',
              _Preset.custom   => 'Custom',
            };
            final selected = _preset == p;
            final isLast = p == _Preset.custom;
            return Expanded(
              child: GestureDetector(
                onTap: () => _selectPreset(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: isLast ? 0 : 6),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.casinoGold.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppTheme.casinoGold.withValues(alpha: 0.7)
                          : Colors.white12,
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppTheme.casinoGold
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // ── Custom controls ───────────────────────────────────────────
        if (_preset == _Preset.custom) ...[
          const SizedBox(height: 14),

          // Decks
          _RulesRow(
            label: 'Decks',
            child: DropdownButton<int>(
              value: _deckCount,
              dropdownColor: const Color(0xFF1A2E1A),
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
                _apply(_customRules);
              },
            ),
          ),
          const SizedBox(height: 4),

          // Dealer rule
          _RulesRow(
            label: 'Dealer',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'H17',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: _standSoft17
                        ? Colors.white30
                        : AppTheme.casinoGold,
                  ),
                ),
                Switch(
                  value: _standSoft17,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  thumbColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? AppTheme.casinoGold
                        : null,
                  ),
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected)
                        ? AppTheme.casinoGold.withValues(alpha: 0.45)
                        : null,
                  ),
                  onChanged: (v) {
                    setState(() => _standSoft17 = v);
                    _apply(_customRules);
                  },
                ),
                Text(
                  'S17',
                  style: AppTheme.bodyStyle(
                    fontSize: 12,
                    color: _standSoft17
                        ? AppTheme.casinoGold
                        : Colors.white30,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Blackjack payout
          _RulesRow(
            label: 'BJ Payout',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PayoutChip(
                  label: '3:2',
                  value: 1.5,
                  current: _bjPayout,
                  onTap: () {
                    setState(() => _bjPayout = 1.5);
                    _apply(_customRules);
                  },
                ),
                const SizedBox(width: 6),
                _PayoutChip(
                  label: '6:5',
                  value: 1.2,
                  current: _bjPayout,
                  onTap: () {
                    setState(() => _bjPayout = 1.2);
                    _apply(_customRules);
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RulesRow extends StatelessWidget {
  const _RulesRow({required this.label, required this.child});

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

class _PayoutChip extends StatelessWidget {
  const _PayoutChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String label;
  final double value;
  final double current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.casinoGold.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? AppTheme.casinoGold.withValues(alpha: 0.7)
                : Colors.white12,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTheme.bodyStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.casinoGold : Colors.white38,
          ),
        ),
      ),
    );
  }
}
