/// Which network is asked first.
///
/// The other network is requested only after the first one fails.
enum EasyAdPriority {
  /// Request AdMob first. Facebook is the fallback.
  admob,

  /// Request Facebook first. AdMob is the fallback.
  facebook,
}
