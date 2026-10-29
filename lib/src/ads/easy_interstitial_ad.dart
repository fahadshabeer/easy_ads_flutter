import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import 'fullscreen_ad.dart';

/// A full-screen interstitial.
///
/// Load it before the moment you want to show it, then call [show].
///
/// [onTimeout] runs when the load is still unfinished after [timeout].
/// The default is 10 seconds. [onLoaded] and [onError] do not run for
/// that attempt. Pass `timeout: null` to wait for the network.
class EasyInterstitialAd extends FullScreenAdBase {
  /// Creates an interstitial.
  EasyInterstitialAd({
    required super.admobAdUnitId,
    super.onLoading,
    super.onLoaded,
    super.onError,
    super.onClosed,
    super.onTimeout,
    super.timeout = const Duration(seconds: 10),
  }) : super(format: EasyAdFormat.interstitial);

  InterstitialAd? _ad;

  @override
  Future<LoadAttempt> loadNetwork(EasyAdNetwork network) {
    return _loadAdmob();
  }

  Future<LoadAttempt> _loadAdmob() {
    final completer = Completer<LoadAttempt>();
    InterstitialAd.load(
      adUnitId: resolveAdmobAdUnitId(
        adUnitId: admobAdUnitId,
        format: format,
        testMode: EasyAds.testMode,
      ),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (identical(_ad, ad)) {
                _ad = null;
              }
              notifyClosed();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (identical(_ad, ad)) {
                _ad = null;
              }
              notifyShowFailed(error.message);
            },
          );
          if (!completer.isCompleted) {
            completer.complete(const LoadAttempt.filled());
          }
        },
        onAdFailedToLoad: (error) {
          if (!completer.isCompleted) {
            completer.complete(
              LoadAttempt.failed(
                EasyAdFailure(
                  network: EasyAdNetwork.admob,
                  message: error.message,
                  code: error.code,
                ),
              ),
            );
          }
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<void> showNetwork(EasyAdNetwork network) async {
    final ad = _ad;
    if (ad == null) {
      throw StateError('AdMob interstitial is not loaded.');
    }
    await ad.show();
  }

  @override
  Future<void> discardNetwork(EasyAdNetwork network) async {
    final ad = _ad;
    _ad = null;
    ad?.dispose();
  }
}
