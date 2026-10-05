# Easy Ads SDK

One Flutter API for **Google AdMob** and **Meta Audience Network**.

You add this package the same way you add any other package. The Facebook native SDK is already inside it. You do not write Android XML or Swift for ads. AdMob native ads use Google's built-in medium template. Facebook native ads use the template shipped with this package.

| | Version |
|---|---|
| `google_mobile_ads` | 9.1.0 |
| Google Mobile Ads Android SDK | 25.4.0 |
| Google Mobile Ads iOS SDK | 13.7.0 |
| Meta Audience Network, Android and iOS | 6.22.0 |

These versions live in `pubspec.yaml`, `android/build.gradle.kts`, and `ios/easy_ads_sdk/Package.swift`. `EasyAdsVersions` exposes the same numbers from Dart.

## What you get

* Banner
* Interstitial
* Rewarded
* Rewarded interstitial
* Native, using each network's built-in template

Every ad has `onLoading`, `onLoaded`, and `onError`.

* `onLoading` runs once, when the first request starts.
* `onLoaded` runs when one network fills, and tells you which network it was.
* `onError` runs only when every available network has failed. It does not run when the first network fails and the second one is still loading.

Full-screen ads also have `onClosed`. Rewarded ads and rewarded interstitials also have `onReward`.

## How fallback works

You pick one priority when the SDK starts: AdMob first, or Facebook first.

The SDK asks the first network. If that ad loads, the other network is never contacted. If the first network fails, the SDK immediately asks the second network and shows that ad instead. If the second network is not configured, or it also fails, you get `onError`.

Facebook is skipped entirely when you do not pass `FacebookOptions`, or when Facebook cannot initialize. AdMob is always required.

## Requirements

* Flutter 3.38 or newer
* Dart 3.10 or newer
* Android `minSdk` 24 or higher
* iOS 15 or higher
* Xcode 26 or higher, because Meta Audience Network 6.22.0 requires it

`INTERNET` and `ACCESS_NETWORK_STATE` are merged into the Android app by this package. You do not add those two permissions yourself.

The AdMob app id, and the Facebook app id when you use Facebook, are different for every app. Those two values still go in your project files. The snippets below are the whole native setup.

## 1. Add the package

```yaml
dependencies:
  easy_ads_sdk:
    path: ../easy_ads_sdk
```

Use a pub.dev version constraint here after the package is published. Until then, point `path` at the package directory.

```bash
flutter pub get
```

You do not also add `google_mobile_ads`. This package already depends on it.

## 2. Android setup

Open `android/app/build.gradle.kts` (or `build.gradle`) and set `minSdk` to at least 24.

```kotlin
defaultConfig {
    minSdk = maxOf(flutter.minSdkVersion, 24)
}
```

Open `android/app/src/main/AndroidManifest.xml`. Inside `<application>`, add the AdMob app id. The sample value below is Google's demo app id. Replace it with yours before release.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:hardwareAccelerated="true">

        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy"/>

    </application>
</manifest>
```

`android:hardwareAccelerated="true"` is the Flutter default. Video ads need it. Do not turn it off.

### Facebook on Android

Skip this section if the app will not use Facebook.

Create `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="facebook_app_id">YOUR_FACEBOOK_APP_ID</string>
    <string name="facebook_client_token">YOUR_FACEBOOK_CLIENT_TOKEN</string>
</resources>
```

The app id and client token come from the Meta app dashboard: **App settings > Basic**.

Add both keys inside `<application>` in `AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.facebook.sdk.ApplicationId"
    android:value="@string/facebook_app_id"/>
<meta-data
    android:name="com.facebook.sdk.ClientToken"
    android:value="@string/facebook_client_token"/>
```

If these values are missing or Facebook cannot start, the SDK ignores Facebook and keeps serving AdMob. A missing **AdMob** app id is different: the Google SDK stops the process on startup. Put the AdMob app id in the manifest before the first run.

## 3. iOS setup

Set the app's iOS deployment target to 15.0 or higher.

In Xcode this is the Runner target's **Minimum Deployments**. In `ios/Podfile`, when the project uses CocoaPods:

```ruby
platform :ios, '15.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      # Required with google_mobile_ads 9.1.0. Without it, Xcode stops on
      # "Include of non-modular header" inside GoogleMobileAds.
      config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      if target.name == 'google_mobile_ads'
        config.build_settings['DEFINES_MODULE'] = 'NO'
      end
    end
  end

  Dir.glob(File.join(installer.sandbox.root.to_s, 'Target Support Files', 'google_mobile_ads', '*.xcconfig')).each do |xcconfig|
    text = File.read(xcconfig)
    text = text.gsub('DEFINES_MODULE = YES', 'DEFINES_MODULE = NO')
    unless text.include?('CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES')
      text << "\nCLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES = YES\n"
    end
    File.write(xcconfig, text)
  end
end
```

Open `ios/Runner/Info.plist`. Add the AdMob app id. The sample value is Google's demo iOS app id.

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
```

Add Google's SKAdNetwork list. `cstr6suwn9.skadnetwork` is Google. `v9wttpbfk9.skadnetwork` is Meta. The rest are buyers Google lists for iOS attribution. Paste this inside the top-level `<dict>`:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict><key>SKAdNetworkIdentifier</key><string>cstr6suwn9.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>4fzdc2evr5.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>2fnua5tdw4.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>ydx93a7ass.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>p78axxw29g.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>v72qych5uu.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>ludvb6z3bs.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>cp8zw746q7.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>3sh42y64q3.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>c6k4g5qg8m.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>s39g8k73mm.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>wg4vff78zm.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>3qy4746246.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>f38h382jlk.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>hs6bdukanm.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>mlmmfzh3r3.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>v4nxqhlyqp.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>wzmmz9fp6w.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>su67r6k2v3.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>yclnxrl5pm.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>t38b2kh725.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>7ug5zh24hu.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>gta9lk7p23.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>vutu7akeur.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>y5ghdn5j9k.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>v9wttpbfk9.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>n38lu8286q.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>47vhws6wlr.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>kbd757ywx3.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>9t245vhmpl.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>a2p9lx4jpn.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>22mmun2rn5.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>44jx6755aq.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>k674qkevps.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>4468km3ulz.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>2u9pt9hc89.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>8s468mfl3y.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>klf5c3l5u5.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>ppxm28t8ap.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>kbmxgpxpgc.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>uw77j35x4d.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>578prtvx9j.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>4dzt52r2t5.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>tl55sbb4fm.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>c3frkrj4fj.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>e5fvkxwrpn.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>8c4e2ghe7u.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>3rd42ekr43.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>97r2b46745.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>3qcr597p9d.skadnetwork</string></dict>
</array>
```

This list matches Google's iOS quick start as published on 2 October 2026. When you update the Google SDK, compare it with [Set up Google Mobile Ads SDK for iOS](https://developers.google.com/admob/ios/quick-start) and add any new identifiers.

### Facebook on iOS

Skip this section if the app will not use Facebook.

Add the same Meta app id and client token to `Info.plist`:

```xml
<key>FacebookAppID</key>
<string>YOUR_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_FACEBOOK_CLIENT_TOKEN</string>
<key>FacebookDisplayName</key>
<string>YOUR_APP_NAME</string>
```

If you ask for tracking permission, also add a usage description. iOS will not show the prompt without it.

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier is used to show ads that are more relevant to you.</string>
```

Request permission before `EasyAds.initialize`, and pass `iosAdvertiserTrackingEnabled: true` only when the user allows it. The SDK still checks the system status, so a denied prompt does not turn tracking on.

```dart
final status = await EasyAds.requestIosTrackingAuthorization();

await EasyAds.initialize(
  facebook: FacebookOptions(
    iosAdvertiserTrackingEnabled: status == IosTrackingStatus.authorized,
  ),
);
```

On Android, `requestIosTrackingAuthorization` returns `IosTrackingStatus.notSupported` and does not show a dialog.

## 4. Initialize

```dart
import 'package:easy_ads_sdk/easy_ads_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyAds.initialize(
    priority: EasyAdPriority.admob, // or EasyAdPriority.facebook
    facebook: const FacebookOptions(), // omit this to skip Facebook
    testMode: true, // false in production
  );
  runApp(const MyApp());
}
```

`testMode: true` does two things:

* AdMob requests use Google's demo ad units, even if you passed your real ad unit ids. Demo ads are safe to click.
* A Facebook placement id that does not already contain `#` is prefixed with a Meta test creative. Rewarded ads use a video test creative. The other formats use an image test creative.

Set `testMode` to `false` before you ship. A second call to `initialize` does not change the priority or the test mode chosen by the first call.

`EasyTestIds` holds Google's demo ad units and Meta's public sample placement ids, if you want to pass those ids yourself.

## 5. Banner

```dart
EasyBannerAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb',
  facebookPlacementId: 'YOUR_FACEBOOK_BANNER_PLACEMENT', // optional
  size: EasyBannerSize.banner,
  onLoading: () => debugPrint('banner loading'),
  onLoaded: (network) => debugPrint('banner from ${network.name}'),
  onError: (error) => debugPrint('banner failed: $error'),
)
```

`EasyBannerSize.banner` is the standard banner. `EasyBannerSize.large` is the taller banner. `EasyBannerSize.mediumRectangle` is 300x250.

The widget loads itself. While it is loading it keeps its height empty, so the screen does not jump when the ad arrives. If both networks fail, it collapses.

Changing the ad unit id, the Facebook placement id, or the size loads a new ad.

## 6. Native

```dart
EasyNativeAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn',
  facebookPlacementId: 'YOUR_FACEBOOK_NATIVE_PLACEMENT', // optional
  height: 320,
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)
```

AdMob uses the medium native template. Facebook uses the template built into this package: icon, title, sponsored label, media, body, and call-to-action button. Keep `height` at 250 or more. Facebook does not count an impression when the media is shorter than that.

This version does not take button colors or a custom layout. That can be added later without changing the load and fallback behavior.

## 7. Interstitial

Create it once, load it before you need it, then show it.

```dart
final interstitial = EasyInterstitialAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/iiiiiiiiii',
  facebookPlacementId: 'YOUR_FACEBOOK_INTERSTITIAL_PLACEMENT', // optional
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
  onClosed: () {
    // The ad was dismissed. Load another one if you will show it again.
  },
);

final loaded = await interstitial.load();
if (loaded) {
  await interstitial.show();
}
```

`show()` throws a `StateError` if you call it before `onLoaded`. After `onClosed`, the ad is spent. Call `load()` again before the next `show()`.

Call `interstitial.dispose()` when the screen that owns it is disposed.

## 8. Rewarded

```dart
final rewarded = EasyRewardedAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/rrrrrrrrrr',
  facebookPlacementId: 'YOUR_FACEBOOK_REWARDED_PLACEMENT', // optional
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
  onClosed: () {},
  onReward: (reward) {
    // Grant reward.amount of reward.type.
    // reward.network tells you who paid for it.
  },
);

await rewarded.load();
await rewarded.show();
```

AdMob sends the amount and type configured on the ad unit. Facebook sends amount `1` and type `reward` when the video completes. Grant the reward inside `onReward`, not inside `onClosed`. The user can close a rewarded ad without earning it.

## 9. Rewarded interstitial

Same callbacks as rewarded. Show it at a natural break, the same way you show an interstitial.

```dart
final rewardedInterstitial = EasyRewardedInterstitialAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/wwwwwwwwww',
  facebookPlacementId: 'YOUR_FACEBOOK_REWARDED_INTERSTITIAL_PLACEMENT',
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
  onClosed: () {},
  onReward: (reward) {},
);

await rewardedInterstitial.load();
await rewardedInterstitial.show();
```

## Reading errors

`onError` receives an `EasyAdError`. When both networks fail, `error.failures` lists them in the order they were tried:

```dart
onError: (error) {
  for (final failure in error.failures) {
    debugPrint('${failure.network.name}: ${failure.message}');
  }
}
```

## Placement ids must match the format

Create one AdMob ad unit per format, and one Facebook placement per format. A banner id cannot be used as an interstitial id. The request fails, and the SDK moves on to the other network.

## Example app

`example/` is a working app wired to Google's demo ad units and Meta's public sample placement ids. It is already in test mode.

```bash
cd example
flutter run
```

The Android demo app id is `ca-app-pub-3940256099942544~3347511713`. The iOS demo app id is `ca-app-pub-3940256099942544~1458002511`. Both are already in the example project.

## Keeping the SDKs current

1. Check [google_mobile_ads on pub.dev](https://pub.dev/packages/google_mobile_ads) and set that version in `pubspec.yaml`.
2. Check the [Meta Audience Network Android SDK](https://developers.facebook.com/documentation/audience-network/setting-up/platform-setup/android/add-sdk) and set the same version in `android/build.gradle.kts`.
3. Set the same version in `ios/easy_ads_sdk/Package.swift` (`exact`) and `ios/easy_ads_sdk.podspec`.
4. Update `EasyAdsVersions` and this table so they match.
5. Compare the iOS `SKAdNetworkItems` list with Google's current quick start.

Meta Audience Network 6.22.0 is the last version distributed through CocoaPods. Newer iOS releases have to come through Swift Package Manager, which this plugin already uses in `Package.swift`.
