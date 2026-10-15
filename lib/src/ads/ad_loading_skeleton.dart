import 'package:flutter/widgets.dart';

/// The box a banner or native ad occupies while it loads and after it fills.
///
/// [loading] replaces [fallback] when the app supplies its own shimmer.
/// [ad] replaces both once a network fills. A failed load collapses the box.
class AdLoadingSlot extends StatelessWidget {
  /// Creates the shared ad box.
  const AdLoadingSlot({
    super.key,
    required this.height,
    required this.failed,
    required this.ad,
    required this.loading,
    required this.fallback,
  });

  /// Height of the ad format. The loaded ad uses this same height.
  final double height;

  /// Whether every network failed. The box then takes no space.
  final bool failed;

  /// The loaded ad view, when a network has filled.
  final Widget? ad;

  /// App-supplied shimmer or placeholder. Null keeps [fallback].
  final Widget? loading;

  /// Built-in skeleton used when [loading] is omitted.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ad ?? loading ?? fallback,
    );
  }
}

/// Which ad shape the loading skeleton should imitate.
enum AdSkeletonKind {
  /// Standard 50-tall banner.
  banner,

  /// Taller banner, 90 or 100.
  largeBanner,

  /// 300x250 rectangle.
  mediumRectangle,

  /// Native template: icon, text, media, and a call-to-action.
  native,
}

/// Gray stand-in shown in the ad's own box until that ad fills.
///
/// The red Ad mark stays in the corner. The loaded ad replaces this
/// widget without changing the box size.
class AdLoadingSkeleton extends StatefulWidget {
  /// Creates a skeleton for [kind].
  const AdLoadingSkeleton({super.key, required this.kind});

  /// Layout to imitate.
  final AdSkeletonKind kind;

  @override
  State<AdLoadingSkeleton> createState() => _AdLoadingSkeletonState();
}

class _AdLoadingSkeletonState extends State<AdLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  static const _bone = Color(0xFFD5D8DC);

  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.kind == AdSkeletonKind.banner;
    return Semantics(
      label: 'Advertisement loading',
      container: true,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 2 : 8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFF4F5F7),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFFE1E4E8)),
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Stack(
                    children: [
                      _layout(),
                      Positioned.fill(child: _shimmerWash()),
                    ],
                  ),
                ),
                _badge(compact),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(bool compact) {
    final mark = _AdMark(compact: compact);
    if (compact) {
      return Positioned(
        left: 6,
        top: 0,
        bottom: 0,
        child: Center(child: mark),
      );
    }
    if (widget.kind == AdSkeletonKind.native) {
      return Positioned(top: 20, left: 12, child: mark);
    }
    return Positioned(top: 8, left: 8, child: mark);
  }

  /// A light band moves across the bones. The bones keep their shape.
  Widget _shimmerWash() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final t = _shimmer.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.4 + (t * 2.8), -0.15),
              end: Alignment(-0.7 + (t * 2.8), 0.15),
              colors: const [
                Color(0x00FFFFFF),
                Color(0xB3FFFFFF),
                Color(0x00FFFFFF),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _layout() {
    return switch (widget.kind) {
      AdSkeletonKind.banner => const _BannerBody(),
      AdSkeletonKind.largeBanner => const _LargeBannerBody(),
      AdSkeletonKind.mediumRectangle => const _RectangleBody(),
      AdSkeletonKind.native => const _NativeBody(),
    };
  }
}

class _AdMark extends StatelessWidget {
  const _AdMark({required this.compact});

  /// Smaller label for the 50-tall banner, where a large badge would cover the row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.all(Radius.circular(2)),
        border: Border.all(color: const Color(0xFFD32F2F)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 3 : 4,
          vertical: compact ? 0 : 1,
        ),
        child: Text(
          'Ad',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: const Color(0xFFD32F2F),
            fontSize: compact ? 9 : 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({
    this.width,
    this.height,
    this.radius = 4,
    this.expand = false,
    this.media = false,
    this.button = false,
  });

  final double? width;
  final double? height;
  final double radius;
  final bool expand;

  /// Darker block, used where the ad shows an image.
  final bool media;

  /// Darker block, used where the ad shows a call-to-action.
  final bool button;

  @override
  Widget build(BuildContext context) {
    final color = button
        ? const Color(0xFFC5CAD1)
        : media
        ? const Color(0xFFD5D9DE)
        : _AdLoadingSkeletonState._bone;
    final decoration = BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    );
    if (expand) {
      return DecoratedBox(
        decoration: decoration,
        child: const SizedBox.expand(),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(decoration: decoration),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.secondWidth, this.button = false});

  final double secondWidth;
  final bool button;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Bone(height: 8),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: secondWidth,
            child: const _Bone(height: 8),
          ),
        ),
        if (button) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: _Bone(width: 96, height: 26, radius: 6, button: true),
          ),
        ],
      ],
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 34, right: 10),
      child: Row(
        children: [
          _Bone(width: 32, height: 32, radius: 4, media: true),
          SizedBox(width: 8),
          Expanded(child: _Lines(secondWidth: 0.62)),
        ],
      ),
    );
  }
}

class _LargeBannerBody extends StatelessWidget {
  const _LargeBannerBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _Bone(expand: true, radius: 6, media: true),
          ),
          SizedBox(width: 10),
          Expanded(child: _Lines(secondWidth: 0.7, button: true)),
        ],
      ),
    );
  }
}

class _RectangleBody extends StatelessWidget {
  const _RectangleBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Bone(expand: true, radius: 6, media: true)),
          SizedBox(height: 10),
          _Bone(height: 10),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.72,
              child: _Bone(height: 8),
            ),
          ),
          SizedBox(height: 10),
          _Bone(height: 32, radius: 6, button: true),
        ],
      ),
    );
  }
}

class _NativeBody extends StatelessWidget {
  const _NativeBody();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                SizedBox(width: 30),
                _Bone(width: 40, height: 40, radius: 8, media: true),
                SizedBox(width: 10),
                Expanded(child: _Lines(secondWidth: 0.42)),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(child: _Bone(expand: true, radius: 6, media: true)),
          SizedBox(height: 10),
          _Bone(height: 8),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: _Bone(height: 8),
            ),
          ),
          SizedBox(height: 10),
          _Bone(height: 36, radius: 8, button: true),
        ],
      ),
    );
  }
}
