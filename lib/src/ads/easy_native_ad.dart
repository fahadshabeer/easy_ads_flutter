import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import '../facebook/facebook_bridge.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import 'ad_loading_skeleton.dart';
import 'facebook_platform_view.dart';

/// A native ad that uses AdMob's medium template, or Facebook's built-in
/// template, whichever network fills first.
///
/// This version does not take colors or a custom layout.
class EasyNativeAd extends StatefulWidget {
  /// Creates a native ad.
  const EasyNativeAd({
    super.key,
    required this.admobAdUnitId,
    this.facebookPlacementId,
    this.height = 320,
    this.loading,
    this.onLoading,
    this.onLoaded,
    this.onError,
  });

  /// AdMob native ad unit id. Required.
  final String admobAdUnitId;

  /// Facebook native placement id. Omit it to use AdMob only.
  final String? facebookPlacementId;

  /// Height of the template. Facebook needs at least 250 to count an
  /// impression, so the default is 320.
  final double height;

  /// Shimmer or other placeholder shown until the native ad fills.
  ///
  /// It is laid out in the same box as the ad and removed when the ad
  /// loads. Omit it to use the built-in skeleton.
  final Widget? loading;

  /// Called once, when the first request starts.
  final VoidCallback? onLoading;

  /// Called with the network that filled the ad.
  final void Function(EasyAdNetwork network)? onLoaded;

  /// Called when the ad cannot be shown.
  final void Function(EasyAdError error)? onError;

  @override
  State<EasyNativeAd> createState() => _EasyNativeAdState();
}

class _EasyNativeAdState extends State<EasyNativeAd> {
  int _generation = 0;
  bool _failed = false;
  NativeAd? _admobAd;
  Widget? _adView;
  String? _facebookId;
  StreamSubscription<FacebookEvent>? _facebookSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EasyNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.admobAdUnitId != widget.admobAdUnitId ||
        oldWidget.facebookPlacementId != widget.facebookPlacementId) {
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    final ad = _admobAd;
    _admobAd = null;
    ad?.dispose();
    final id = _facebookId;
    _facebookId = null;
    _facebookSub?.cancel();
    _facebookSub = null;
    if (id != null) {
      FacebookBridge.dispose(id: id);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    await _releaseCurrent();
    if (!mounted || generation != _generation) {
      return;
    }
    if (!EasyAds.isInitialized) {
      _fail(generation, notInitializedError());
      return;
    }

    setState(() {});
    _notify(widget.onLoading);
    final failures = <EasyAdFailure>[];
    final network = await runWaterfall(
      facebookPlacementId: widget.facebookPlacementId,
      isCancelled: () => !mounted || generation != _generation,
      failures: failures,
      load: _loadNetwork,
      discard: _discard,
    );
    if (!mounted || generation != _generation) {
      return;
    }
    if (network == null) {
      _fail(generation, noFillError(failures));
      return;
    }
    setState(() {});
    _notify(() => widget.onLoaded?.call(network));
  }

  Future<LoadAttempt> _loadNetwork(EasyAdNetwork network) {
    return switch (network) {
      EasyAdNetwork.admob => _loadAdmob(),
      EasyAdNetwork.facebook => _loadFacebook(),
    };
  }

  Future<LoadAttempt> _loadAdmob() {
    final completer = Completer<LoadAttempt>();
    final ad = NativeAd(
      adUnitId: resolveAdmobAdUnitId(
        adUnitId: widget.admobAdUnitId,
        format: EasyAdFormat.native,
        testMode: EasyAds.testMode,
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
      ),
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          _admobAd = loaded as NativeAd;
          _adView = AdWidget(ad: loaded);
          if (!completer.isCompleted) {
            completer.complete(const LoadAttempt.filled());
          }
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          if (identical(_admobAd, failed)) {
            _admobAd = null;
          }
          if (!completer.isCompleted) {
            completer.complete(
              LoadAttempt.failed(
                EasyAdFailure(
                  network: EasyAdNetwork.admob,
                  message: error.message,
                  code: error.code,
                ),
              ),
            );
          }
        },
      ),
    );
    _admobAd = ad;
    ad.load();
    return completer.future;
  }

  Future<LoadAttempt> _loadFacebook() async {
    final placementId = resolveFacebookPlacementId(
      placementId: widget.facebookPlacementId,
      format: EasyAdFormat.native,
      testMode: EasyAds.testMode,
    );
    if (placementId == null) {
      return const LoadAttempt.failed(
        EasyAdFailure(
          network: EasyAdNetwork.facebook,
          message: 'Facebook placement id is missing.',
        ),
      );
    }
    final id = FacebookBridge.newId('native');
    _facebookId = id;
    await _facebookSub?.cancel();
    _facebookSub = FacebookBridge.listen(id, (_) {});
    try {
      await FacebookBridge.loadNative(id: id, placementId: placementId);
      _adView = FacebookPlatformView(
        viewType: 'easy_ads_sdk/facebook_native',
        id: id,
      );
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

  Future<void> _discard(EasyAdNetwork network) async {
    switch (network) {
      case EasyAdNetwork.admob:
        _disposeAdmob();
      case EasyAdNetwork.facebook:
        await _clearFacebook();
        _adView = null;
    }
  }

  void _disposeAdmob() {
    final ad = _admobAd;
    _admobAd = null;
    _adView = null;
    ad?.dispose();
  }

  Future<void> _releaseCurrent() async {
    _disposeAdmob();
    _failed = false;
    await _clearFacebook();
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

  void _fail(int generation, EasyAdError error) {
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() => _failed = true);
    _notify(() => widget.onError?.call(error));
  }

  void _notify(VoidCallback? callback) {
    if (callback == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdLoadingSlot(
      height: widget.height,
      failed: _failed,
      ad: _adView,
      loading: widget.loading,
      fallback: const AdLoadingSkeleton(kind: AdSkeletonKind.native),
    );
  }
}
