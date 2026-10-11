import 'package:easy_ads_sdk/src/internal/waterfall.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ad requests wait for initialization and consent', () {
    final beforeInit = adRequestBlock(
      initialized: false,
      canRequestAds: false,
    );
    expect(beforeInit?.message, contains('initialize'));

    final refused = adRequestBlock(
      initialized: true,
      canRequestAds: false,
    );
    expect(refused?.message, contains('consent'));

    expect(
      adRequestBlock(initialized: true, canRequestAds: true),
      isNull,
    );
  });
}
