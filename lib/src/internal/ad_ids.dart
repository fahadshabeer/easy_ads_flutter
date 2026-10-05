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

/// Placement id to send to Facebook.
///
/// Returns null when Facebook should be skipped for this placement.
/// In test mode, a real placement id is prefixed with a Meta test creative
/// so the request returns a test ad.
String? resolveFacebookPlacementId({
  required String? placementId,
  required EasyAdFormat format,
  required bool testMode,
}) {
  final trimmed = placementId?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  if (!testMode || trimmed.contains('#')) {
    return trimmed;
  }
  final prefix = format == EasyAdFormat.rewarded
      ? 'VID_HD_16_9_46S_APP_INSTALL'
      : 'IMG_16_9_APP_INSTALL';
  return '$prefix#$trimmed';
}
