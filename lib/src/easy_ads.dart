import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_priority.dart';
import 'facebook/facebook_bridge.dart';

/// Optional Facebook setup.
///
/// Pass this to [EasyAds.initialize] only when the app has completed the
/// Facebook steps in the README. Leave it out and every ad uses AdMob only.
class FacebookOptions {
  /// Creates Facebook setup.
  const FacebookOptions({this.iosAdvertiserTrackingEnabled = false});

  /// Asks Meta to use the iOS advertising identifier.
  ///
  /// This is applied only after the user has allowed App Tracking
  /// Transparency. Call [EasyAds.requestIosTrackingAuthorization] first,
  /// then pass `true` here when the status is [IosTrackingStatus.authorized].
  final bool iosAdvertiserTrackingEnabled;
}

/// Result of [EasyAds.requestIosTrackingAuthorization].
enum IosTrackingStatus {
  /// The user allowed tracking.
  authorized,

  /// The user denied tracking.
  denied,

  /// Tracking is restricted on this device.
  restricted,

  /// The user has not answered yet.
  notDetermined,

  /// This platform does not use App Tracking Transparency.
  notSupported,
}

/// Entry point for the SDK.
///
/// Call [initialize] once after `WidgetsFlutterBinding.ensureInitialized()`
/// and before any ad is created.
class EasyAds {
  EasyAds._();

  static EasyAdPriority _priority = EasyAdPriority.admob;
  static bool _testMode = false;
  static bool _facebookEnabled = false;
  static bool _ready = false;
  static Future<void>? _initFuture;

  /// The priority chosen in [initialize].
  static EasyAdPriority get priority => _priority;

  /// Whether [initialize] was called with test mode.
  static bool get testMode => _testMode;

  /// Whether Meta Audience Network initialized successfully.
  static bool get isFacebookEnabled => _facebookEnabled;

  /// Whether [initialize] has finished.
  static bool get isInitialized => _ready;

  /// Starts AdMob, and starts Facebook when [facebook] is provided.
  ///
  /// AdMob is required. A missing AdMob app id in the native project crashes
  /// the app before this future can recover, so complete the README setup
  /// first.
  ///
  /// Facebook is optional. If [facebook] is omitted, or Facebook cannot
  /// initialize, ads continue with AdMob only.
  ///
  /// A second call waits for the first one and does not change the original
  /// priority or test mode.
  static Future<void> initialize({
    EasyAdPriority priority = EasyAdPriority.admob,
    FacebookOptions? facebook,
    bool testMode = false,
  }) {
    if (_ready) {
      return Future<void>.value();
    }
    final existing = _initFuture;
    if (existing != null) {
      return existing;
    }
    final future = _run(
      priority: priority,
      facebook: facebook,
      testMode: testMode,
    );
    _initFuture = future;
    return future;
  }

  static Future<void> _run({
    required EasyAdPriority priority,
    required FacebookOptions? facebook,
    required bool testMode,
  }) async {
    try {
      await _initialize(
        priority: priority,
        facebook: facebook,
        testMode: testMode,
      );
      _ready = true;
    } catch (error) {
      _initFuture = null;
      rethrow;
    }
  }

  /// Shows the iOS tracking prompt.
  ///
  /// The host app must include `NSUserTrackingUsageDescription` in
  /// `Info.plist` before this is called. On Android this returns
  /// [IosTrackingStatus.notSupported] and does not show a prompt.
  static Future<IosTrackingStatus> requestIosTrackingAuthorization() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return IosTrackingStatus.notSupported;
    }
    final status = await FacebookBridge.requestTracking();
    return switch (status) {
      'authorized' => IosTrackingStatus.authorized,
      'denied' => IosTrackingStatus.denied,
      'restricted' => IosTrackingStatus.restricted,
      _ => IosTrackingStatus.notDetermined,
    };
  }

  static Future<void> _initialize({
    required EasyAdPriority priority,
    required FacebookOptions? facebook,
    required bool testMode,
  }) async {
    _priority = priority;
    _testMode = testMode;
    _facebookEnabled = false;

    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported) {
      throw UnsupportedError('Easy Ads supports Android and iOS only.');
    }

    await MobileAds.instance.initialize();

    if (facebook == null) {
      return;
    }

    try {
      await FacebookBridge.initialize(
        testMode: testMode,
        advertiserTrackingEnabled: facebook.iosAdvertiserTrackingEnabled,
      );
      _facebookEnabled = true;
    } catch (error) {
      _facebookEnabled = false;
      debugPrint(
        'EasyAds: Facebook was not initialized and will be skipped. $error',
      );
    }
  }
}
