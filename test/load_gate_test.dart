import 'package:easy_ads_sdk/src/internal/load_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timeout blocks a later load result', () {
    final gate = AdLoadGate();

    expect(gate.claimTimeout(), isTrue);
    expect(gate.claimResult(), isFalse);
    expect(gate.claimTimeout(), isFalse);
    expect(gate.timedOut, isTrue);
  });

  test('a load result blocks a later timeout', () {
    final gate = AdLoadGate();

    expect(gate.claimResult(), isTrue);
    expect(gate.claimTimeout(), isFalse);
    expect(gate.timedOut, isFalse);
  });

  test('dispose blocks both timeout and the load result', () {
    final gate = AdLoadGate();

    gate.close();
    expect(gate.claimTimeout(), isFalse);
    expect(gate.claimResult(), isFalse);
  });
}
