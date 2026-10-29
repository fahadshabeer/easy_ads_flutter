import 'package:flutter/foundation.dart';

import '../ad_format.dart';
import '../test_ids.dart';

/// Ad unit id to send to AdMob.
///
/// In test mode this is always a Google demo ad unit, so development clicks
/// cannot count as invalid traffic.
String resolveAdmobAdUnitId({
  required String adUnitId,
  required EasyAdFormat format,
  required bool testMode,
  TargetPlatform? platform,
}) {
  final trimmed = adUnitId.trim();
  if (!testMode) {
    return trimmed;
  }
  return EasyTestIds.admob(format, platform: platform);
}
