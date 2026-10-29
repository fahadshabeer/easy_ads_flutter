import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../banner_size.dart';
import '../easy_ads.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import 'ad_loading_skeleton.dart';

/// A banner that loads through AdMob.
///
/// Meta can fill this request when Meta Audience Network is a bidding
/// source on the ad unit. The widget loads itself. [onLoading] runs once.
/// [onLoaded] runs when AdMob returns an ad. [onError] runs when it does not.
class EasyBannerAd extends StatefulWidget {
  /// Creates a banner.
  const EasyBannerAd({
    super.key,
    required this.admobAdUnitId,
    this.size = EasyBannerSize.banner,
    this.loading,
    this.onLoading,
    this.onLoaded,
    this.onError,
  });

  /// AdMob banner ad unit id. Required.
  final String admobAdUnitId;

  /// Banner size. The default is the standard 50pt banner.
  final EasyBannerSize size;

  /// Shimmer or other placeholder shown until the banner fills.
  ///
  /// It is laid out in the banner's own box and removed when the ad
  /// loads. Omit it to use the built-in skeleton.
  final Widget? loading;

  /// Called once, when the request starts.
  final VoidCallback? onLoading;

  /// Called when AdMob returns a banner.
  final void Function(EasyAdNetwork network)? onLoaded;

  /// Called when the banner cannot be shown.
  final void Function(EasyAdError error)? onError;

  @override
  State<EasyBannerAd> createState() => _EasyBannerAdState();
}

class _EasyBannerAdState extends State<EasyBannerAd> {
  int _generation = 0;
  bool _failed = false;
  BannerAd? _admobAd;
  Widget? _adView;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EasyBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.admobAdUnitId != widget.admobAdUnitId ||
        oldWidget.size != widget.size) {
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    final ad = _admobAd;
    _admobAd = null;
    _adView = null;
    ad?.dispose();
    super.dispose();
  }

  double get _height {
    return switch (widget.size) {
      EasyBannerSize.banner => 50,
      EasyBannerSize.large => 100,
      EasyBannerSize.mediumRectangle => 250,
    };
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
    setState(() => _failed = false);
    _notify(() => widget.onLoaded?.call(network));
  }

  Future<LoadAttempt> _loadNetwork(EasyAdNetwork network) {
    return _loadAdmob();
  }

  Future<LoadAttempt> _loadAdmob() {
    final completer = Completer<LoadAttempt>();
    final ad = BannerAd(
      adUnitId: resolveAdmobAdUnitId(
        adUnitId: widget.admobAdUnitId,
        format: EasyAdFormat.banner,
        testMode: EasyAds.testMode,
      ),
      size: _admobSize(widget.size),
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          _admobAd = loaded as BannerAd;
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
    final ad = _admobAd;
    _admobAd = null;
    _adView = null;
    ad?.dispose();
  }

  void _releaseCurrent() {
    final ad = _admobAd;
    _admobAd = null;
    _adView = null;
    _failed = false;
    ad?.dispose();
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
      height: _height,
      failed: _failed,
      ad: _adView,
      loading: widget.loading,
      fallback: AdLoadingSkeleton(
        kind: switch (widget.size) {
          EasyBannerSize.banner => AdSkeletonKind.banner,
          EasyBannerSize.large => AdSkeletonKind.largeBanner,
          EasyBannerSize.mediumRectangle => AdSkeletonKind.mediumRectangle,
        },
      ),
    );
  }
}

AdSize _admobSize(EasyBannerSize size) {
  return switch (size) {
    EasyBannerSize.banner => AdSize.banner,
    EasyBannerSize.large => AdSize.largeBanner,
    EasyBannerSize.mediumRectangle => AdSize.mediumRectangle,
  };
}
