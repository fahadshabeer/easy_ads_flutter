/// SDK versions bundled with this package.
///
/// Change these only when `pubspec.yaml` changes with them. The Meta
/// bidding adapter versions follow `gma_mediation_meta`.
class EasyAdsVersions {
  const EasyAdsVersions._();

  /// `google_mobile_ads` plugin version.
  static const admobFlutterPlugin = '9.1.0';

  /// Google Mobile Ads Android SDK pulled in by [admobFlutterPlugin].
  static const admobAndroidSdk = '25.4.0';

  /// Google Mobile Ads iOS SDK pulled in by [admobFlutterPlugin].
  static const admobIosSdk = '13.7.0';

  /// `gma_mediation_meta` plugin that links the AdMob Meta bidding adapter.
  static const metaMediationFlutter = '1.7.1';

  /// Google Mobile Ads Meta adapter on Android.
  static const metaMediationAndroid = '6.22.0.1';

  /// Google Mobile Ads Meta adapter on iOS.
  static const metaMediationIos = '6.22.0.0';
}
