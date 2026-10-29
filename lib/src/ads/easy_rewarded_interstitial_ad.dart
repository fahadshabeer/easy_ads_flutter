import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import '../reward.dart';
import 'fullscreen_ad.dart';

/// A rewarded interstitial, shown at a natural break.
///
/// [onReward] runs when AdMob reports the reward.
class EasyRewardedInterstitialAd extends FullScreenAdBase {
  /// Creates a rewarded interstitial.
  EasyRewardedInterstitialAd({
    required super.admobAdUnitId,
    super.onLoading,
    super.onLoaded,
    super.onError,
    super.onClosed,
    super.onReward,
  }) : super(format: EasyAdFormat.rewardedInterstitial);

  RewardedInterstitialAd? _ad;

  @override
  Future<LoadAttempt> loadNetwork(EasyAdNetwork network) {
    return _loadAdmob();
  }

  Future<LoadAttempt> _loadAdmob() {
    final completer = Completer<LoadAttempt>();
    RewardedInterstitialAd.load(
      adUnitId: resolveAdmobAdUnitId(
        adUnitId: admobAdUnitId,
        format: format,
        testMode: EasyAds.testMode,
      ),
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
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
      throw StateError('AdMob rewarded interstitial is not loaded.');
    }
    await ad.show(
      onUserEarnedReward: (ad, reward) {
        notifyReward(
          EasyReward(
            amount: reward.amount.round(),
            type: reward.type,
            network: EasyAdNetwork.admob,
          ),
        );
      },
    );
  }

  @override
  Future<void> discardNetwork(EasyAdNetwork network) async {
    final ad = _ad;
    _ad = null;
    ad?.dispose();
  }
}
