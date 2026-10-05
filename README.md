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

Banners and native ads load themselves when the widget is on screen. Interstitials, rewarded ads, and rewarded interstitials do not. You preload those, keep the object, and call `show()` later. See [Preload full-screen ads](#7-preload-full-screen-ads).

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

Three sizes work on both networks. Pass `size`. If you omit it, the widget uses `EasyBannerSize.banner`.

| Size | AdMob | Meta |
|---|---|---|
| `EasyBannerSize.banner` | 320×50 | 50 tall |
| `EasyBannerSize.large` | 320×100 | 90 tall |
| `EasyBannerSize.mediumRectangle` | 300×250 | 300×250 |

`large` is 100 tall when AdMob fills and 90 tall when Meta fills. The other two sizes use the same height on both networks.

```dart
EasyBannerAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/bbbbbbbbbb',
  facebookPlacementId: 'YOUR_FACEBOOK_BANNER_PLACEMENT', // optional
  size: EasyBannerSize.mediumRectangle,
  onLoading: () => debugPrint('banner loading'),
  onLoaded: (network) => debugPrint('banner from ${network.name}'),
  onError: (error) => debugPrint('banner failed: $error'),
)
```

The widget loads itself when it enters the tree. It is not a preload object, and there is no separate `load()` call. While the request is in flight, that same box shows a skeleton. When the ad loads, it replaces the skeleton in that box. See [Loading placeholder](#loading-placeholder) for the built-in shapes and for passing your own shimmer through `loading`.

Changing the ad unit id, the Facebook placement id, or the size disposes the current ad and sends a new request.

## 6. Native

There is one native template. AdMob uses Google's medium template. Meta uses the template built into this package: icon, title, sponsored label, media, body, and call-to-action button. There is no small native template, and this version does not take button colors or a custom layout.

The ad is drawn inside a box with a fixed `height`. The default is 320. That box does not grow with the screen size, the system font size, or the length of the ad text. If the template is taller than the box, Flutter clips the bottom, and the call-to-action is the part that disappears. A clipped call-to-action is an ad-policy problem: the button, the text, and the ad choices icon all have to be fully visible.

Pass a height that fits the whole template on the phones you support. Where 320 cuts the button off, 400 is a practical height:

```dart
EasyNativeAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn',
  facebookPlacementId: 'YOUR_FACEBOOK_NATIVE_PLACEMENT', // optional
  height: 400,
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)
```

Keep `height` at 250 or more. Meta does not count an impression when the media area is shorter than that. Do not put this widget inside another widget that clips it, such as a shorter `SizedBox`.

The widget loads itself when it enters the tree. While the request is in flight, the same box shows a skeleton of this height. The loaded ad replaces it without changing `height`. Pass `loading` to draw your own shimmer in that box. The shapes, the red **Ad** label, and a copy-paste widget are in [Loading placeholder](#loading-placeholder).

Changing the ad unit id or the Facebook placement id sends a new request.

## Loading placeholder

Banner and native ads reserve their box as soon as the widget is built. Until an ad fills, that box shows the built-in skeleton: gray blocks in the shape of that format, and a red **Ad** label in the top-left corner.

| Format | What the skeleton looks like | Box size |
|---|---|---|
| `EasyBannerSize.banner` | Image block and two text lines | 50 tall |
| `EasyBannerSize.large` | Image, text, and a button | 100 tall, or 90 when Meta fills |
| `EasyBannerSize.mediumRectangle` | Large image, text, and a button | 250 tall |
| Native | Icon, title, media, body, and a call-to-action | The `height` you pass, 320 by default |

When the ad loads, it replaces the skeleton in the same box, so the screen does not jump. If every network fails, the box collapses and the skeleton is removed.

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
  facebookPlacementId: 'YOUR_FACEBOOK_BANNER_PLACEMENT', // optional
  size: EasyBannerSize.large,
  loading: const AdShimmer(),
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)

EasyNativeAd(
  admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/nnnnnnnnnn',
  facebookPlacementId: 'YOUR_FACEBOOK_NATIVE_PLACEMENT', // optional
  height: 400,
  loading: const AdShimmer(),
  onLoading: () {},
  onLoaded: (network) {},
  onError: (error) {},
)
```

## 7. Preload full-screen ads

Interstitials, rewarded ads, and rewarded interstitials share this behavior. You create an object, call `load()`, keep that object, and call `show()` when you want the ad on screen. Banners and native ads do not work this way. Those widgets request an ad when they are built.

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

Use a different AdMob ad unit, and a different Meta placement, for each place. The id has to be an interstitial id. A banner id fails, and the SDK then tries the other network.

```dart
class AdSlots {
  AdSlots() {
    splash = EasyInterstitialAd(
      admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/splash',
      facebookPlacementId: 'YOUR_SPLASH_PLACEMENT',
      onLoading: () {},
      onLoaded: (network) {},
      onError: (error) {},
      onClosed: () => splash.load(),
    );
    download = EasyInterstitialAd(
      admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/download',
      facebookPlacementId: 'YOUR_DOWNLOAD_PLACEMENT',
      onLoading: () {},
      onLoaded: (network) {},
      onError: (error) {},
      onClosed: () => download.load(),
    );
    notification = EasyInterstitialAd(
      admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/notification',
      facebookPlacementId: 'YOUR_NOTIFICATION_PLACEMENT',
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
    facebookPlacementId: 'YOUR_FACEBOOK_INTERSTITIAL_PLACEMENT', // optional
    onLoading: () {},
    onLoaded: (network) {},
    onError: (error) {},
    onClosed: () => interstitial.load(),
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

## 9. Rewarded

```dart
late final EasyRewardedAd rewarded;

void createRewarded() {
  rewarded = EasyRewardedAd(
    admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/rrrrrrrrrr',
    facebookPlacementId: 'YOUR_FACEBOOK_REWARDED_PLACEMENT', // optional
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

AdMob sends the amount and type configured on the ad unit. Facebook sends amount `1` and type `reward` when the video completes. Grant the reward inside `onReward`, not inside `onClosed`. The user can close a rewarded ad without earning it.

This object follows [Preload full-screen ads](#7-preload-full-screen-ads). `load()` does not send another request while `isLoaded` is true. Call `load()` from `onClosed` when you want the next rewarded ad ready. Use a separate `EasyRewardedAd` for each place you show one.

## 10. Rewarded interstitial

Same callbacks as rewarded. Show it at a natural break, the same way you show an interstitial.

```dart
late final EasyRewardedInterstitialAd rewardedInterstitial;

void createRewardedInterstitial() {
  rewardedInterstitial = EasyRewardedInterstitialAd(
    admobAdUnitId: 'ca-app-pub-xxxxxxxxxxxxxxxx/wwwwwwwwww',
    facebookPlacementId: 'YOUR_FACEBOOK_REWARDED_INTERSTITIAL_PLACEMENT',
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
