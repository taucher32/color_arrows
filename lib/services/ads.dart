import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The game works without ads: while [ready] is false the UI simply hides
/// the "watch an ad" button, and an interstitial that never loaded is skipped.
abstract class Ads {
  /// Whether a rewarded ad is loaded. A listenable, so a button that is
  /// already on screen appears as soon as the ad finishes loading.
  ValueListenable<bool> get ready;

  /// Shows the rewarded ad; true when the player earned the reward.
  Future<bool> showRewarded();

  /// Shows a full-screen ad between two levels. Returns as soon as the ad is
  /// gone, and at once when there is none to show.
  Future<void> showInterstitial();
}

class NoAds implements Ads {
  const NoAds();

  @override
  ValueListenable<bool> get ready => ValueNotifier(false);

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<void> showInterstitial() async {}
}

class AdMobAds implements Ads {
  AdMobAds() {
    MobileAds.instance.initialize().then((_) {
      _load();
      _loadInterstitial();
    }, onError: (_) {});
  }

  // Google's public test units. Replace with the real unit ids before release.
  static const _unitId = 'ca-app-pub-3940256099942544/5224354917';
  static const _interstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';

  RewardedAd? _ad;
  InterstitialAd? _interstitial;
  final _ready = ValueNotifier(false);

  @override
  ValueListenable<bool> get ready => _ready;

  void _setAd(RewardedAd? ad) {
    _ad = ad;
    _ready.value = ad != null;
  }

  void _load() {
    RewardedAd.load(
      adUnitId: _unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: _setAd,
        onAdFailedToLoad: (_) => _setAd(null),
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
    _setAd(null);
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
