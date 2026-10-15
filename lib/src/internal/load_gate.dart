/// Decides which load callback is allowed to run.
///
/// A timeout and a load result are mutually exclusive. After either one
/// wins, the other stays silent.
class AdLoadGate {
  bool _closed = false;
  bool _timedOut = false;

  /// Whether this load already timed out.
  bool get timedOut => _timedOut;

  /// Returns true when [onTimeout] should run.
  bool claimTimeout() {
    if (_closed) {
      return false;
    }
    _closed = true;
    _timedOut = true;
    return true;
  }

  /// Returns true when [onLoaded] or [onError] should run.
  bool claimResult() {
    if (_closed) {
      return false;
    }
    _closed = true;
    return true;
  }

  /// Blocks every later callback. Used when the ad is disposed.
  void close() {
    _closed = true;
  }
}
