import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:wallone/features/ads/ad_manager.dart';

class BannerAdWidget extends StatefulWidget {
  final AdSize size;
  const BannerAdWidget({super.key, this.size = AdSize.banner});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _hasFailed = false;

  double get _height => widget.size.height.toDouble();
  double get _width => widget.size.width.toDouble();

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = AdManager.createBannerAd(
      size: widget.size,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() {
            _isLoaded = true;
            _hasFailed = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;

          setState(() {
            _isLoaded = false;
            _hasFailed = true;
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasFailed || !_isLoaded) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: _width,
      height: _height,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
