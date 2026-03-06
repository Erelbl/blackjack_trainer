import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/config/retention_config.dart';

class AdState {
  final bool isLoading;
  final bool isReady;
  final int remainingAds;
  final int remainingRevives;

  const AdState({
    this.isLoading = false,
    this.isReady = false,
    this.remainingAds = 7,
    this.remainingRevives = RetentionConfig.kMaxRevivesPerDay,
  });

  AdState copyWith({
    bool? isLoading,
    bool? isReady,
    int? remainingAds,
    int? remainingRevives,
  }) =>
      AdState(
        isLoading: isLoading ?? this.isLoading,
        isReady: isReady ?? this.isReady,
        remainingAds: remainingAds ?? this.remainingAds,
        remainingRevives: remainingRevives ?? this.remainingRevives,
      );
}

class AdNotifier extends StateNotifier<AdState> {
  // TODO(release): Replace the production ID with your real AdMob rewarded
  // ad unit ID before publishing. The current value is Google's test ID.
  static const String _testAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _prodAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static String get _rewardedAdUnitId =>
      kDebugMode ? _testAdUnitId : _prodAdUnitId;

  static const int _maxAdsPerDay = 7;

  RewardedAd? _rewardedAd;
  String _lastAdRewardDate = '';
  int _rewardedAdsCountToday = 0;

  // Revive ad tracking — keyed by date so it auto-resets each calendar day.
  String _lastReviveDateStr = '';
  int _reviveAdsToday = 0;

  AdNotifier() : super(const AdState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadAdLimitData();
    state = state.copyWith(
      remainingAds: _remaining(),
      remainingRevives: _remainingRevives(),
    );
    await _loadAd();
  }

  // ── Revive helpers ─────────────────────────────────────────────────────────

  int _remainingRevives() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final count = _lastReviveDateStr == today ? _reviveAdsToday : 0;
    return (RetentionConfig.kMaxRevivesPerDay - count)
        .clamp(0, RetentionConfig.kMaxRevivesPerDay);
  }

  bool canRevive() => _remainingRevives() > 0;

  int _remaining() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final count =
        _lastAdRewardDate == today ? _rewardedAdsCountToday : 0;
    final r = _maxAdsPerDay - count;
    return r > 0 ? r : 0;
  }

  bool _canShowAd() => _remaining() > 0;

  Future<void> _loadAdLimitData() async {
    final prefs = await SharedPreferences.getInstance();
    _lastAdRewardDate = prefs.getString('lastAdRewardDate') ?? '';
    _rewardedAdsCountToday = prefs.getInt('rewardedAdsCountToday') ?? 0;

    // Revive count is keyed by date (revive_ads_YYYYMMDD) so it auto-expires.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _lastReviveDateStr = today;
    _reviveAdsToday =
        prefs.getInt('revive_ads_${today.replaceAll('-', '')}') ?? 0;
  }

  Future<void> _loadAd() async {
    if (!mounted) return;
    if (state.isLoading || _rewardedAd != null) return;
    if (!_canShowAd()) return;

    state = state.copyWith(isLoading: true, isReady: false);

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _rewardedAd = ad;
          state = state.copyWith(isLoading: false, isReady: true);
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          state = state.copyWith(isLoading: false, isReady: false);
          // Retry after a delay
          Future.delayed(const Duration(minutes: 1), () {
            if (mounted) _loadAd();
          });
        },
      ),
    );
  }

  Future<void> showAd({required void Function(int) onReward}) async {
    if (_rewardedAd == null || !_canShowAd()) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        if (mounted) {
          state = state.copyWith(isReady: false);
          _loadAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (mounted) {
          state = state.copyWith(isReady: false);
          _loadAd();
        }
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        await _incrementAdCount();
        if (mounted) state = state.copyWith(remainingAds: _remaining());
        onReward(reward.amount.toInt());
      },
    );
  }

  /// Shows a rewarded ad for the out-of-coins revive flow.
  ///
  /// Grants [RetentionConfig.kReviveAdRewardCoins] and counts against the
  /// per-day revive cap ([RetentionConfig.kMaxRevivesPerDay]).  If the cap is
  /// reached the call is silently ignored — the caller should check
  /// [canRevive()] / [AdState.remainingRevives] before showing the button.
  Future<void> showReviveAd({required void Function(int) onReward}) async {
    if (_rewardedAd == null || !_canShowAd()) return;
    if (!canRevive()) {
      if (kDebugMode) {
        debugPrint(
          '[Ad] Revive blocked — cap reached '
          '($_reviveAdsToday/${RetentionConfig.kMaxRevivesPerDay} today)',
        );
      }
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        if (mounted) {
          state = state.copyWith(isReady: false);
          _loadAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (mounted) {
          state = state.copyWith(isReady: false);
          _loadAd();
        }
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        await _incrementReviveCount();
        if (mounted) {
          state = state.copyWith(remainingRevives: _remainingRevives());
        }
        onReward(reward.amount.toInt());
      },
    );
  }

  Future<void> _incrementReviveCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    if (_lastReviveDateStr != today) {
      _lastReviveDateStr = today;
      _reviveAdsToday = 0;
    }
    _reviveAdsToday++;
    await prefs.setInt(
        'revive_ads_${today.replaceAll('-', '')}', _reviveAdsToday);
    if (kDebugMode) {
      debugPrint(
        '[Ad] Revive granted +${RetentionConfig.kReviveAdRewardCoins} coins. '
        'Count today: $_reviveAdsToday/${RetentionConfig.kMaxRevivesPerDay}',
      );
    }
  }

  Future<void> _incrementAdCount() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final prefs = await SharedPreferences.getInstance();
    if (_lastAdRewardDate != today) {
      _lastAdRewardDate = today;
      _rewardedAdsCountToday = 0;
    }
    _rewardedAdsCountToday++;
    await prefs.setString('lastAdRewardDate', _lastAdRewardDate);
    await prefs.setInt('rewardedAdsCountToday', _rewardedAdsCountToday);
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}

final adNotifierProvider =
    StateNotifierProvider<AdNotifier, AdState>((ref) => AdNotifier());
