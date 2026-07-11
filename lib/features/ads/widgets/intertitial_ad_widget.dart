import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wallone/features/ads/ad_manager.dart';

class InterstitialAdManager {
  static InterstitialAd? _interstitialAd;
  static bool _isLoading = false;

  static void load() {
    if (_isLoading || _interstitialAd != null) return;

    _isLoading = true;

    InterstitialAd.load(
      adUnitId: AdManager.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isLoading = false;
          _interstitialAd = null;

          if (error.code == 3) {
            // NO_FILL → do nothing, retry later
          }
        },
      ),
    );
  }

  static void show() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        load(); // preload next
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        load();
      },
    );

    _interstitialAd!.show();
  }

  static bool get isAvailable => _interstitialAd != null;
}
