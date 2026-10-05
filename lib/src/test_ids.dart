import 'package:flutter/foundation.dart';

import 'ad_format.dart';

/// Google's public demo ad units, and Meta's public sample placement ids.
///
/// Demo ad units are safe to click. Replace them before you ship.
class EasyTestIds {
  const EasyTestIds._();

  /// Google's Android demo app id. This goes in `AndroidManifest.xml`.
  static const androidAdmobAppId = 'ca-app-pub-3940256099942544~3347511713';

  /// Google's iOS demo app id. This goes in `Info.plist`.
  static const iosAdmobAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const _androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _androidInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _androidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _androidRewardedInterstitial =
      'ca-app-pub-3940256099942544/5354046379';
  static const _androidNative = 'ca-app-pub-3940256099942544/2247696110';

  static const _iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const _iosInterstitial = 'ca-app-pub-3940256099942544/4411468910';
  static const _iosRewarded = 'ca-app-pub-3940256099942544/1712485313';
  static const _iosRewardedInterstitial =
      'ca-app-pub-3940256099942544/6978759866';
  static const _iosNative = 'ca-app-pub-3940256099942544/3986624511';

  /// Meta sample banner placement. Already a test creative.
  static const facebookBanner =
      'IMG_16_9_APP_INSTALL#2312433698835503_2964944860251047';

  /// Meta sample interstitial placement. Already a test creative.
  static const facebookInterstitial =
      'IMG_16_9_APP_INSTALL#2312433698835503_2650502525028617';

  /// Meta sample rewarded placement. Already a test creative.
  static const facebookRewarded =
      'VID_HD_16_9_46S_APP_INSTALL#2312433698835503_2650502525028617';

  /// Meta sample rewarded interstitial placement. Already a test creative.
  static const facebookRewardedInterstitial =
      'VID_HD_16_9_46S_APP_INSTALL#2312433698835503_2650502525028617';

  /// Meta sample native placement. Already a test creative.
  static const facebookNative =
      'IMG_16_9_APP_INSTALL#2312433698835503_2964953543583512';

  /// Demo AdMob ad unit for [format] on the current platform.
  static String admob(EasyAdFormat format, {TargetPlatform? platform}) {
    final ios = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    return switch (format) {
      EasyAdFormat.banner => ios ? _iosBanner : _androidBanner,
      EasyAdFormat.interstitial =>
        ios ? _iosInterstitial : _androidInterstitial,
      EasyAdFormat.rewarded => ios ? _iosRewarded : _androidRewarded,
      EasyAdFormat.rewardedInterstitial =>
        ios ? _iosRewardedInterstitial : _androidRewardedInterstitial,
      EasyAdFormat.native => ios ? _iosNative : _androidNative,
    };
  }

  /// Demo banner ad unit for the current platform.
  static String get banner => admob(EasyAdFormat.banner);

  /// Demo interstitial ad unit for the current platform.
  static String get interstitial => admob(EasyAdFormat.interstitial);

  /// Demo rewarded ad unit for the current platform.
  static String get rewarded => admob(EasyAdFormat.rewarded);

  /// Demo rewarded interstitial ad unit for the current platform.
  static String get rewardedInterstitial =>
      admob(EasyAdFormat.rewardedInterstitial);

  /// Demo native ad unit for the current platform.
  static String get native => admob(EasyAdFormat.native);
}
