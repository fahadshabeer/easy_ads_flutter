import 'package:easy_ads_sdk/src/ads/ad_loading_skeleton.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom loading widget fills the ad box until the ad arrives', (
    tester,
  ) async {
    await tester.pumpWidget(
      _slot(
        const AdLoadingSlot(
          height: 50,
          failed: false,
          ad: null,
          loading: Text('Mine'),
          fallback: Text('Default'),
        ),
      ),
    );

    expect(find.text('Mine'), findsOneWidget);
    expect(find.text('Default'), findsNothing);
    expect(tester.getSize(find.byType(AdLoadingSlot)).height, 50);
  });

  testWidgets('omitted loading widget keeps the built-in skeleton', (
    tester,
  ) async {
    await tester.pumpWidget(
      _slot(
        const AdLoadingSlot(
          height: 250,
          failed: false,
          ad: null,
          loading: null,
          fallback: Text('Default'),
        ),
      ),
    );

    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('a loaded ad replaces the custom placeholder', (tester) async {
    await tester.pumpWidget(
      _slot(
        const AdLoadingSlot(
          height: 320,
          failed: false,
          ad: Text('Filled'),
          loading: Text('Mine'),
          fallback: Text('Default'),
        ),
      ),
    );

    expect(find.text('Filled'), findsOneWidget);
    expect(find.text('Mine'), findsNothing);
    expect(tester.getSize(find.byType(AdLoadingSlot)).height, 320);
  });

  testWidgets('a failed load removes the placeholder', (tester) async {
    await tester.pumpWidget(
      _slot(
        const AdLoadingSlot(
          height: 50,
          failed: true,
          ad: null,
          loading: Text('Mine'),
          fallback: Text('Default'),
        ),
      ),
    );

    expect(find.text('Mine'), findsNothing);
    expect(tester.getSize(find.byType(AdLoadingSlot)), Size.zero);
  });

  testWidgets('skeletons keep the ad box and show a red Ad mark', (tester) async {
    await _expectSkeleton(tester, AdSkeletonKind.banner, 360, 50);
    await _expectSkeleton(tester, AdSkeletonKind.largeBanner, 360, 100);
    await _expectSkeleton(tester, AdSkeletonKind.largeBanner, 360, 90);
    await _expectSkeleton(tester, AdSkeletonKind.mediumRectangle, 300, 250);
    await _expectSkeleton(tester, AdSkeletonKind.native, 360, 320);
    await _expectSkeleton(tester, AdSkeletonKind.native, 360, 400);
  });
}

Widget _slot(AdLoadingSlot slot) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(alignment: Alignment.topCenter, child: slot),
  );
}

Future<void> _expectSkeleton(
  WidgetTester tester,
  AdSkeletonKind kind,
  double width,
  double height,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: AdLoadingSkeleton(kind: kind),
        ),
      ),
    ),
  );

  expect(find.text('Ad'), findsOneWidget);
  expect(tester.getSize(find.byType(AdLoadingSkeleton)), Size(width, height));
  expect(tester.takeException(), isNull);
}
