import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_ads_sdk/src/ad_format.dart';
import 'package:easy_ads_sdk/src/ad_network.dart';
import 'package:easy_ads_sdk/src/ad_priority.dart';
import 'package:easy_ads_sdk/src/internal/ad_ids.dart';
import 'package:easy_ads_sdk/src/internal/load_order.dart';
import 'package:easy_ads_sdk/src/test_ids.dart';

void main() {
  test('AdMob is the only network when Facebook is off', () {
    expect(
      resolveLoadOrder(
        priority: EasyAdPriority.facebook,
        facebookEnabled: false,
        facebookPlacementId: '123_456',
      ),
      [EasyAdNetwork.admob],
    );
  });

  test('AdMob is the only network when the placement id is blank', () {
    expect(
      resolveLoadOrder(
        priority: EasyAdPriority.facebook,
        facebookEnabled: true,
        facebookPlacementId: '   ',
      ),
      [EasyAdNetwork.admob],
    );
  });

  test('AdMob priority tries AdMob first', () {
    expect(
      resolveLoadOrder(
        priority: EasyAdPriority.admob,
        facebookEnabled: true,
        facebookPlacementId: '123_456',
      ),
      [EasyAdNetwork.admob, EasyAdNetwork.facebook],
    );
  });

  test('Facebook priority tries Facebook first', () {
    expect(
      resolveLoadOrder(
        priority: EasyAdPriority.facebook,
        facebookEnabled: true,
        facebookPlacementId: '123_456',
      ),
      [EasyAdNetwork.facebook, EasyAdNetwork.admob],
    );
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

  test('test mode prefixes a Facebook placement once', () {
    expect(
      resolveFacebookPlacementId(
        placementId: '123_456',
        format: EasyAdFormat.banner,
        testMode: true,
      ),
      'IMG_16_9_APP_INSTALL#123_456',
    );
    expect(
      resolveFacebookPlacementId(
        placementId: '123_456',
        format: EasyAdFormat.rewarded,
        testMode: true,
      ),
      'VID_HD_16_9_46S_APP_INSTALL#123_456',
    );
  });

  test('an existing Facebook test prefix is left alone', () {
    expect(
      resolveFacebookPlacementId(
        placementId: 'IMG_16_9_APP_INSTALL#123_456',
        format: EasyAdFormat.banner,
        testMode: true,
      ),
      'IMG_16_9_APP_INSTALL#123_456',
    );
  });

  test('a missing Facebook placement stays missing', () {
    expect(
      resolveFacebookPlacementId(
        placementId: null,
        format: EasyAdFormat.native,
        testMode: true,
      ),
      isNull,
    );
  });
}
