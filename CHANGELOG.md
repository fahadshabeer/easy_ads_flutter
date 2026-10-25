## 0.1.1

* Bundles the AdMob Meta Audience Network bidding adapter (`gma_mediation_meta` 1.7.1, Android adapter 6.22.0.1, iOS adapter 6.22.0.0).
* An existing AdMob request can fill from Meta inventory after Meta is added as a bidding source on that ad unit. App call sites stay the same.
* Direct Meta placements are unchanged.
* Sets Meta's iOS advertiser-tracking flag before AdMob starts, including when `FacebookOptions` is omitted.
* Documents the app setup and the existing Dart API for Meta bidding.

## 0.1.0

* First release.
* One Dart API for AdMob and Meta Audience Network on Android and iOS.
* Banner, interstitial, rewarded, rewarded interstitial, and template native ads.
* AdMob is required. Facebook is optional and is skipped when it cannot initialize.
* Priority chooses which network is requested first. The other network is requested only after the first one fails.
* Pins `google_mobile_ads` 9.1.0 (Google Mobile Ads Android 25.4.0, iOS 13.7.0) and Meta Audience Network 6.22.0.
* Documents full-screen preload, separate ad instances, banner sizes, and native height.
* Shows a same-size skeleton, with a red Ad label, while a banner or native ad is loading.
* Banner and native ads accept a `loading` widget so an app can supply its own shimmer.
* Documents the built-in loading skeleton and a copy-paste custom shimmer.
* Gathers European consent before ad requests and blocks ads until consent allows them.
* Documents the settings entry that reopens ad privacy options after consent.
* Matches each banner and native skeleton to that format, including the red Ad label.
* Adds app open ads, and a 10 second load timeout for interstitial and app open.
* Documents git install, the callback list, app open, and which formats time out.
