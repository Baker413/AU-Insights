import 'package:flutter_test/flutter_test.dart';

import 'package:au_insights/services/shared_plan_loader.dart';

void main() {
  group('SharedRiskSnapshot drawdown parsing', () {
    test('drawdownPercent (legacy) wins when both legacy + contract are present', () {
      final snap = SharedRiskSnapshot.fromJson(<String, dynamic>{
        'drawdownPercent': 12.0, // percent units 0..100
        'drawdownPct': 0.34, // fraction units 0..1 (would be 34.0%)
      });

      expect(snap.drawdownPercent, 12.0);
    });

    test('drawdownPct (contract fraction) converts to percent when legacy missing', () {
      final snap = SharedRiskSnapshot.fromJson(<String, dynamic>{
        'drawdownPct': 0.12,
      });

      expect(snap.drawdownPercent, closeTo(12.0, 1e-9));
    });

    test('null when neither legacy nor contract drawdown field is present', () {
      final snap = SharedRiskSnapshot.fromJson(<String, dynamic>{});
      expect(snap.drawdownPercent, isNull);
    });
  });
}
