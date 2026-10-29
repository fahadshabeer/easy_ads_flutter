# Easy Ads SDK

One Flutter API for **Google AdMob**, with **Meta Audience Network bidding** included.

You add this package the same way you add any other package. Ads are requested through AdMob. The Meta mediation adapter (`gma_mediation_meta`) is already a dependency, so Meta can fill those AdMob requests when you add Meta as a bidding source in AdMob. There is no direct Facebook Ads SDK in this package, and there is no Facebook placement id in the Dart API. AdMob native ads use Google's built-in medium template.

Meta mediation is already integrated. An app does not add `gma_mediation_meta` itself. After the steps in [Meta mediation is already integrated](#meta-mediation-is-already-integrated), AdMob can fill the same ad units from Meta inventory.

| | Version |
|---|---|
| `google_mobile_ads` | 9.1.0 |
| Google Mobile Ads Android SDK | 25.4.0 |
| Google Mobile Ads iOS SDK | 13.7.0 |
| `gma_mediation_meta` | 1.7.1 |
| AdMob Meta adapter, Android | 6.22.0.1 |
| AdMob Meta adapter, iOS | 6.22.0.0 |

These versions live in `pubspec.yaml`. The Meta bidding adapter comes from `gma_mediation_meta`, which brings the Meta Audience Network SDK used by mediation. `EasyAdsVersions` exposes the same numbers from Dart.

## What you get

* Banner
* Interstitial
* App open. Meta has no app open format, including through mediation
* Rewarded
* Rewarded interstitial
* Native, using AdMob's built-in medium template

Every ad has `onLoading`, `onLoaded`, and `onError`.

* `onLoading` runs once, when the request starts.
* `onLoaded` runs when AdMob returns an ad. A Meta-mediated creative is still reported as `EasyAdNetwork.admob`.
* `onError` runs when that AdMob request fails.

| Callback | Banner | Native | Interstitial | App open | Rewarded | Rewarded interstitial |
|---|---|---|---|---|---|---|
| `onLoading` | yes | yes | yes | yes | yes | yes |
| `onLoaded` | yes | yes | yes | yes | yes | yes |
| `onError` | yes | yes | yes | yes | yes | yes |
| `onClosed` | | | yes | yes | yes | yes |
| `onReward` | | | | | yes | yes |
| `onTimeout` | | | yes | yes | | |
| `loading` widget | yes | yes | | | | |

`onTimeout` belongs only to interstitial and app open. The default wait is 10 seconds. When it runs, `onLoaded` and `onError` do not run for that attempt, and a late response is discarded. Banner and native have no timeout. Their widget stays, with its skeleton, until the ad fills or the request fails. On failure the widget collapses.

Banners and native ads load themselves when the widget is on screen. Interstitials, app open ads, rewarded ads, and rewarded interstitials do not. You preload those, keep the object, and call `show()` later. See [Preload full-screen ads](#7-preload-full-screen-ads).

## How an ad is requested

Every format asks AdMob. Meta is not a second request. When Meta Audience Network is a bidding source on that ad unit, Meta competes inside the AdMob auction, and the winning creative comes back through AdMob. App open has no Meta format, so that ad stays on AdMob inventory only. See [Meta mediation is already integrated](#meta-mediation-is-already-integrated).

## Meta mediation is already integrated

Meta Audience Network bidding is part of this package. `pubspec.yaml` depends on `gma_mediation_meta` 1.7.1, which links the AdMob adapter (Android `6.22.0.1`, iOS `6.22.0.0`) and the Audience Network SDK that adapter needs. The adapter is registered with the app when you depend on `easy_ads_sdk`. There is no second package to add, and there is no Facebook placement id to pass.

An AdMob request can then be filled by Meta inventory when Meta wins that auction. The placement id lives in the AdMob mediation group, not in Dart.

`onLoaded` reports `EasyAdNetwork.admob` when the Google SDK returns the ad, including when the creative came from Meta. Open Ad Inspector to see that Meta won.

Ship a new binary after you take this package update. A mediation group in AdMob has no Meta demand until that binary, with the adapter inside it, is installed.

### Dart API you keep using

Import one library:

```dart
import 'package:easy_ads_sdk/easy_ads_sdk.dart';
```

Start the SDK once. Meta bidding runs on the AdMob request.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startup = EasyAds.initialize(
    testMode: false, // true swaps in Google demo units and skips your mediation group
  );
  runApp(const MyApp());
  await startup;
}
```

These are the ad APIs. Each one takes the AdMob ad unit id that you mapped to a Meta placement in AdMob.

| API | Role with Meta bidding |
|---|---|
| `EasyAds.initialize` | Starts consent, then AdMob. The Meta adapter initializes from the AdMob bidding configuration. |
| `EasyAds.canRequestAds` | `true` when consent allows a request. |
| `EasyAds.isPrivacyOptionsRequired` | `true` when the app must show a settings entry that calls `EasyAds.showPrivacyOptionsForm`. |
| `EasyBannerAd` | Banner. Loads when the widget is built. `size` is `EasyBannerSize.banner`, `large`, or `mediumRectangle`. |
| `EasyNativeAd` | Native template. Loads when the widget is built. |
| `EasyInterstitialAd` | Preload with `load()`, then `show()`. |
| `EasyRewardedAd` | Preload with `load()`, grant the reward in `onReward`, then `show()`. |
| `EasyRewardedInterstitialAd` | Same preload pattern as rewarded. |
| `EasyAppOpenAd` | AdMob inventory only. Meta has no app open format, so mediation cannot fill this one from Meta. |
| `EasyAdNetwork` | `admob`. A Meta-mediated creative is reported as `admob`. |
| `EasyAdsVersions` | `admobFlutterPlugin`, `admobAndroidSdk`, `admobIosSdk`, `metaMediationFlutter`, `metaMediationAndroid`, and `metaMediationIos`. |

```dart
EasyBannerAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb',
  size: EasyBannerSize.banner,
  onLoading: () {},
  onLoaded: (EasyAdNetwork network) {},
  onError: (error) {},
)

final interstitial = EasyInterstitialAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/iiiiiiiiii',
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
  onClosed: () => interstitial.load(),
);
await interstitial.load();
if (interstitial.isLoaded) {
  await interstitial.show();
}
```

`testMode: true` replaces your ad unit with a Google demo ad unit. Demo ad units ignore your mediation group, so Meta does not bid. Use `testMode: false` and the real ad unit when you want Meta. Register the device as a test device in AdMob, and turn on test mode in Monetization Manager, before anyone taps those ads.

In Ad Inspector, use single ad source testing on **Meta Audience Network (Bidding)**. A Meta failure is reported under `com.google.ads.mediation.facebook.FacebookMediationAdapter` on Android and `GADMediationAdapterFacebook` on iOS. Error 101 means the placement id AdMob sent is missing or wrong.

### Setup in the app project

The AdMob app id is still required. Sections [2. Android setup](#2-android-setup) and [3. iOS setup](#3-ios-setup) are the whole native project setup for an app that already uses this package. Meta bidding adds no Android dependency line and no iOS pod line.

| In the app | Needed for Meta bidding |
|---|---|
| `easy_ads_sdk` in `pubspec.yaml` | Yes. This is the only ads dependency. |
| `google_mobile_ads` or `gma_mediation_meta` in the app `pubspec.yaml` | No. This package already depends on both. |
| AdMob app id in `AndroidManifest.xml` and `Info.plist` | Yes. Same value you already use for AdMob. |
| Android `minSdk` 24, iOS deployment target 15 | Yes. |
| `SKAdNetworkItems` from the iOS section, including `v9wttpbfk9.skadnetwork` and `n38lu8286q.skadnetwork` | Yes, on iOS. |
| `NSUserTrackingUsageDescription` | On iOS, when the app shows the App Tracking Transparency prompt. This package does not show that prompt. On iOS 17 and later, Meta reads the system tracking status itself. |

After `flutter pub upgrade easy_ads_sdk`, build and install the app again so the adapter is in the binary.

### Setup in AdMob and Meta

1. In [Meta Monetization Manager](https://business.facebook.com/pub/start), create the app property and choose **Google AdMob** as the mediation platform. Create one placement for each format you serve: banner, interstitial, rewarded, rewarded interstitial, and native. For a banner taller than 249 points, create a medium rectangle placement. App open has no Meta placement.
2. In AdMob, open **Mediation**, add **Meta Audience Network** as a **bidding** source, and map each AdMob ad unit to the matching Meta placement id. Meta has been bidding-only since 2021, so add it as bidding.
3. Copy the `app-ads.txt` lines Monetization Manager shows for this property onto your domain. Missing lines cut Meta demand.
4. In AdMob **Privacy & messaging**, select Meta on the GDPR message and the US state message. This SDK already writes the consent string Meta reads through `EasyAds.initialize`. European and US-state fill waits on that published message. Details are in [European consent](#european-consent).

### Android media cache

Android 9 and later blocks cleartext traffic. Meta caches some media on the device through a local address, and a blocked cache can leave a blank creative after Meta has already filled. Bidding still starts without the file below. Add it when a Meta creative does not render.

`android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">127.0.0.1</domain>
    </domain-config>
</network-security-config>
```

On `<application>` in `AndroidManifest.xml`:

```xml
android:networkSecurityConfig="@xml/network_security_config"
```

If the app already has a network security config, add the `127.0.0.1` domain to that file instead of replacing it.

## Requirements

* Flutter 3.38 or newer
* Dart 3.10 or newer
* Android `minSdk` 24 or higher
* iOS 15 or higher
* Xcode 26 or higher, because Meta Audience Network 6.22.0 requires it

`INTERNET` and `ACCESS_NETWORK_STATE` are merged into the Android app by Google Mobile Ads. You do not add those two permissions yourself.

The AdMob app id is different for every app. That value still goes in your project files. The snippets below are the whole native setup.

## 1. Add the package

For an app in another folder, depend on the GitHub repo. The package name stays `easy_ads_sdk`. The repo name is `easy_ads_flutter`.

```yaml
dependencies:
  easy_ads_sdk:
    git:
      url: https://github.com/fahadshabeer/easy_ads_flutter.git
      ref: main
```

`ref: main` means the `main` branch. `flutter pub get` does not fetch a new commit every time. The first get writes the exact commit into `pubspec.lock`, and later gets use that commit. The `version` in this package does not choose the commit.

To take the newest commit on `main`:

```bash
flutter pub upgrade easy_ads_sdk
```

The repo is private. `pub get` works on a machine that is already logged into the GitHub account that can read it.

While you are developing the plugin itself, a path dependency is enough:

```yaml
dependencies:
  easy_ads_sdk:
    path: ../easy_ads_sdk
```

```bash
flutter pub get
```

You do not also add `google_mobile_ads` or `gma_mediation_meta`. This package already depends on both. Use a pub.dev version constraint here after the package is published.

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

If the app shows the iOS tracking prompt, add a usage description. iOS will not show the prompt without it. This package does not show the prompt. On iOS 17 and later, the Meta adapter reads App Tracking Transparency itself.

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier is used to show ads that are more relevant to you.</string>
```

## 4. Initialize

```dart
import 'package:easy_ads_sdk/easy_ads_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final startup = EasyAds.initialize(
    testMode: true, // false in production
  );
  runApp(const MyApp());
  await startup;
}
```

Call `runApp` before you await `initialize`. Startup asks for European consent first, and that form is a native dialog that needs the app on screen. Ads requested while startup is still running wait for it. They do not request again on their own if consent is refused.

`testMode: true` sends AdMob requests to Google's demo ad units, even if you passed your real ad unit ids. Demo ads are safe to click. Those demo units ignore the Meta bidding source on your real ad unit.

Set `testMode` to `false` before you ship. A second call to `initialize` does not change the test mode chosen by the first call. Meta bidding setup is in [Meta mediation is already integrated](#meta-mediation-is-already-integrated).

`EasyTestIds` holds Google's demo ad units, if you want to pass those ids yourself.

## European consent

`initialize` gathers consent before AdMob or Meta is started. Google's User Messaging Platform decides who sees the form. People in the EEA, the UK, and Switzerland see it when your AdMob account has a published GDPR message. Everyone else continues without a dialog, and `EasyAds.canRequestAds` becomes true.

No extra native SDK is required. The consent library ships inside Google Mobile Ads.

### AdMob message

In AdMob, open **Privacy & messaging** and publish a **GDPR** message for this app. Include every ad partner you use. Meta Audience Network reads the consent string that this form writes, so Meta has to be selected as an ad partner in that message. Without a published message, European users are not shown a form and ad requests stay blocked.

The same startup also covers a published US state privacy message. You do not add a second call.

### Ad privacy options

A user who already answered the consent form must be able to change that answer later. Google requires a settings entry for that, and only for people the consent SDK marks with `EasyAds.isPrivacyOptionsRequired`. That is true for a European user who has seen the form. It stays false for everyone else, so those users never see the row.

```dart
if (EasyAds.isPrivacyOptionsRequired)
  ListTile(
    title: const Text('Ad privacy options'),
    onTap: () async {
      await EasyAds.showPrivacyOptionsForm();
      if (EasyAds.canRequestAds) {
        // Consent still allows ads. Preload the next one if you need it.
      }
    },
  )
```

The tap opens the same Google form. The user can allow ads, allow limited ads, or withdraw consent. When the form closes, `EasyAds.canRequestAds` matches the new choice. A withdrawal blocks every later request. An ad that is already loaded stays loaded; the next `load()` is what follows the new choice.

Call `showPrivacyOptionsForm()` only when `isPrivacyOptionsRequired` is true. Calling it otherwise throws.

This row does not open Apple's tracking prompt. After the user has answered that prompt, they change tracking in the iPhone Settings app, under Privacy & Security, then Tracking.

Users under the age of consent must not see the form:

```dart
await EasyAds.initialize(
  tagForUnderAgeOfConsent: true,
);
```

### Testing the form outside Europe

The form stays hidden on a device that is not in Europe. Force it on a debug build only. The first consent run prints a hashed device id in the debug log. Put that id in `testDeviceIds`.

```dart
EasyAds.initialize(
  consentDebug: EasyConsentDebug(
    geography: EasyConsentDebugGeography.eea,
    testDeviceIds: ['YOUR_HASHED_DEVICE_ID'],
  ),
);
```

Remove `consentDebug` before release. `EasyConsentDebugGeography.other` checks the path where no form should appear.

## 5. Banner

Three sizes work. Pass `size`. If you omit it, the widget uses `EasyBannerSize.banner`.

| Size | AdMob |
|---|---|
| `EasyBannerSize.banner` | 320×50 |
| `EasyBannerSize.large` | 320×100 |
| `EasyBannerSize.mediumRectangle` | 300×250 |

```dart
EasyBannerAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb',
  size: EasyBannerSize.mediumRectangle,
  onLoading: () => debugPrint('banner loading'),
  onLoaded: (network) => debugPrint('banner from ${network.name}'),
  onError: (error) => debugPrint('banner failed: $error'),
)
```

The widget loads itself when it enters the tree. It is not a preload object, and there is no separate `load()` call. While the request is in flight, that same box shows a skeleton. When the ad loads, it replaces the skeleton in that box. See [Loading placeholder](#loading-placeholder) for the built-in shapes and for passing your own shimmer through `loading`.

Changing the ad unit id or the size disposes the current ad and sends a new request.

## 6. Native

There is one native template. AdMob uses Google's medium template. There is no small native template, and this version does not take button colors or a custom layout.

The ad is drawn inside a box with a fixed `height`. The default is 320. That box does not grow with the screen size, the system font size, or the length of the ad text. If the template is taller than the box, Flutter clips the bottom, and the call-to-action is the part that disappears. A clipped call-to-action is an ad-policy problem: the button, the text, and the ad choices icon all have to be fully visible.

Pass a height that fits the whole template on the phones you support. Where 320 cuts the button off, 400 is a practical height:

```dart
EasyNativeAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn',
  height: 400,
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)
```

Do not put this widget inside another widget that clips it, such as a shorter `SizedBox`.

The widget loads itself when it enters the tree. While the request is in flight, the same box shows a skeleton of this height. The loaded ad replaces it without changing `height`. Pass `loading` to draw your own shimmer in that box. The shapes, the red **Ad** label, and a copy-paste widget are in [Loading placeholder](#loading-placeholder).

Changing the ad unit id sends a new request.

## Loading placeholder

Banner and native ads reserve their box as soon as the widget is built. Until an ad fills, that box shows a skeleton of the same size and the same shape as that format. Every skeleton has a red **Ad** label, outlined so it stays readable. The label is small on the 50-tall banner and larger on the other formats. A light band moves across the blocks. The blocks themselves stay in the shape of the ad.

| Format | What the skeleton looks like | Box size |
|---|---|---|
| `EasyBannerSize.banner` | Thumbnail, headline, and advertiser line | 50 tall |
| `EasyBannerSize.large` | Image, headline, description, and a button | 100 tall |
| `EasyBannerSize.mediumRectangle` | Large image, headline, description, and a button | 250 tall |
| Native | Icon, title, media, body, and a call-to-action | The `height` you pass, 320 by default |

When the ad loads, it replaces the skeleton in the same box, so the screen does not jump. If the request fails, the box collapses and the skeleton is removed. These widgets do not time out. A slow banner or native ad keeps its skeleton until it fills or fails.

### Your own shimmer

Pass `loading` to draw your own widget in that box. Any widget works: a shimmer from another package, a static placeholder, or the class below. The SDK already forces it to the ad's width and height, so do not wrap it in a different height. The loaded ad replaces it. A failed load removes it.

Omit `loading` to keep the built-in skeleton. Interstitials, rewarded ads, and rewarded interstitials do not take this parameter. Those ads are preloaded and shown later.

```dart
class AdShimmer extends StatelessWidget {
  const AdShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFECEFF1),
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: Text(
            'Ad',
            style: TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

EasyBannerAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb',
  size: EasyBannerSize.large,
  loading: const AdShimmer(),
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)

EasyNativeAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn',
  height: 400,
  loading: const AdShimmer(),
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)
```

## 7. Preload full-screen ads

Interstitials, app open ads, rewarded ads, and rewarded interstitials share this behavior. You create an object, call `load()`, keep that object, and call `show()` when you want the ad on screen. Banners and native ads do not work this way. Those widgets request an ad when they are built.

Interstitial and app open loads stop after 10 seconds unless you pass another `timeout`. A splash slot should keep that default and leave the screen from `onTimeout`. A slot you preload for later, such as a download button, can pass `timeout: null` so it waits for the network. Rewarded formats have no timeout.

### One object holds one ad

`load()` sends a request only when that object is empty.

* Already loaded: `load()` returns `true` and does not send another request. Check this with `isLoaded`.
* A request is already in flight: another `load()` waits for that same request. It does not start a second one.
* `show()` throws `StateError` when nothing is loaded yet. Check `isLoaded`, or use the `bool` returned by `load()`, before you show.
* After the user closes the ad, the object is empty again. The next `load()` is what sends a new request.
* `dispose()` drops the cached ad. Call it only when that object will never be shown again.

Put the next `load()` in `onClosed`. That request runs after the ad the user just saw, so you are not requesting a second ad while the first one is still loaded.

The SDK does not refresh a loaded ad on a timer. AdMob stops serving an interstitial or rewarded ad that has been sitting for about an hour. If `show()` fails, call `load()` again.

### One object per place you show an ad

A splash screen, a download button, and a notification screen each need their own object. Showing one does not clear the others. A second `load()` on an object that is already loaded does not add another request, so the request count stays at one per object until that ad is shown.

Create the objects once, after `EasyAds.initialize` has finished, and keep them for as long as those screens can show an ad. Constructing a new object every time the user opens a screen is a new request. That is the pattern that raises request volume and hurts fill.

Use a different AdMob ad unit for each place. The id has to be an interstitial id. A banner id fails.

```dart
class AdSlots {
  AdSlots() {
    splash = EasyInterstitialAd(
      admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/splash',
      onLoading: () {},
      onLoaded: (network) {},
      onError: (error) {},
      onClosed: () => splash.load(),
    );
    download = EasyInterstitialAd(
      admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/download',
      onLoading: () {},
      onLoaded: (network) {},
      onError: (error) {},
      onClosed: () => download.load(),
    );
    notification = EasyInterstitialAd(
      admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/notification',
      onLoading: () {},
      onLoaded: (network) {},
      onError: (error) {},
      onClosed: () => notification.load(),
    );
  }

  late final EasyInterstitialAd splash;
  late final EasyInterstitialAd download;
  late final EasyInterstitialAd notification;

  /// One request per slot. Calling this again while a slot is still
  /// loaded does not send another request for that slot.
  Future<void> preload() {
    return Future.wait([
      splash.load(),
      download.load(),
      notification.load(),
    ]);
  }

  Future<void> showSplash() async {
    if (!splash.isLoaded) {
      return;
    }
    await splash.show();
  }

  Future<void> dispose() async {
    await splash.dispose();
    await download.dispose();
    await notification.dispose();
  }
}
```

Create the slots once, then call `preload()` after `EasyAds.initialize` finishes. `onClosed` calls `load()` on that same object, so only the slot that was just shown requests the next ad. The other two stay loaded and do not request again.

Rewarded ads and rewarded interstitials use the same rules. Grant the reward in `onReward`. Preload the next ad in `onClosed`, not in `onReward`, because the user can earn the reward and still be looking at the ad.

## 8. Interstitial

Follow [Preload full-screen ads](#7-preload-full-screen-ads). This is the smallest version of that pattern: one object, load before the moment you need it, show the ad you already have.

```dart
late final EasyInterstitialAd interstitial;

void createInterstitial() {
  interstitial = EasyInterstitialAd(
    admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/iiiiiiiiii',
    onLoading: () {},
    onLoaded: (network) {},
    onError: (error) {},
    onTimeout: () {
      // Still not loaded. Leave the splash. onLoaded and onError
      // will not run for this attempt.
    },
    onClosed: () => interstitial.load(),
    timeout: const Duration(seconds: 10),
  );
}

Future<void> showInterstitial() async {
  final loaded = await interstitial.load();
  if (!loaded) {
    return;
  }
  await interstitial.show();
}
```

`load()` returns `true` when this object already has an ad, and in that case it does not request again. `show()` throws `StateError` if you call it before a load has filled. After `onClosed`, call `load()` before the next `show()`. Call `dispose()` when you will never show this object again.

`timeout` defaults to 10 seconds. Pass another duration, such as 8 seconds, when the splash should wait less. Pass `timeout: null` on a preloaded slot that should wait for the network. `await load()` returns `false` on timeout, and only `onTimeout` runs. A response that arrives later is discarded, so that attempt cannot load and then sit unshown.

## App open


Use one object on the splash screen. `onLoaded` shows the ad. `onTimeout` and `onError` both mean the splash should continue, and they do not both run for the same attempt. `onClosed` preloads the next one. The default `timeout` is 10 seconds. AdMob stops serving an app open ad that has been sitting for about four hours. If `show()` fails, call `load()` again.

```dart
late final EasyAppOpenAd appOpen;

void createAppOpen() {
  appOpen = EasyAppOpenAd(
    admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/oooooooooo',
    onLoading: () {},
    onLoaded: (network) async {
      await appOpen.show();
    },
    onError: (error) {
      leaveSplash();
    },
    onTimeout: leaveSplash,
    onClosed: () => appOpen.load(),
  );
}

void leaveSplash() {
  // Open the home screen. Do not call show().
}

Future<void> openApp() => appOpen.load();
```

## 9. Rewarded

```dart
late final EasyRewardedAd rewarded;

void createRewarded() {
  rewarded = EasyRewardedAd(
    admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/rrrrrrrrrr',
    onLoading: () {},
    onLoaded: (network) {},
    onError: (error) {},
    onClosed: () => rewarded.load(),
    onReward: (reward) {
      // Grant reward.amount of reward.type.
      // reward.network tells you who paid for it.
    },
  );
}

Future<void> showRewarded() async {
  if (!await rewarded.load()) {
    return;
  }
  await rewarded.show();
}
```

AdMob sends the amount and type configured on the ad unit. Grant the reward inside `onReward`, not inside `onClosed`. The user can close a rewarded ad without earning it.

This object follows [Preload full-screen ads](#7-preload-full-screen-ads). `load()` does not send another request while `isLoaded` is true. Call `load()` from `onClosed` when you want the next rewarded ad ready. Use a separate `EasyRewardedAd` for each place you show one.

## 10. Rewarded interstitial

Same callbacks as rewarded. Show it at a natural break, the same way you show an interstitial.

```dart
late final EasyRewardedInterstitialAd rewardedInterstitial;

void createRewardedInterstitial() {
  rewardedInterstitial = EasyRewardedInterstitialAd(
    admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/wwwwwwwwww',
    onLoading: () {},
    onLoaded: (network) {},
    onError: (error) {},
    onClosed: () => rewardedInterstitial.load(),
    onReward: (reward) {},
  );
}

Future<void> showRewardedInterstitial() async {
  if (!await rewardedInterstitial.load()) {
    return;
  }
  await rewardedInterstitial.show();
}
```

This object follows [Preload full-screen ads](#7-preload-full-screen-ads). `onClosed` preloads the next ad. `onReward` only grants the reward.

## Reading errors

`onError` receives an `EasyAdError`. `error.failures` lists the AdMob failure:

```dart
onError: (error) {
  for (final failure in error.failures) {
    debugPrint('${failure.network.name}: ${failure.message}');
  }
}
```

## Placement ids must match the format

Create one AdMob ad unit per format. A banner id cannot be used as an interstitial id. The request fails.

## Example app

`example/` is a working app wired to Google's demo ad units. It is already in test mode. The screen loads a banner and a native ad on its own, and it has buttons for interstitial, app open, rewarded, and rewarded interstitial. Interstitial and app open use the 10 second timeout. The status line names the callback that ran.

```bash
cd example
flutter run
```

The Android demo app id is `ca-app-pub-3940256099942544~3347511713`. The iOS demo app id is `ca-app-pub-3940256099942544~1458002511`. Both are already in the example project.

## Keeping the SDKs current

1. Check [google_mobile_ads on pub.dev](https://pub.dev/packages/google_mobile_ads) and set that version in `pubspec.yaml`.
2. Check [gma_mediation_meta on pub.dev](https://pub.dev/packages/gma_mediation_meta) and set the version tested with that Google plugin. That package brings the Meta adapter and the Audience Network SDK.
3. Update `EasyAdsVersions` and the version table so they match.
4. Compare the iOS `SKAdNetworkItems` list with Google's current quick start.
