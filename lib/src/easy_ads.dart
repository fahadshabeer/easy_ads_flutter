import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_error.dart';
import 'consent_debug.dart';
import 'internal/waterfall.dart';

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

  static const MethodChannel _tracking = MethodChannel('easy_ads_sdk/tracking');

  static bool _testMode = false;
  static bool _ready = false;
  static bool _canRequestAds = false;
  static bool _privacyOptionsRequired = false;
  static bool _networksStarted = false;
  static Future<void>? _initFuture;

  /// Whether [initialize] was called with test mode.
  static bool get testMode => _testMode;

  /// Whether [initialize] has finished.
  static bool get isInitialized => _ready;

  /// Whether an ad request is allowed after consent.
  ///
  /// This is false until [initialize] finishes. It stays false when the
  /// user is in Europe and has not granted consent. Elsewhere it becomes
  /// true without a form.
  static bool get canRequestAds => _canRequestAds;

  /// Whether the app must offer a way to change the consent choice.
  ///
  /// Google requires this entry point for European users who have seen
  /// the consent form. Call [showPrivacyOptionsForm] from that entry point.
  static bool get isPrivacyOptionsRequired => _privacyOptionsRequired;

  /// Starts consent, then AdMob.
  ///
  /// AdMob is required. A missing AdMob app id in the native project crashes
  /// the app before this future can recover, so complete the README setup
  /// first. Meta inventory is included when Meta Audience Network is a
  /// bidding source on the ad unit. The mediation adapter ships with this
  /// package.
  ///
  /// A second call waits for the first one and does not change the original
  /// test mode.
  ///
  /// [consentDebug] forces the European form on a test device. Do not pass
  /// it in a release build.
  ///
  /// [tagForUnderAgeOfConsent] marks the user as under the age of consent.
  /// The form is not shown, and ad requests stay limited.
  ///
  /// Start this, then call `runApp`. The European form is a native dialog
  /// and needs the app on screen. Awaiting [initialize] before `runApp`
  /// can finish before that dialog has a window.
  static Future<void> initialize({
    bool testMode = false,
    EasyConsentDebug? consentDebug,
    bool tagForUnderAgeOfConsent = false,
  }) {
    if (_ready) {
      return Future<void>.value();
    }
    final existing = _initFuture;
    if (existing != null) {
      return existing;
    }
    final future = _run(
      testMode: testMode,
      consentDebug: consentDebug,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
    );
    _initFuture = future;
    return future;
  }

  static Future<void> _run({
    required bool testMode,
    required EasyConsentDebug? consentDebug,
    required bool tagForUnderAgeOfConsent,
  }) async {
    try {
      await _initialize(
        testMode: testMode,
        consentDebug: consentDebug,
        tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      );
      _ready = true;
    } catch (error) {
      _initFuture = null;
      rethrow;
    }
  }

  /// Opens the European privacy form again.
  ///
  /// Call this from a settings entry when [isPrivacyOptionsRequired] is
  /// true. The form is the same one Google showed at startup.
  static Future<void> showPrivacyOptionsForm() async {
    final pending = _initFuture;
    if (!_ready && pending != null) {
      await pending;
    }
    if (!_ready) {
      throw StateError(
        'Call EasyAds.initialize() before showing privacy options.',
      );
    }
    final error = await _showPrivacyOptions();
    await _refreshConsent();
    await _startNetworks();
    if (error != null) {
      throw StateError(error.message);
    }
  }

  /// Waits for startup, then reports why an ad request must stop.
  static Future<EasyAdError?> prepareRequest() async {
    final pending = _initFuture;
    if (!_ready && pending != null) {
      try {
        await pending;
      } catch (error) {
        return EasyAdError(message: error.toString());
      }
    }
    return adRequestBlock(
      initialized: _ready,
      canRequestAds: _canRequestAds,
    );
  }

  /// Shows the iOS App Tracking Transparency prompt.
  ///
  /// The host app must include `NSUserTrackingUsageDescription` in
  /// `Info.plist` before this is called. On Android this returns
  /// [IosTrackingStatus.notSupported] and does not show a prompt.
  ///
  /// Call this before [initialize] when the app asks for tracking. On iOS 17
  /// and later, the Meta mediation adapter reads that system status itself.
  static Future<IosTrackingStatus> requestIosTrackingAuthorization() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return IosTrackingStatus.notSupported;
    }
    try {
      final status = await _tracking.invokeMethod<String>('requestTracking');
      return switch (status) {
        'authorized' => IosTrackingStatus.authorized,
        'denied' => IosTrackingStatus.denied,
        'restricted' => IosTrackingStatus.restricted,
        _ => IosTrackingStatus.notDetermined,
      };
    } on MissingPluginException {
      return IosTrackingStatus.notDetermined;
    } on PlatformException {
      return IosTrackingStatus.notDetermined;
    }
  }

  static Future<void> _initialize({
    required bool testMode,
    required EasyConsentDebug? consentDebug,
    required bool tagForUnderAgeOfConsent,
  }) async {
    _testMode = testMode;

    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported) {
      throw UnsupportedError('Easy Ads supports Android and iOS only.');
    }

    await _gatherConsent(
      consentDebug: consentDebug,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
    );
    await _startNetworks();
  }

  static Future<void> _gatherConsent({
    required EasyConsentDebug? consentDebug,
    required bool tagForUnderAgeOfConsent,
  }) async {
    final updateError = await _requestConsentInfoUpdate(
      consentDebug: consentDebug,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
    );
    if (updateError != null) {
      debugPrint(
        'EasyAds: consent info was not updated. ${updateError.message}',
      );
    } else {
      await _presentConsentForm();
    }
    await _refreshConsent();
  }

  static Future<void> _presentConsentForm() async {
    final error = await _loadAndShowConsentForm();
    if (error == null) {
      return;
    }
    debugPrint('EasyAds: consent form was not shown. ${error.message}');
    if (WidgetsBinding.instance.firstFrameRasterized) {
      return;
    }
    try {
      await _waitForFirstFrame();
    } on TimeoutException {
      debugPrint(
        'EasyAds: the consent form had no window. '
        'Call runApp before awaiting EasyAds.initialize().',
      );
      return;
    }
    final retry = await _loadAndShowConsentForm();
    if (retry != null) {
      debugPrint('EasyAds: consent form was not shown. ${retry.message}');
    }
  }

  static Future<void> _waitForFirstFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
    return completer.future.timeout(const Duration(seconds: 3));
  }

  static Future<FormError?> _requestConsentInfoUpdate({
    required EasyConsentDebug? consentDebug,
    required bool tagForUnderAgeOfConsent,
  }) {
    final completer = Completer<FormError?>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(
        tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
        consentDebugSettings: _debugSettings(consentDebug),
      ),
      () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.complete(error);
        }
      },
    );
    return completer.future;
  }

  static ConsentDebugSettings? _debugSettings(EasyConsentDebug? debug) {
    if (debug == null) {
      return null;
    }
    return ConsentDebugSettings(
      debugGeography: switch (debug.geography) {
        EasyConsentDebugGeography.eea => DebugGeography.debugGeographyEea,
        EasyConsentDebugGeography.other => DebugGeography.debugGeographyOther,
        EasyConsentDebugGeography.regulatedUsState =>
          DebugGeography.debugGeographyRegulatedUsState,
      },
      testIdentifiers: debug.testDeviceIds,
    );
  }

  static Future<FormError?> _loadAndShowConsentForm() {
    final completer = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (!completer.isCompleted) {
        completer.complete(error);
      }
    });
    return completer.future;
  }

  static Future<FormError?> _showPrivacyOptions() {
    final completer = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (!completer.isCompleted) {
        completer.complete(error);
      }
    });
    return completer.future;
  }

  static Future<void> _refreshConsent() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    final privacy =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    _privacyOptionsRequired =
        privacy == PrivacyOptionsRequirementStatus.required;
  }

  static Future<void> _startNetworks() async {
    if (_networksStarted || !_canRequestAds) {
      return;
    }
    _networksStarted = true;
    await MobileAds.instance.initialize();
  }
}
