import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Test Ad Unit ID for rewarded ads
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _removeAds = false;

  String _lastAdRewardDate = '';
  int _rewardedAdsCountToday = 0;
  static const int _maxAdsPerDay = 7;

  bool get isAdReady => _rewardedAd != null && !_removeAds && _canShowAd();
  bool get isLoading => _isAdLoading;
  int get remainingAds => _maxAdsPerDay - _rewardedAdsCountToday;

  bool _canShowAd() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_lastAdRewardDate != today) {
      return true;
    }
    return _rewardedAdsCountToday < _maxAdsPerDay;
  }

  void setRemoveAds(bool value) {
    _removeAds = value;
  }

  Future<void> loadRewardedAd() async {
    if (_removeAds || _isAdLoading || _rewardedAd != null) {
      return; // Ads disabled, already loading, or loaded
    }

    await _loadAdLimitData();

    if (!_canShowAd()) {
      return; // Daily limit reached
    }

    _isAdLoading = true;

    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          print('Failed to load rewarded ad: $error');
        },
      ),
    );
  }

  Future<void> _loadAdLimitData() async {
    final prefs = await SharedPreferences.getInstance();
    _lastAdRewardDate = prefs.getString('lastAdRewardDate') ?? '';
    _rewardedAdsCountToday = prefs.getInt('rewardedAdsCountToday') ?? 0;
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

  Future<void> showRewardedAd({required Function(int) onReward}) async {
    if (_rewardedAd == null || _removeAds || !_canShowAd()) {
      print('Rewarded ad not available');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        // Preload next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        print('Failed to show rewarded ad: $error');
        // Preload next ad
        loadRewardedAd();
      },
    );

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        await _incrementAdCount();
        onReward(reward.amount.toInt());
      },
    );
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
