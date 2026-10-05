import 'ad_network.dart';

/// The reward earned from a rewarded ad or a rewarded interstitial.
class EasyReward {
  /// Creates a reward.
  const EasyReward({
    required this.amount,
    required this.type,
    required this.network,
  });

  /// How much of [type] the user earned.
  final int amount;

  /// The reward name. AdMob uses the name configured on the ad unit.
  /// Facebook reports `reward` when the video completes.
  final String type;

  /// The network that granted the reward.
  final EasyAdNetwork network;

  @override
  String toString() => 'EasyReward($amount $type from ${network.name})';
}
