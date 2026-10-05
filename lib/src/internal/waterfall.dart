import '../ad_error.dart';
import '../ad_network.dart';
import '../easy_ads.dart';
import 'load_order.dart';

/// The outcome of asking one network for an ad.
class LoadAttempt {
  const LoadAttempt.filled() : failure = null;

  const LoadAttempt.failed(this.failure);

  /// Set when this network did not fill.
  final EasyAdFailure? failure;

  /// Whether this network returned an ad.
  bool get filled => failure == null;
}

/// Asks each network in priority order and stops at the first fill.
Future<EasyAdNetwork?> runWaterfall({
  required String? facebookPlacementId,
  required bool Function() isCancelled,
  required Future<LoadAttempt> Function(EasyAdNetwork network) load,
  required Future<void> Function(EasyAdNetwork network) discard,
  required List<EasyAdFailure> failures,
}) async {
  final order = resolveLoadOrder(
    priority: EasyAds.priority,
    facebookEnabled: EasyAds.isFacebookEnabled,
    facebookPlacementId: facebookPlacementId,
  );

  for (final network in order) {
    if (isCancelled()) {
      return null;
    }
    final attempt = await load(network);
    if (isCancelled()) {
      if (attempt.filled) {
        await discard(network);
      }
      return null;
    }
    if (attempt.filled) {
      return network;
    }
    final failure = attempt.failure;
    if (failure != null) {
      failures.add(failure);
    }
  }
  return null;
}

/// Error used when [EasyAds.initialize] has not finished.
EasyAdError notInitializedError() {
  return const EasyAdError(
    message:
        'Call EasyAds.initialize() before loading ads. '
        'Wait for it to finish.',
  );
}

/// Error used when every network in the waterfall failed.
EasyAdError noFillError(List<EasyAdFailure> failures) {
  if (failures.isEmpty) {
    return const EasyAdError(message: 'No ad filled.');
  }
  return EasyAdError(
    message: failures.join(' | '),
    failures: List<EasyAdFailure>.unmodifiable(failures),
  );
}
