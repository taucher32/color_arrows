import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Rewarded ads only. The game works without them: when [isReady] is false
/// the UI simply hides the "watch an ad" button.
abstract class Ads {
  bool get isReady;

  /// Shows the ad; true when the player earned the reward.
  Future<bool> showRewarded();
}

class NoAds implements Ads {
  const NoAds();

  @override
  bool get isReady => false;

  @override
  Future<bool> showRewarded() async => false;
}

class AdMobAds implements Ads {
  AdMobAds() {
    _load();
  }

  // Google's public test unit. Replace with the real unit id before release.
  static const _unitId = 'ca-app-pub-3940256099942544/5224354917';

  RewardedAd? _ad;

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
