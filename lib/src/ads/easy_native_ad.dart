import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import 'ad_loading_skeleton.dart';

/// A native ad that uses AdMob's medium template.
///
/// Meta can fill this request when Meta Audience Network is a bidding
/// source on the ad unit. This version does not take colors or a custom layout.
class EasyNativeAd extends StatefulWidget {
  /// Creates a native ad.
  const EasyNativeAd({
    super.key,
    required this.admobAdUnitId,
    this.height = 320,
    this.loading,
    this.onLoading,
    this.onLoaded,
    this.onError,
  });

  /// AdMob native ad unit id. Required.
  final String admobAdUnitId;

  /// Height of the template. The default is 320.
  final double height;

  /// Shimmer or other placeholder shown until the native ad fills.
  ///
  /// It is laid out in the same box as the ad and removed when the ad
  /// loads. Omit it to use the built-in skeleton.
  final Widget? loading;

  /// Called once, when the request starts.
  final VoidCallback? onLoading;

  /// Called when AdMob returns a native ad.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EasyNativeAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.admobAdUnitId != widget.admobAdUnitId) {
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    final ad = _admobAd;
    _admobAd = null;
    ad?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _releaseCurrent();
    if (!mounted || generation != _generation) {
      return;
    }
    setState(() {});

    final blocked = await EasyAds.prepareRequest();
    if (!mounted || generation != _generation) {
      return;
    }
    if (blocked != null) {
      _fail(generation, blocked);
      return;
    }

    _notify(widget.onLoading);
    final failures = <EasyAdFailure>[];
    final network = await runWaterfall(
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
    return _loadAdmob();
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

  Future<void> _discard(EasyAdNetwork network) async {
    _disposeAdmob();
  }

  void _disposeAdmob() {
    final ad = _admobAd;
    _admobAd = null;
    _adView = null;
    ad?.dispose();
  }

  void _releaseCurrent() {
    _disposeAdmob();
    _failed = false;
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
