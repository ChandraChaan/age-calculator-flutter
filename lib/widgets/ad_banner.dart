import 'dart:async';

import 'package:agecalculator/services/ads_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A banner pinned above the navigation bar on calm, read-only tabs
/// (Upcoming and Age). Never shown in editors, imports, permission prompts
/// or dialogs. Collapses to nothing when ads are off or fail to load, and
/// retries a failed load a few times with growing delays (as in Vajra
/// Automate).
class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.ads});

  /// `null` means no ad layer (tests, other platforms): nothing is shown.
  final AdsController? ads;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  static const _retryDelays = [
    Duration(seconds: 20),
    Duration(seconds: 60),
    Duration(seconds: 180),
  ];

  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;
  int _attempt = 0;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    widget.ads?.addListener(_onAdsChanged);
    _onAdsChanged();
  }

  @override
  void didUpdateWidget(AdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ads != widget.ads) {
      oldWidget.ads?.removeListener(_onAdsChanged);
      widget.ads?.addListener(_onAdsChanged);
      _onAdsChanged();
    }
  }

  void _onAdsChanged() {
    final ads = widget.ads;
    if (_requested || ads == null || !ads.ready || AdUnits.banner == null) {
      return;
    }
    _requested = true;
    // After this frame: reporting status notifies listeners.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final unit = AdUnits.banner;
    final ads = widget.ads;
    if (unit == null || ads == null || !mounted) return;
    _attempt++;
    ads.reportBanner('loading (attempt $_attempt)');
    final banner = BannerAd(
      adUnitId: unit,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          ads.reportBanner(
            'loaded (${AdSize.banner.width}x${AdSize.banner.height})',
          );
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          ads.reportBanner(
            'failed (code ${error.code}: ${error.message})'
            '${_attempt <= _retryDelays.length ? ', retrying' : ', giving up'}',
          );
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          if (_attempt <= _retryDelays.length) {
            _retry?.cancel();
            _retry = Timer(_retryDelays[_attempt - 1], _load);
          }
        },
        onAdImpression: (_) => ads.reportBanner('impression recorded'),
      ),
    );
    _ad?.dispose();
    _ad = banner;
    banner.load();
  }

  @override
  void dispose() {
    widget.ads?.removeListener(_onAdsChanged);
    _retry?.cancel();
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Center(
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
