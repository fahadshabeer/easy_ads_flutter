import 'package:flutter_test/flutter_test.dart';
import 'package:easy_ads_sdk_example/main.dart';

void main() {
  testWidgets('example screen shows the Easy Ads title', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Easy Ads'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Load interstitial'),
      200,
    );
    expect(find.text('Load interstitial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
