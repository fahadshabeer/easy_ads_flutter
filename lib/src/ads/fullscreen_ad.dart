import 'dart:async';

import 'package:flutter/foundation.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import '../facebook/facebook_bridge.dart';
import '../internal/load_gate.dart';
import '../internal/waterfall.dart';
import '../reward.dart';

/// Shared load, show, and fallback behavior for full-screen ads.
abstract class FullScreenAdBase {
  /// Creates the shared full-screen controller.
  FullScreenAdBase({
    required this.admobAdUnitId,
    required this.format,
    this.facebookPlacementId,
    this.onLoading,
    this.onLoaded,
    this.onError,
    this.onClosed,
    this.onReward,
    this.onTimeout,
    this.timeout,
  });

  /// AdMob ad unit id.
  final String admobAdUnitId;

  /// Which full-screen format this object loads.
  final EasyAdFormat format;

  /// Facebook placement id. Omit it to use AdMob only.
  final String? facebookPlacementId;

  /// Called once, when the first request starts.
  final VoidCallback? onLoading;

  /// Called with the network that filled the ad.
  final void Function(EasyAdNetwork network)? onLoaded;

  /// Called when the ad cannot load or cannot be shown.
  final void Function(EasyAdError error)? onError;

  /// Called when the full-screen ad is dismissed.
  final VoidCallback? onClosed;

  /// Called when the user earns a reward. Unused by interstitials.
  final void Function(EasyReward reward)? onReward;

  /// Called when [timeout] elapses before a network fills.
  ///
  /// [onLoaded] and [onError] do not run for that load after this.
  /// Null on formats that wait for the network.
  final VoidCallback? onTimeout;

  /// How long [load] waits before [onTimeout].
  ///
  /// Null waits until the network answers. Interstitial and app open
  /// default this to 10 seconds.
  final Duration? timeout;

  EasyAdNetwork? _loadedNetwork;
  Future<bool>? _loadFuture;
  bool _disposed = false;
  bool _showing = false;
  int _generation = 0;
  Timer? _timeoutTimer;
  AdLoadGate? _gate;
  String? _facebookId;
  StreamSubscription<FacebookEvent>? _facebookSub;

  /// Whether [load] has finished with an ad that can be shown.
  bool get isLoaded => _loadedNetwork != null && !_disposed;

  /// Loads the ad. Returns `true` when a network filled.
  ///
  /// A second call while a load is already running waits for that load.
  /// A call after a fill returns `true` without requesting again.
  Future<bool> load() {
    if (_disposed) {
      return Future<bool>.error(StateError('This ad has been disposed.'));
    }
    if (_loadedNetwork != null) {
      return Future<bool>.value(true);
    }
    final existing = _loadFuture;
    if (existing != null) {
      return existing;
    }
    final completer = Completer<bool>();
    final generation = ++_generation;
    final gate = AdLoadGate();
    _gate = gate;
    _loadFuture = completer.future;
    unawaited(() async {
      try {
        final loaded = await _load(generation, gate, completer);
        if (!completer.isCompleted) {
          completer.complete(loaded);
        }
      } catch (error, stack) {
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      } finally {
        _timeoutTimer?.cancel();
        if (identical(_loadFuture, completer.future)) {
          _loadFuture = null;
        }
      }
    }());
    return completer.future;
  }

  /// Shows the loaded ad.
  ///
  /// Throws [StateError] when [load] has not filled yet.
  Future<void> show() async {
    if (_disposed) {
      throw StateError('This ad has been disposed.');
    }
    final network = _loadedNetwork;
    if (network == null) {
      throw StateError('Call load() and wait for onLoaded before show().');
    }
    if (_showing) {
      return;
    }
    _showing = true;
    try {
      await showNetwork(network);
    } catch (error) {
      _showing = false;
      _loadedNetwork = null;
      final message = error is FacebookCallException
          ? error.message
          : error.toString();
      onError?.call(EasyAdError(message: message));
      rethrow;
    }
  }

  /// Releases the loaded ad. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _generation++;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _gate?.close();
    _loadedNetwork = null;
    _showing = false;
    await discardNetwork(EasyAdNetwork.admob);
    await discardNetwork(EasyAdNetwork.facebook);
  }

  /// Loads one network. Implemented by each format.
  Future<LoadAttempt> loadNetwork(EasyAdNetwork network);

  /// Presents the ad from [network].
  Future<void> showNetwork(EasyAdNetwork network);

  /// Destroys a network's ad object if this controller still holds one.
  Future<void> discardNetwork(EasyAdNetwork network);

  /// Loads Facebook and keeps the subscription for reward and close events.
  @protected
  Future<LoadAttempt> loadFacebook(
    Future<void> Function(String id) load,
  ) async {
    final id = FacebookBridge.newId(format.name);
    _facebookId = id;
    await _facebookSub?.cancel();
    _facebookSub = FacebookBridge.listen(id, _onFacebookEvent);
    try {
      await load(id);
      return const LoadAttempt.filled();
    } on FacebookCallException catch (error) {
      await _clearFacebook();
      return LoadAttempt.failed(
        EasyAdFailure(
          network: EasyAdNetwork.facebook,
          message: error.message,
          code: error.code,
        ),
      );
    }
  }

  /// Shows the Facebook ad stored for this controller.
  @protected
  Future<void> showFacebook(Future<void> Function(String id) show) async {
    final id = _facebookId;
    if (id == null) {
      throw StateError('Facebook ad is not loaded.');
    }
    await show(id);
  }

  /// Clears the Facebook ad held by this controller.
  @protected
  Future<void> clearFacebook() => _clearFacebook();

  /// The Facebook instance id, when a Facebook load has started.
  @protected
  String? get facebookId => _facebookId;

  /// Called by AdMob when the full-screen ad closes.
  @protected
  void notifyClosed() {
    if (_disposed || (_gate?.timedOut ?? false)) {
      return;
    }
    _showing = false;
    _loadedNetwork = null;
    _facebookId = null;
    onClosed?.call();
  }

  /// Called by AdMob when show() fails after a successful load.
  @protected
  void notifyShowFailed(String message) {
    if (_disposed || (_gate?.timedOut ?? false)) {
      return;
    }
    _showing = false;
    _loadedNetwork = null;
    onError?.call(EasyAdError(message: message));
  }

  /// Delivers an AdMob reward.
  @protected
  void notifyReward(EasyReward reward) {
    if (_disposed) {
      return;
    }
    onReward?.call(reward);
  }

  void _armTimeout(int generation, AdLoadGate gate, Completer<bool> done) {
    _timeoutTimer?.cancel();
    final limit = timeout;
    if (limit == null) {
      return;
    }
    _timeoutTimer = Timer(limit, () {
      if (_disposed || generation != _generation || !gate.claimTimeout()) {
        return;
      }
      _timeoutTimer = null;
      if (!done.isCompleted) {
        done.complete(false);
      }
      if (identical(_loadFuture, done.future)) {
        _loadFuture = null;
      }
      onTimeout?.call();
      unawaited(discardNetwork(EasyAdNetwork.admob));
      unawaited(discardNetwork(EasyAdNetwork.facebook));
    });
  }

  Future<bool> _load(
    int generation,
    AdLoadGate gate,
    Completer<bool> done,
  ) async {
    final blocked = await EasyAds.prepareRequest();
    if (_disposed || generation != _generation || gate.timedOut) {
      return false;
    }
    if (blocked != null) {
      if (gate.claimResult()) {
        onError?.call(blocked);
      }
      return false;
    }
    _armTimeout(generation, gate, done);
    if (gate.timedOut) {
      return false;
    }
    onLoading?.call();
    final failures = <EasyAdFailure>[];
    final network = await runWaterfall(
      facebookPlacementId: facebookPlacementId,
      isCancelled: () => _disposed || gate.timedOut || generation != _generation,
      failures: failures,
      load: loadNetwork,
      discard: discardNetwork,
    );
    _timeoutTimer?.cancel();
    if (_disposed || generation != _generation || !gate.claimResult()) {
      return false;
    }
    if (network == null) {
      onError?.call(noFillError(failures));
      return false;
    }
    _loadedNetwork = network;
    onLoaded?.call(network);
    return true;
  }

  void _onFacebookEvent(FacebookEvent event) {
    if (_disposed || (_gate?.timedOut ?? false) || event.id != _facebookId) {
      return;
    }
    switch (event.type) {
      case 'reward':
        onReward?.call(
          EasyReward(
            amount: event.rewardAmount ?? 1,
            type: event.rewardType ?? 'reward',
            network: EasyAdNetwork.facebook,
          ),
        );
      case 'closed':
        _showing = false;
        _loadedNetwork = null;
        _facebookId = null;
        onClosed?.call();
      case 'show_failed':
        notifyShowFailed(event.message ?? 'Facebook ad failed to show.');
    }
  }

  Future<void> _clearFacebook() async {
    await _facebookSub?.cancel();
    _facebookSub = null;
    final id = _facebookId;
    _facebookId = null;
    if (id != null) {
      await FacebookBridge.dispose(id: id);
    }
  }
}
