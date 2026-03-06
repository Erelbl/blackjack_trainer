import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers/stats_providers.dart';

// ─── SharedPreferences keys ───────────────────────────────────────────────────
const _kBgmEnabled = 'audio_bgm_enabled';
const _kSfxEnabled = 'audio_sfx_enabled';
const _kBgmVolume  = 'audio_bgm_volume';
const _kSfxVolume  = 'audio_sfx_volume';

// ─── Defaults – deliberately low to avoid being obnoxious ────────────────────
const _kDefaultBgmVol = 0.3;
const _kDefaultSfxVol = 0.6;

// ─── BGM asset path ───────────────────────────────────────────────────────────
const _kBgmPath = 'audio/bgm_loop.mp3';

// ─── SFX catalogue ────────────────────────────────────────────────────────────
enum SfxType { click, deal, win, lose }

const _kSfxPaths = <SfxType, String>{
  SfxType.click : 'audio/sfx_click.mp3',
  SfxType.deal  : 'audio/sfx_deal.mp3',
  SfxType.win   : 'audio/sfx_win.mp3',
  SfxType.lose  : 'audio/sfx_lose.mp3',
};

// ─── Immutable state exposed to the UI ───────────────────────────────────────
class AudioState {
  final bool   bgmEnabled;
  final bool   sfxEnabled;
  final double bgmVolume;
  final double sfxVolume;

  const AudioState({
    this.bgmEnabled = true,
    this.sfxEnabled = true,
    this.bgmVolume  = _kDefaultBgmVol,
    this.sfxVolume  = _kDefaultSfxVol,
  });

  AudioState copyWith({
    bool?   bgmEnabled,
    bool?   sfxEnabled,
    double? bgmVolume,
    double? sfxVolume,
  }) => AudioState(
    bgmEnabled: bgmEnabled ?? this.bgmEnabled,
    sfxEnabled: sfxEnabled ?? this.sfxEnabled,
    bgmVolume:  bgmVolume  ?? this.bgmVolume,
    sfxVolume:  sfxVolume  ?? this.sfxVolume,
  );
}

// ─── Service ──────────────────────────────────────────────────────────────────
class AudioService extends StateNotifier<AudioState> {
  AudioService(this._prefs) : super(const AudioState()) {
    _loadSettings();
    // Fire-and-forget: init players then auto-start BGM if enabled.
    _initPlayers().then((_) {
      if (state.bgmEnabled) startBgm();
    });
  }

  final SharedPreferences _prefs;

  final _bgmPlayer  = AudioPlayer();
  final _sfxPlayers = <SfxType, AudioPlayer>{};

  /// Whether BGM was deliberately started (guards resume-after-lifecycle).
  bool _bgmPlaying = false;

  /// Timestamp of last click SFX – used for debounce.
  DateTime? _lastClick;
  static const _kClickDebounce = Duration(milliseconds: 200);

  // ── Initialisation ──────────────────────────────────────────────────────────

  void _loadSettings() {
    state = AudioState(
      bgmEnabled: _prefs.getBool(_kBgmEnabled)  ?? true,
      sfxEnabled: _prefs.getBool(_kSfxEnabled)  ?? true,
      bgmVolume:  _prefs.getDouble(_kBgmVolume) ?? _kDefaultBgmVol,
      sfxVolume:  _prefs.getDouble(_kSfxVolume) ?? _kDefaultSfxVol,
    );
    debugPrint('[Audio] loaded – bgm=${state.bgmEnabled} sfx=${state.sfxEnabled} '
        'bgmVol=${state.bgmVolume} sfxVol=${state.sfxVolume}');
  }

  Future<void> _initPlayers() async {
    await _bgmPlayer.setVolume(state.bgmVolume);

    for (final type in SfxType.values) {
      final path = _kSfxPaths[type]!;
      final player = AudioPlayer();
      await player.setVolume(state.sfxVolume);
      _sfxPlayers[type] = player;
      // Best-effort preload to minimise first-play latency.
      try {
        await player.setSource(AssetSource(path));
        debugPrint('[Audio] preloaded $path');
      } catch (e) {
        debugPrint('[Audio] preload FAILED for $path: $e');
      }
    }
  }

  // ── BGM ─────────────────────────────────────────────────────────────────────

  Future<void> startBgm() async {
    if (!state.bgmEnabled) return;
    debugPrint('[Audio] startBgm() → $_kBgmPath');
    try {
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(state.bgmVolume);
      await _bgmPlayer.play(AssetSource(_kBgmPath));
      _bgmPlaying = true;
    } catch (e) {
      debugPrint('[Audio] startBgm() FAILED (path: $_kBgmPath): $e');
    }
  }

  Future<void> stopBgm() async {
    _bgmPlaying = false;
    try { await _bgmPlayer.stop(); } catch (e) {
      debugPrint('[Audio] stopBgm() FAILED: $e');
    }
  }

  Future<void> pauseBgm() async {
    try { await _bgmPlayer.pause(); } catch (e) {
      debugPrint('[Audio] pauseBgm() FAILED: $e');
    }
  }

  Future<void> resumeBgm() async {
    if (!state.bgmEnabled || !_bgmPlaying) return;
    try { await _bgmPlayer.resume(); } catch (e) {
      debugPrint('[Audio] resumeBgm() FAILED: $e');
    }
  }

  // ── SFX ─────────────────────────────────────────────────────────────────────

  Future<void> playSfx(SfxType type) async {
    if (!state.sfxEnabled) return;

    if (type == SfxType.click) {
      final now = DateTime.now();
      if (_lastClick != null &&
          now.difference(_lastClick!) < _kClickDebounce) {
        return;
      }
      _lastClick = now;
    }

    final player = _sfxPlayers[type];
    if (player == null) {
      debugPrint('[Audio] playSfx($type) – player not ready yet, skipping');
      return;
    }

    final path = _kSfxPaths[type]!;
    debugPrint('[Audio] playSfx($type) → $path');
    try {
      await player.play(AssetSource(path));
    } catch (e) {
      debugPrint('[Audio] playSfx($type) FAILED (path: $path): $e');
    }
  }

  // ── Settings ─────────────────────────────────────────────────────────────────

  Future<void> setBgmEnabled(bool enabled) async {
    state = state.copyWith(bgmEnabled: enabled);
    await _prefs.setBool(_kBgmEnabled, enabled);
    debugPrint('[Audio] setBgmEnabled($enabled)');
    if (!enabled) {
      await stopBgm();
    } else {
      await startBgm();
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    state = state.copyWith(sfxEnabled: enabled);
    await _prefs.setBool(_kSfxEnabled, enabled);
    debugPrint('[Audio] setSfxEnabled($enabled)');
  }

  Future<void> setBgmVolume(double volume) async {
    state = state.copyWith(bgmVolume: volume);
    await _prefs.setDouble(_kBgmVolume, volume);
    await _bgmPlayer.setVolume(volume);
  }

  Future<void> setSfxVolume(double volume) async {
    state = state.copyWith(sfxVolume: volume);
    await _prefs.setDouble(_kSfxVolume, volume);
    for (final p in _sfxPlayers.values) {
      await p.setVolume(volume);
    }
  }

  @override
  void dispose() {
    _bgmPlayer.dispose();
    for (final p in _sfxPlayers.values) {
      p.dispose();
    }
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final audioServiceProvider =
    StateNotifierProvider<AudioService, AudioState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).value;
  if (prefs == null) throw Exception('SharedPreferences not initialized');
  return AudioService(prefs);
});
