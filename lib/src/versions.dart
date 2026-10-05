/// SDK versions bundled with this package.
///
/// Change these only when the native dependencies in `pubspec.yaml`,
/// `android/build.gradle.kts`, and `ios/easy_ads_sdk/Package.swift` change
/// with them.
class EasyAdsVersions {
  const EasyAdsVersions._();

  /// `google_mobile_ads` plugin version.
  static const admobFlutterPlugin = '9.1.0';

  /// Google Mobile Ads Android SDK pulled in by [admobFlutterPlugin].
  static const admobAndroidSdk = '25.4.0';

  /// Google Mobile Ads iOS SDK pulled in by [admobFlutterPlugin].
  static const admobIosSdk = '13.7.0';

  /// Meta Audience Network SDK on Android and iOS.
  static const facebookSdk = '6.22.0';
}
