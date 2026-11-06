import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob unit IDs (same scheme as Vajra Automate).
///
/// Only Google's documented **test** banner unit exists in code. Debug builds
/// use it when compiled with `--dart-define=FORCE_ADS=true`. Release builds
/// show ads only when a real unit is supplied at build time:
///   flutter build appbundle --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-.../...
/// Without it no ads are requested.
abstract final class AdUnits {
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _prodBanner = String.fromEnvironment('ADMOB_BANNER_UNIT_ID');

  /// Debug-only switch for Google's test ads; a release build ignores it.
  static const bool forceTestAds =
      kDebugMode && bool.fromEnvironment('FORCE_ADS');

  static String? get banner {
    if (_prodBanner.isNotEmpty) return _prodBanner;
    return forceTestAds ? _testBanner : null;
  }

  /// True when the unit in use is Google's demo unit (never a live ad).
  static bool get isTestUnit => banner == _testBanner;
}

enum AdsState { off, initialising, ready, blocked }

/// Consent-aware ads. Fully optional: when no unit is configured, consent is
/// refused, or loading fails, the app behaves identically without them.
///
/// Every state change is logged with the `Ads:` prefix
/// (`adb logcat -s flutter`).
class AdsController extends ChangeNotifier {
  AdsController({bool? enabled})
    : _enabled = enabled ?? (!kIsWeb && Platform.isAndroid);

  final bool _enabled;
  AdsState _state = AdsState.off;
  bool _privacyOptionsRequired = false;
  bool _started = false;
  bool _disposed = false;
  String _reason = 'not started yet';
  String _banner = 'no banner requested';

  AdsState get state => _state;
  bool get ready => _state == AdsState.ready;

  /// Whether Settings must offer "Ad privacy options" (required in some
  /// regions once the user has answered the consent form).
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// One line describing the current ads situation, for diagnostics.
  String get statusText => '${_state.name}: $_reason · banner: $_banner';

  void _log(String message) => debugPrint('Ads: $message');

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setReason(String reason, {AdsState? state}) {
    final changed = reason != _reason || (state != null && state != _state);
    _reason = reason;
    if (state != null) _state = state;
    if (changed) {
      _log(statusText);
      _notify();
    }
  }

  /// Called by the banner with load results (success, failure, retry).
  void reportBanner(String status) {
    if (status == _banner) return;
    _banner = status;
    _log('banner $status');
    _notify();
  }

  /// Starts at most once, after the app has loaded.
  Future<void> start() async {
    if (_started) return;
    if (!_enabled) {
      _setReason('disabled on this platform');
      return;
    }
    if (AdUnits.banner == null) {
      _setReason(
        kDebugMode
            ? 'disabled: debug build without --dart-define=FORCE_ADS=true'
            : 'disabled: release build without an ADMOB_BANNER_UNIT_ID',
      );
      return;
    }
    _started = true;
    _log(
      'starting (unit=${AdUnits.isTestUnit ? 'Google test unit' : 'configured unit'})',
    );
    _setReason('initialising', state: AdsState.initialising);
    // Google's User Messaging Platform: shows the consent form only where
    // the law requires it (e.g. EEA/UK). A consent error never decides on
    // its own: as Google recommends, ads may still be requested when
    // canRequestAds() allows it (consent from an earlier session, or not
    // required in this region).
    try {
      await _requestConsentInfo();
      _log('consent info updated');
      try {
        await _showFormIfRequired();
      } catch (e) {
        _log('consent form failed (${e.runtimeType}: $e)');
      }
    } catch (e) {
      _log('consent info update failed (${e.runtimeType}: $e)');
    }
    try {
      final canRequest = await ConsentInformation.instance.canRequestAds();
      _log('canRequestAds=$canRequest');
      if (!canRequest) {
        _setReason('consent does not allow ads', state: AdsState.blocked);
        return;
      }
      final status = await MobileAds.instance.initialize();
      for (final entry in status.adapterStatuses.entries) {
        _log('adapter ${entry.key}: ${entry.value.state.name}');
      }
      _setReason('SDK initialised', state: AdsState.ready);
      _privacyOptionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (e) {
      _setReason(
        'initialisation failed (${e.runtimeType}: $e)',
        state: AdsState.blocked,
      );
    }
    _notify();
  }

  Future<void> _requestConsentInfo() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      done.complete,
      (error) => done.completeError(StateError(error.message)),
    );
    return done.future;
  }

  Future<void> _showFormIfRequired() {
    final done = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        done.completeError(StateError(error.message));
      } else {
        done.complete();
      }
    });
    return done.future;
  }

  /// Lets the user revisit their consent choice.
  void showPrivacyOptions() => ConsentForm.showPrivacyOptionsForm((_) {});

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
