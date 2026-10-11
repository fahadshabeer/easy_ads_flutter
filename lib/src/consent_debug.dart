/// Geography forced by [EasyConsentDebug] on a test device.
///
/// Production builds must not pass this. Real users are classified by
/// Google's consent SDK.
enum EasyConsentDebugGeography {
  /// Treat the test device as being in the EEA, the UK, or Switzerland.
  eea,

  /// Treat the test device as being outside regulated regions.
  other,

  /// Treat the test device as being in a regulated US state.
  regulatedUsState,
}

/// Forces the European consent form on a test device.
///
/// Google only enables these overrides for the hashed device ids you pass.
/// The debug log prints that id the first time consent runs.
class EasyConsentDebug {
  /// Creates debug consent settings.
  const EasyConsentDebug({
    this.geography = EasyConsentDebugGeography.eea,
    this.testDeviceIds = const [],
  });

  /// Region the test device should appear to be in.
  final EasyConsentDebugGeography geography;

  /// Hashed device ids from the consent debug log.
  final List<String> testDeviceIds;
}
