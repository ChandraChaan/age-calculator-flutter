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

class _AdBannerState extends State<AdBanner> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    widget.ads?.addListener(_onAdsChanged);
    _onAdsChanged();
  }

  /// After the retries run out, try again each time the app comes back to
  /// the foreground (for example once AdMob approves the account).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_requested || _loaded || _ad != null || _retry?.isActive == true) {
      return;
    }
    _attempt = 0;
    _load();
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

  Future<void> _load() async {
    final unit = AdUnits.banner;
    final ads = widget.ads;
    if (unit == null || ads == null || !mounted) return;
    _attempt++;
    ads.reportBanner('loading (attempt $_attempt)');
    // A full-width anchored adaptive banner, falling back to 320x50. The
    // "large" variant the SDK now suggests is about 128dp tall, too much
    // above the navigation bar, so the standard one (about 50-60dp) is used.
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size =
        // ignore: deprecated_member_use
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted) return;
    final banner = BannerAd(
      adUnitId: unit,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          ads.reportBanner('loaded (${size.width}x${size.height})');
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
            if (identical(_ad, failed)) _ad = null;
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
    WidgetsBinding.instance.removeObserver(this);
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
