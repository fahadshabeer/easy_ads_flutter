import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_ads_sdk/src/ad_format.dart';
import 'package:easy_ads_sdk/src/ad_network.dart';
import 'package:easy_ads_sdk/src/internal/ad_ids.dart';
import 'package:easy_ads_sdk/src/internal/load_order.dart';
import 'package:easy_ads_sdk/src/test_ids.dart';

void main() {
  test('requests go to AdMob', () {
    expect(resolveLoadOrder(), [EasyAdNetwork.admob]);
  });

  test('test mode replaces the AdMob unit with the demo unit', () {
    expect(
      resolveAdmobAdUnitId(
        adUnitId: 'ca-app-pub-real/banner',
        format: EasyAdFormat.banner,
        testMode: true,
        platform: TargetPlatform.android,
      ),
      EasyTestIds.admob(EasyAdFormat.banner, platform: TargetPlatform.android),
    );
  });

  test('production mode keeps the AdMob unit', () {
    expect(
      resolveAdmobAdUnitId(
        adUnitId: ' ca-app-pub-real/banner ',
        format: EasyAdFormat.banner,
        testMode: false,
        platform: TargetPlatform.iOS,
      ),
      'ca-app-pub-real/banner',
    );
  });
}
