import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Resolves AdMob app / ad unit IDs for the current platform and build mode.
class AdMobConfig {
  AdMobConfig._();

  static bool get useProductionAds => kReleaseMode;

  // ── App IDs (AndroidManifest / Info.plist) ───────────────────────────────

  static const androidTestAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const iosTestAppId = 'ca-app-pub-3940256099942544~1458002511';

  /// Replace with your production AdMob app IDs before shipping.
  static const androidProductionAppId =
      'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY';
  static const iosProductionAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY';

  static String get appId {
    if (Platform.isAndroid) {
      return useProductionAds ? androidProductionAppId : androidTestAppId;
    }
    if (Platform.isIOS) {
      return useProductionAds ? iosProductionAppId : iosTestAppId;
    }
    return '';
  }

  // ── Banner ───────────────────────────────────────────────────────────────

  static const androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const androidProductionBanner =
      'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB';
  static const iosProductionBanner = 'ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII';

  static String get banner {
    if (Platform.isAndroid) {
      return useProductionAds ? androidProductionBanner : androidTestBanner;
    }
    if (Platform.isIOS) {
      return useProductionAds ? iosProductionBanner : iosTestBanner;
    }
    return '';
  }

  // ── Interstitial ─────────────────────────────────────────────────────────

  static const androidTestInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const iosTestInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const androidProductionInterstitial =
      'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB';
  static const iosProductionInterstitial =
      'ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII';

  static String get interstitial {
    if (Platform.isAndroid) {
      return useProductionAds
          ? androidProductionInterstitial
          : androidTestInterstitial;
    }
    if (Platform.isIOS) {
      return useProductionAds
          ? iosProductionInterstitial
          : iosTestInterstitial;
    }
    return '';
  }

  // ── Rewarded ─────────────────────────────────────────────────────────────

  static const androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';
  static const androidProductionRewarded =
      'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB';
  static const iosProductionRewarded =
      'ca-app-pub-XXXXXXXXXXXXXXXX/IIIIIIIIII';

  static String get rewarded {
    if (Platform.isAndroid) {
      return useProductionAds ? androidProductionRewarded : androidTestRewarded;
    }
    if (Platform.isIOS) {
      return useProductionAds ? iosProductionRewarded : iosTestRewarded;
    }
    return '';
  }
}

/// Centralized Google Mobile Ads loader with preload and exponential backoff.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  static const _backoffDelays = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
  ];

  bool _initialized = false;
  bool _disposed = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  int _interstitialLoadAttempts = 0;
  int _rewardedLoadAttempts = 0;

  Timer? _interstitialRetryTimer;
  Timer? _rewardedRetryTimer;

  bool get isInitialized => _initialized;
  bool get isInterstitialReady => _interstitialAd != null;
  bool get isRewardedReady => _rewardedAd != null;

  String get bannerAdUnitId => AdMobConfig.banner;

  /// Initializes the SDK and preloads full-screen ad formats.
  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('AdService: ads are only supported on Android and iOS.');
      return;
    }

    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
    _loadRewarded();
  }

  Future<bool> showInterstitial() async {
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    ad.show();
    return true;
  }

  Future<bool> showRewarded({
    required void Function(RewardItem reward) onUserEarnedReward,
    VoidCallback? onAdDismissed,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      _loadRewarded();
      return false;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        _rewardedAd = null;
        onAdDismissed?.call();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('AdService: rewarded show failed — $error');
        failedAd.dispose();
        _rewardedAd = null;
        _loadRewarded();
      },
    );

    ad.show(
      onUserEarnedReward: (_, reward) => onUserEarnedReward(reward),
    );
    return true;
  }

  /// Shows a rewarded ad and completes when it closes. Returns true only if
  /// [onUserEarnedReward] fired (full watch).
  Future<bool> showRewardedAndWaitForReward() async {
    if (!_initialized) return false;

    final ad = _rewardedAd;
    if (ad == null) {
      _loadRewarded();
      return false;
    }

    final completer = Completer<bool>();
    var earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint('AdService: rewarded show failed — $error');
        failedAd.dispose();
        _rewardedAd = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(onUserEarnedReward: (_, reward) => earned = true);
    return completer.future;
  }

  void dispose() {
    _disposed = true;
    _interstitialRetryTimer?.cancel();
    _rewardedRetryTimer?.cancel();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
    _initialized = false;
  }

  void _loadInterstitial() {
    if (_disposed || !_initialized) return;

    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoadAttempts = 0;
          _interstitialRetryTimer?.cancel();
          _interstitialAd?.dispose();
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (dismissedAd) {
              dismissedAd.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (failedAd, error) {
              debugPrint('AdService: interstitial show failed — $error');
              failedAd.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: interstitial load failed — $error');
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _scheduleInterstitialRetry();
        },
      ),
    );
  }

  void _loadRewarded() {
    if (_disposed || !_initialized) return;

    RewardedAd.load(
      adUnitId: AdMobConfig.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoadAttempts = 0;
          _rewardedRetryTimer?.cancel();
          _rewardedAd?.dispose();
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: rewarded load failed — $error');
          _rewardedAd?.dispose();
          _rewardedAd = null;
          _scheduleRewardedRetry();
        },
      ),
    );
  }

  void _scheduleInterstitialRetry() {
    _scheduleRetry(
      currentAttempt: _interstitialLoadAttempts,
      onAttemptAdvanced: (next) => _interstitialLoadAttempts = next,
      onRetry: _loadInterstitial,
      timerSetter: (timer) => _interstitialRetryTimer = timer,
    );
  }

  void _scheduleRewardedRetry() {
    _scheduleRetry(
      currentAttempt: _rewardedLoadAttempts,
      onAttemptAdvanced: (next) => _rewardedLoadAttempts = next,
      onRetry: _loadRewarded,
      timerSetter: (timer) => _rewardedRetryTimer = timer,
    );
  }

  void _scheduleRetry({
    required int currentAttempt,
    required void Function(int nextAttempt) onAttemptAdvanced,
    required VoidCallback onRetry,
    required void Function(Timer? timer) timerSetter,
  }) {
    if (_disposed) return;

    final delayIndex = currentAttempt.clamp(0, _backoffDelays.length - 1);
    final delay = _backoffDelays[delayIndex];
    onAttemptAdvanced((currentAttempt + 1) % _backoffDelays.length);

    timerSetter(null);
    timerSetter(
      Timer(delay, () {
        if (!_disposed) onRetry();
      }),
    );
  }
}
