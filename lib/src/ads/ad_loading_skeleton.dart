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
    return Semantics(
      label: 'Advertisement loading',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F3F5),
            border: Border.all(color: const Color(0xFFE3E5E8)),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: _shimmerBody()),
              const Positioned(top: 4, left: 4, child: _AdMark()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBody() {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final travel = bounds.width * 1.6;
            final dx = (_shimmer.value * travel * 2) - travel;
            return LinearGradient(
              colors: const [
                _bone,
                Color(0xFFF7F8F9),
                _bone,
              ],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: _layout(),
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

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

class _AdMark extends StatelessWidget {
  const _AdMark();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          'Ad',
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Color(0xFFD32F2F),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({this.width, this.height, this.radius = 4, this.expand = false});

  final double? width;
  final double? height;
  final double radius;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: _AdLoadingSkeletonState._bone,
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
            child: _Bone(width: 88, height: 26, radius: 6),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _Bone(width: 32, height: 32, radius: 4),
          SizedBox(width: 10),
          Expanded(child: _Lines(secondWidth: 0.55)),
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
            child: _Bone(expand: true, radius: 6),
          ),
          SizedBox(width: 10),
          Expanded(child: _Lines(secondWidth: 0.62, button: true)),
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
          Expanded(child: _Bone(expand: true, radius: 6)),
          SizedBox(height: 10),
          _Bone(height: 10),
          SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: _Bone(height: 10),
            ),
          ),
          SizedBox(height: 10),
          _Bone(height: 32, radius: 6),
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
                _Bone(width: 40, height: 40, radius: 8),
                SizedBox(width: 10),
                Expanded(child: _Lines(secondWidth: 0.42)),
              ],
            ),
          ),
          SizedBox(height: 10),
          Expanded(child: _Bone(expand: true, radius: 6)),
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
          _Bone(height: 36, radius: 8),
        ],
      ),
    );
  }
}
