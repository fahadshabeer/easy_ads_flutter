/// Ad formats this SDK loads.
enum EasyAdFormat {
  /// A rectangular banner.
  banner,

  /// A full-screen ad at a natural break.
  interstitial,

  /// A full-screen ad that grants a reward when completed.
  rewarded,

  /// A full-screen ad shown at a transition that grants a reward.
  rewardedInterstitial,

  /// An in-content ad that uses the network's built-in template.
  native,
}
