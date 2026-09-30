import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The game works without ads: when [isReady] is false the UI simply hides
/// the "watch an ad" button, and an interstitial that never loaded is skipped.
abstract class Ads {
  bool get isReady;

  /// Shows the rewarded ad; true when the player earned the reward.
  Future<bool> showRewarded();

  /// Shows a full-screen ad between two levels. Returns as soon as the ad is
  /// gone, and at once when there is none to show.
  Future<void> showInterstitial();
}

class NoAds implements Ads {
  const NoAds();

  @override
  bool get isReady => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<void> showInterstitial() async {}
}

class AdMobAds implements Ads {
  AdMobAds() {
    _start();
  }

  // Default to Google's public test units; release builds pass the real ones:
  //   flutter build appbundle --dart-define=ADMOB_REWARDED_ID=ca-app-pub-.../...
  //                           --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-.../...
  static const _unitId = String.fromEnvironment(
    'ADMOB_REWARDED_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _interstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// Asks for consent first (GDPR/UMP; the form only appears where required),
  /// and only then starts the ads SDK. Any failure just means no ads.
  Future<void> _start() async {
    try {
      final info = ConsentInformation.instance;
      final updated = Completer<void>();
      info.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => updated.complete(),
        (_) => updated.complete(),
      );
      await updated.future;
      final shown = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((_) => shown.complete());
      await shown.future;
      if (!await info.canRequestAds()) return;
      await MobileAds.instance.initialize();
      _load();
      _loadInterstitial();
    } catch (_) {}
  }

  RewardedAd? _ad;
  InterstitialAd? _interstitial;

  @override
  bool get isReady => _ad != null;

  void _load() {
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _ad = ad,
        onAdFailedToLoad: (_) => _ad = null,
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
        done.complete();
      },
    );
    await ad.show();
    return done.future;
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _load();
        result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _load();
        result.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }
}
