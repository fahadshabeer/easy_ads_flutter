import '../ad_network.dart';
import '../ad_priority.dart';

/// Networks to try, first to last.
///
/// Facebook is omitted when it was not initialized, or when this placement
/// has no Facebook placement id.
List<EasyAdNetwork> resolveLoadOrder({
  required EasyAdPriority priority,
  required bool facebookEnabled,
  required String? facebookPlacementId,
}) {
  final placement = facebookPlacementId?.trim() ?? '';
  final facebookAvailable = facebookEnabled && placement.isNotEmpty;
  if (!facebookAvailable) {
    return const [EasyAdNetwork.admob];
  }
  if (priority == EasyAdPriority.facebook) {
    return const [EasyAdNetwork.facebook, EasyAdNetwork.admob];
  }
  return const [EasyAdNetwork.admob, EasyAdNetwork.facebook];
}
