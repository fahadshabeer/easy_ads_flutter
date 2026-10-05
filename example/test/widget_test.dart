import 'package:flutter_test/flutter_test.dart';
import 'package:easy_ads_sdk_example/main.dart';

void main() {
  testWidgets('example screen shows the Easy Ads title', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Easy Ads'), findsOneWidget);
    expect(find.text('Load interstitial'), findsOneWidget);
  });
}
