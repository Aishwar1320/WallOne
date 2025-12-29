import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  /// 🔹 BANNER AD UNIT ID
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/6300978111' // Android test banner
          : 'YOUR_ANDROID_BANNER_ID';
    } else if (Platform.isIOS) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/2934735716' // iOS test banner
          : 'YOUR_IOS_BANNER_ID';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// 🔹 INTERSTITIAL AD UNIT ID
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/1033173712' // Android test interstitial
          : 'YOUR_ANDROID_INTERSTITIAL_ID';
    } else if (Platform.isIOS) {
      return kDebugMode
          ? 'ca-app-pub-3940256099942544/4411468910' // iOS test interstitial
          : 'YOUR_IOS_INTERSTITIAL_ID';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// 🔹 CREATE BANNER AD
  static BannerAd createBannerAd({
    AdSize size = AdSize.banner,
    BannerAdListener? listener,
  }) {
    return BannerAd(
      size: size,
      adUnitId: bannerAdUnitId,
      listener: listener ?? const BannerAdListener(),
      request: const AdRequest(),
    );
  }
}
