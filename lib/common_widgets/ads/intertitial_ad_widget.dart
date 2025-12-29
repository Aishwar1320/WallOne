import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wallone/utils/ad_manager.dart';

class InterstitialAdManager {
  static InterstitialAd? _interstitialAd;

  static void load() {
    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  static void show() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        load(); // preload next
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
  }
}
