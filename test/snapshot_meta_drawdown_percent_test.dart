import 'package:flutter_test/flutter_test.dart';

import 'package:au_insights/services/shared_plan_loader.dart';

double? drawdownPercentFromSnapshotMetaRaw(Map<String, Object?>? raw) {
  if (raw == null || raw.isEmpty) return null;

  double? toFiniteDoubleOrNull(Object? v) {
    if (v == null) return null;
    if (v is num) {
      final d = v.toDouble();
      return d.isFinite ? d : null;
    }
    if (v is String) {
      final d = double.tryParse(v);
      return (d != null && d.isFinite) ? d : null;
    }
    return null;
  }

  double? fraction = toFiniteDoubleOrNull(raw['drawdownPct']);

  if (fraction == null) {
    final nested = raw['drawdownTruthV1'];
    if (nested is Map) {
      fraction = toFiniteDoubleOrNull(nested['drawdownPct']);
    }
  }

  if (fraction == null || fraction < 0.0 || fraction > 0.95) return null;
  return fraction * 100.0;
}

void main() {
  group('snapshotMeta drawdown truth', () {
    test('direct drawdownPct converts fraction to percent', () {
      final summary = SharedPlanSummary(
        exists: true,
        orderCount: 1,
        snapshotMetaRaw: <String, Object?>{'drawdownPct': 0.12},
      );

      expect(
        drawdownPercentFromSnapshotMetaRaw(summary.snapshotMetaRaw),
        closeTo(12.0, 1e-9),
      );
    });

    test('nested drawdownTruthV1.drawdownPct converts fraction to percent', () {
      final summary = SharedPlanSummary(
        exists: true,
        orderCount: 1,
        snapshotMetaRaw: <String, Object?>{
          'drawdownTruthV1': <String, Object?>{'drawdownPct': 0.10},
        },
      );

      expect(
        drawdownPercentFromSnapshotMetaRaw(summary.snapshotMetaRaw),
        closeTo(10.0, 1e-9),
      );
    });

    test('invalid drawdown fraction returns null', () {
      final summary = SharedPlanSummary(
        exists: true,
        orderCount: 1,
        snapshotMetaRaw: <String, Object?>{'drawdownPct': 1.20},
      );

      expect(drawdownPercentFromSnapshotMetaRaw(summary.snapshotMetaRaw), isNull);
    });
  });
}
