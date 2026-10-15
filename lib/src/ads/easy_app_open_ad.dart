import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import 'fullscreen_ad.dart';

/// A full-screen ad shown when the app opens.
///
/// AdMob is the only network. Meta Audience Network has no app open format.
/// Load it on the splash screen, then call [show] from [onLoaded].
///
/// [onTimeout] runs when the load is still unfinished after [timeout].
/// The default is 10 seconds. [onLoaded] and [onError] do not run for
/// that attempt, so the splash can continue. Pass `timeout: null` to wait
/// for the network.
class EasyAppOpenAd extends FullScreenAdBase {
  /// Creates an app open ad.
  EasyAppOpenAd({
    required super.admobAdUnitId,
    super.onLoading,
    super.onLoaded,
    super.onError,
    super.onClosed,
    super.onTimeout,
    super.timeout = const Duration(seconds: 10),
  }) : super(format: EasyAdFormat.appOpen);

  AppOpenAd? _ad;

  @override
  Future<LoadAttempt> loadNetwork(EasyAdNetwork network) {
    return switch (network) {
      EasyAdNetwork.admob => _loadAdmob(),
      EasyAdNetwork.facebook => Future.value(
        const LoadAttempt.failed(
          EasyAdFailure(
            network: EasyAdNetwork.facebook,
            message: 'App open ads are AdMob only.',
          ),
        ),
      ),
    };
  }

  Future<LoadAttempt> _loadAdmob() {
    final completer = Completer<LoadAttempt>();
    AppOpenAd.load(
      adUnitId: resolveAdmobAdUnitId(
        adUnitId: admobAdUnitId,
        format: format,
        testMode: EasyAds.testMode,
      ),
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
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
      throw StateError('App open ad is not loaded.');
    }
    await ad.show();
  }

  @override
  Future<void> discardNetwork(EasyAdNetwork network) async {
    if (network != EasyAdNetwork.admob) {
      return;
    }
    final ad = _ad;
    _ad = null;
    ad?.dispose();
  }
}
