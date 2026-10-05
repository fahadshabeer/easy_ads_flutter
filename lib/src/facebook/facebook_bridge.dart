import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A callback from the Facebook side of the SDK.
class FacebookEvent {
  /// Creates an event parsed from the platform channel.
  FacebookEvent({
    required this.id,
    required this.type,
    this.message,
    this.code,
    this.rewardAmount,
    this.rewardType,
  });

  /// Ad instance id created by [FacebookBridge.newId].
  final String id;

  /// `closed`, `reward`, `clicked`, or `impression`.
  final String type;

  /// Error or diagnostic text, when the platform sent one.
  final String? message;

  /// Network error code, when the platform sent one.
  final int? code;

  /// Reward amount. Facebook video completion uses 1.
  final int? rewardAmount;

  /// Reward name. Facebook video completion uses `reward`.
  final String? rewardType;

  /// Parses a platform event map.
  factory FacebookEvent.fromMap(Map<Object?, Object?> map) {
    return FacebookEvent(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? '',
      message: map['message'] as String?,
      code: map['code'] as int?,
      rewardAmount: map['rewardAmount'] as int?,
      rewardType: map['rewardType'] as String?,
    );
  }
}

/// Failure thrown by a Facebook method call before it is turned into
/// [EasyAdFailure].
class FacebookCallException implements Exception {
  /// Creates a Facebook call failure.
  FacebookCallException({required this.message, this.code});

  /// Platform error message.
  final String message;

  /// Audience Network error code, when one was provided.
  final int? code;

  @override
  String toString() => message;
}

/// Method channel used by the Dart API. Not part of the public surface.
class FacebookBridge {
  FacebookBridge._();

  static const MethodChannel _methods = MethodChannel('easy_ads_sdk/facebook');
  static const EventChannel _events = EventChannel(
    'easy_ads_sdk/facebook_events',
  );

  static final StreamController<FacebookEvent> _controller =
      StreamController<FacebookEvent>.broadcast();
  static StreamSubscription<dynamic>? _subscription;
  static int _sequence = 0;

  /// A new id for one Facebook ad instance.
  static String newId(String kind) => '$kind-${++_sequence}';

  /// Starts listening for Facebook events. Safe to call more than once.
  static void start() {
    if (_subscription != null) {
      return;
    }
    _subscription = _events.receiveBroadcastStream().listen(
      (Object? raw) {
        if (raw is! Map) {
          return;
        }
        _controller.add(
          FacebookEvent.fromMap(Map<Object?, Object?>.from(raw)),
        );
      },
      onError: (Object error) {
        debugPrint('EasyAds Facebook event stream error: $error');
      },
    );
  }

  /// Listens to events for one ad id.
  static StreamSubscription<FacebookEvent> listen(
    String id,
    void Function(FacebookEvent event) onData,
  ) {
    return _controller.stream.where((event) => event.id == id).listen(onData);
  }

  /// Initializes Meta Audience Network.
  static Future<void> initialize({
    required bool testMode,
    required bool advertiserTrackingEnabled,
  }) {
    start();
    return _invoke('initialize', <String, Object?>{
      'testMode': testMode,
      'advertiserTrackingEnabled': advertiserTrackingEnabled,
    });
  }

  /// Asks for App Tracking Transparency permission on iOS.
  static Future<String> requestTracking() async {
    try {
      final status = await _methods.invokeMethod<String>('requestTracking');
      return status ?? 'notDetermined';
    } on PlatformException catch (error) {
      throw FacebookCallException(message: error.message ?? error.code);
    }
  }

  /// Loads a banner and keeps the native view until [dispose] is called.
  static Future<void> loadBanner({
    required String id,
    required String placementId,
    required String size,
  }) {
    return _invoke('loadBanner', <String, Object?>{
      'id': id,
      'placementId': placementId,
      'size': size,
    });
  }

  /// Loads a template native ad.
  static Future<void> loadNative({
    required String id,
    required String placementId,
  }) {
    return _invoke('loadNative', <String, Object?>{
      'id': id,
      'placementId': placementId,
    });
  }

  /// Loads an interstitial.
  static Future<void> loadInterstitial({
    required String id,
    required String placementId,
  }) {
    return _invoke('loadInterstitial', <String, Object?>{
      'id': id,
      'placementId': placementId,
    });
  }

  /// Shows a loaded interstitial.
  static Future<void> showInterstitial({required String id}) {
    return _invoke('showInterstitial', <String, Object?>{'id': id});
  }

  /// Loads a rewarded video.
  static Future<void> loadRewarded({
    required String id,
    required String placementId,
  }) {
    return _invoke('loadRewarded', <String, Object?>{
      'id': id,
      'placementId': placementId,
    });
  }

  /// Shows a loaded rewarded video.
  static Future<void> showRewarded({required String id}) {
    return _invoke('showRewarded', <String, Object?>{'id': id});
  }

  /// Loads a rewarded interstitial.
  static Future<void> loadRewardedInterstitial({
    required String id,
    required String placementId,
  }) {
    return _invoke('loadRewardedInterstitial', <String, Object?>{
      'id': id,
      'placementId': placementId,
    });
  }

  /// Shows a loaded rewarded interstitial.
  static Future<void> showRewardedInterstitial({required String id}) {
    return _invoke('showRewardedInterstitial', <String, Object?>{'id': id});
  }

  /// Destroys any native object stored for [id]. Safe to call twice.
  static Future<void> dispose({required String id}) async {
    try {
      await _methods.invokeMethod<void>('dispose', <String, Object?>{
        'id': id,
      });
    } on PlatformException {
      // The native side already removed it, or the engine is gone.
    }
  }

  static Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _methods.invokeMethod<void>(method, args);
    } on PlatformException catch (error) {
      int? code;
      final details = error.details;
      if (details is Map && details['code'] is int) {
        code = details['code'] as int;
      }
      throw FacebookCallException(
        message: error.message ?? 'Facebook $method failed.',
        code: code,
      );
    }
  }
}
