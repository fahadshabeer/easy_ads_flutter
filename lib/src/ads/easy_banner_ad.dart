import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../ad_error.dart';
import '../ad_format.dart';
import '../ad_network.dart';
import '../banner_size.dart';
import '../easy_ads.dart';
import '../facebook/facebook_bridge.dart';
import '../internal/ad_ids.dart';
import '../internal/waterfall.dart';
import 'facebook_platform_view.dart';

/// A banner that loads AdMob first or Facebook first, then falls back.
///
/// The widget loads itself. [onLoading] runs once. [onLoaded] runs when a
/// network fills. [onError] runs only when every available network fails.
class EasyBannerAd extends StatefulWidget {
  /// Creates a banner.
  const EasyBannerAd({
    super.key,
    required this.admobAdUnitId,
    this.facebookPlacementId,
    this.size = EasyBannerSize.banner,
    this.onLoading,
    this.onLoaded,
    this.onError,
  });

  /// AdMob banner ad unit id. Required.
  final String admobAdUnitId;

  /// Facebook banner placement id. Omit it to use AdMob only.
  final String? facebookPlacementId;

  /// Banner size. The default is the standard 50pt banner.
  final EasyBannerSize size;

  /// Called once, when the first request starts.
  final VoidCallback? onLoading;

  /// Called with the network that filled the banner.
  final void Function(EasyAdNetwork network)? onLoaded;

  /// Called when the banner cannot be shown.
  final void Function(EasyAdError error)? onError;

  @override
  State<EasyBannerAd> createState() => _EasyBannerAdState();
}

class _EasyBannerAdState extends State<EasyBannerAd> {
  int _generation = 0;
  bool _failed = false;
  EasyAdNetwork? _network;
  BannerAd? _admobAd;
  Widget? _adView;
  String? _facebookId;
  StreamSubscription<FacebookEvent>? _facebookSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EasyBannerAd oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.admobAdUnitId != widget.admobAdUnitId ||
        oldWidget.facebookPlacementId != widget.facebookPlacementId ||
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
    final id = _facebookId;
    _facebookId = null;
    _facebookSub?.cancel();
    _facebookSub = null;
    if (id != null) {
      FacebookBridge.dispose(id: id);
    }
    super.dispose();
  }

  double get _height {
    return switch (widget.size) {
      EasyBannerSize.banner => 50,
      EasyBannerSize.large => _network == EasyAdNetwork.facebook ? 90 : 100,
      EasyBannerSize.mediumRectangle => 250,
    };
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
    setState(() {
      _failed = false;
      _network = network;
    });
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

  Future<LoadAttempt> _loadFacebook() async {
    final placementId = resolveFacebookPlacementId(
      placementId: widget.facebookPlacementId,
      format: EasyAdFormat.banner,
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
    final id = FacebookBridge.newId('banner');
    _facebookId = id;
    await _facebookSub?.cancel();
    _facebookSub = FacebookBridge.listen(id, (_) {});
    try {
      await FacebookBridge.loadBanner(
        id: id,
        placementId: placementId,
        size: widget.size.name,
      );
      _adView = FacebookPlatformView(
        viewType: 'easy_ads_sdk/facebook_banner',
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
        final ad = _admobAd;
        _admobAd = null;
        _adView = null;
        ad?.dispose();
      case EasyAdNetwork.facebook:
        await _clearFacebook();
        _adView = null;
    }
  }

  Future<void> _releaseCurrent() async {
    final ad = _admobAd;
    _admobAd = null;
    _adView = null;
    _network = null;
    _failed = false;
    ad?.dispose();
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
    if (_failed) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: _height,
      child: _adView ?? const SizedBox.shrink(),
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
