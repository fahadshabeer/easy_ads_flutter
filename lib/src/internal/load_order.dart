import '../ad_network.dart';

/// Networks this package requests directly.
///
/// Meta inventory is not requested here. It competes inside the AdMob
/// auction when Meta Audience Network is a bidding source on the ad unit.
List<EasyAdNetwork> resolveLoadOrder() => const [EasyAdNetwork.admob];
