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
