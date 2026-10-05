import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:easy_ads_sdk/easy_ads_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdMob initializes', (tester) async {
    await EasyAds.initialize(testMode: true);
    expect(EasyAds.isInitialized, isTrue);
  });
}
