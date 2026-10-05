import 'ad_network.dart';

/// One network's failure inside a load attempt.
class EasyAdFailure {
  /// Creates a failure record.
  const EasyAdFailure({
    required this.network,
    required this.message,
    this.code,
  });

  /// The network that failed.
  final EasyAdNetwork network;

  /// The message returned by that network.
  final String message;

  /// The network error code, when the SDK provided one.
  final int? code;

  @override
  String toString() {
    final codeText = code == null ? '' : ' ($code)';
    return '${network.name}$codeText: $message';
  }
}

/// The error delivered to [onError] after every available network has failed,
/// or when the ad cannot be shown.
class EasyAdError implements Exception {
  /// Creates an error.
  const EasyAdError({
    required this.message,
    this.failures = const [],
  });

  /// A single message. When [failures] is not empty, this summarizes them.
  final String message;

  /// Per-network failures, in the order the SDK tried them.
  final List<EasyAdFailure> failures;

  @override
  String toString() {
    if (failures.isEmpty) {
      return 'EasyAdError: $message';
    }
    return 'EasyAdError: ${failures.join(' | ')}';
  }
}
