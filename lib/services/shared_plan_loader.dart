import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:au_core/au_core.dart';

import '../shared/storage.dart';
import '../models/shared_planned_order.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

List<String>? _normalizeAllowedSymbols(dynamic v) {
  if (v is! List) return null;
  final out = <String>[];
  for (final e in v) {
    final t = (e ?? '').toString().trim().toUpperCase();
    if (t.isNotEmpty) out.add(t);
  }
  final dedup = out.toSet().toList()..sort();
  return dedup.isNotEmpty ? dedup : null;
}

String _toString(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return v.toString();
}

class SharedRiskSnapshot {
  final double? maxInvestDollars;
  final double? currentInvestedDollars;
  final double? currentHedgeDollars;
  final double? maxPerSymbolDollars;
  final double? maxPerBlockRiskDollars;
  final double? drawdownPercent;

  const SharedRiskSnapshot({
    this.maxInvestDollars,
    this.currentInvestedDollars,
    this.currentHedgeDollars,
    this.maxPerSymbolDollars,
    this.maxPerBlockRiskDollars,
    this.drawdownPercent,
  });

  factory SharedRiskSnapshot.fromJson(Map<String, dynamic> json) {
    return SharedRiskSnapshot(
      maxInvestDollars: _toDouble(json['maxInvestDollars']),
      currentInvestedDollars: _toDouble(json['currentInvestedDollars']),
      currentHedgeDollars: _toDouble(json['currentHedgeDollars']),
      maxPerSymbolDollars: _toDouble(json['maxPerSymbolDollars']),
      maxPerBlockRiskDollars: _toDouble(json['maxPerBlockRiskDollars']),
      // Back-compat:
      // - legacy: drawdownPercent (percent units, e.g. 12.0)
      // - contract: drawdownPct (fraction units, e.g. 0.12) => convert to percent
      drawdownPercent: (() {
        final legacy = _toDouble(json['drawdownPercent']);
        if (legacy != null) return legacy;
        final pct = _toDouble(json['drawdownPct']);
        return pct != null ? (pct * 100.0) : null;
      })(),
    );
  }
}

class SharedSnapshotMeta {
  final String? accountLabel;
  final DateTime? asOf;
  final int? totalTrades;

  /// Canonical (preferred) long exposure dollars, producer-supplied.
  ///
  /// Preference order: `exposureDollars` (canonical) → `currentExposureDollars` (legacy).
  final double? currentExposureDollars;

  const SharedSnapshotMeta({
    this.accountLabel,
    this.asOf,
    this.totalTrades,
    this.currentExposureDollars,
  });

  factory SharedSnapshotMeta.fromJson(Map<String, dynamic> json) {
    DateTime? asOf;
    final asOfRaw = json['asOf'];
    if (asOfRaw is String) {
      asOf = DateTime.tryParse(asOfRaw);
    }

    int? totalTrades;
    final tt = json['totalTrades'];
    if (tt is int) {
      totalTrades = tt;
    } else if (tt is num) {
      totalTrades = tt.toInt();
    }

    final double? currentExposure =
        _toDouble(json['exposureDollars']) ??
        _toDouble(json['currentExposureDollars']);

    return SharedSnapshotMeta(
      accountLabel: json['accountLabel'] as String?,
      asOf: asOf,
      totalTrades: totalTrades,
      currentExposureDollars: currentExposure,
    );
  }
}

class SharedPosition {
  final String symbol;
  final double? netQuantity;
  final double? lastPrice;
  final double? avgEntryPrice;
  final double? costBasisDollars;

  const SharedPosition({
    required this.symbol,
    this.netQuantity,
    this.lastPrice,
    this.avgEntryPrice,
    this.costBasisDollars,
  });

  factory SharedPosition.fromJson(Map<String, dynamic> json) {
    return SharedPosition(
      symbol: _toString(json['symbol']).toUpperCase(),
      netQuantity: _toDouble(json['netQuantity']),
      lastPrice: _toDouble(json['lastPrice']),
      avgEntryPrice: _toDouble(json['avgEntryPrice']),
      costBasisDollars: _toDouble(json['costBasisDollars']),
    );
  }
}

class SharedBlock {
  final String blockId;
  final String symbol;
  final String direction;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final String? note;
  final String? origin;
  final int? lifecycleVersion;
  final double? maxBlockDollars;
  final double? initialRiskDollars;
  final double? ageDays;
  final String? regimeTag;
  final int plannedOrderCount;

  const SharedBlock({
    required this.blockId,
    required this.symbol,
    required this.direction,
    required this.status,
    this.createdAt,
    this.lastUpdatedAt,
    this.note,
    this.origin,
    this.lifecycleVersion,
    this.maxBlockDollars,
    this.initialRiskDollars,
    this.ageDays,
    this.regimeTag,
    this.plannedOrderCount = 0,
  });

  bool get isLegacy {
    final o = (origin ?? '').trim().toLowerCase();
    if (o == 'legacy') return true;
    final n = (note ?? '').toLowerCase();
    return n.contains('legacy');
  }

  factory SharedBlock.fromJson(Map<String, dynamic> json) {
    // Contract-first keys (au_core SharedPlanV3 blocksV1 lifecycle law v2):
    //   id, symbol, side, createdAt, status, nextAction
    //
    // Legacy synonyms (accepted for back-compat / drift tolerance):
    //   blockId -> id
    //   direction -> side
    //
    // AU Insights keeps UI-friendly fields (blockId/direction/status uppercased),
    // but parsing MUST accept canonical contract keys.
    final plannedOrders = json['plannedOrders'];
    int count = 0;
    if (plannedOrders is List) {
      count = plannedOrders.length;
    }

    final Object? idRaw = json['id'] ?? json['blockId'];
    final Object? sideRaw = json['side'] ?? json['direction'];

    return SharedBlock(
      blockId: _toString(idRaw),
      symbol: _toString(json['symbol']).toUpperCase(),
      direction: _toString(sideRaw).toUpperCase(),
      status: _toString(json['status']).toUpperCase(),
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastUpdatedAt: json['lastUpdatedAt'] is String
          ? DateTime.tryParse(json['lastUpdatedAt'] as String)
          : null,
      note: json['note'] as String?,
      origin: (() {
        final v = json['origin'];
        if (v is! String) return null;
        final t = v.trim();
        if (t.isEmpty) return null;
        final l = t.toLowerCase();
        // Consumer parsing stays canonical/allowlisted.
        if (l != t) throw FormatException('SharedBlock.origin must be lowercase canonical (got "$t")');
        const allowed = <String>{'legacy', 'au'};
        if (!allowed.contains(l)) throw FormatException('SharedBlock.origin not allowlisted (got "$t")');
        return l;
      })(),
      lifecycleVersion: json['lifecycleVersion'] is int
          ? json['lifecycleVersion'] as int
          : (json['lifecycleVersion'] is num
                ? (json['lifecycleVersion'] as num).toInt()
                : null),
      maxBlockDollars: _toDouble(json['maxBlockDollars']),
      initialRiskDollars: _toDouble(json['initialRiskDollars']),
      ageDays: _toDouble(json['ageDays']),
      regimeTag: json['regimeTag'] as String?,
      plannedOrderCount: count,
    );

  }
}

class SharedPlanSummary {
  final bool exists;
  final int orderCount;
  final int symbolCount;
  final int buyCount;
  final int sellCount;
  final double totalMaxExposure;
  final String? riskModeLabel;
  final double? assumedEquityDollars;
  final int? version;
  final DateTime? timestamp;
  // Plan identity metadata (optional). Present only when the v3 envelope provides it.
  final String? planId;
  final int? identityVersion;
  // Selector diagnostics (optional): why this plan was selected + which path was chosen.
  // Stored as strings to avoid coupling AU Insights UI to au_core enum types.
  final String? selectionReason;
  final String? selectedPlanPath;
  final List<SharedPlannedOrder> orders;
  final SharedRiskSnapshot? riskSummary;
  final List<SharedBlock> blocks;
  final SharedSnapshotMeta? snapshotMeta;

  /// Raw snapshotMeta map (read-only), preserved for diagnostics and provider wiring.
  ///
  /// - Null when unavailable (e.g., Shared Plan v3 envelope path).
  /// - Present for legacy JSON parse when snapshotMeta exists as a map.
  final Map<String, Object?>? snapshotMetaRaw;
  final List<SharedPosition> positions;
  final List<String>? allowedSymbols;

  /// Non-fatal App Group inventory warnings (normalized by au_core).
  /// Includes governance signals like INV-154 ungovernedArtifact.
  final List<String> inventoryWarnings;

  /// Non-fatal selector warnings from au_core SharedPlanLocatorV1.
  final List<String> locatorWarnings;

  const SharedPlanSummary({
    required this.exists,
    required this.orderCount,
    this.symbolCount = 0,
    this.buyCount = 0,
    this.sellCount = 0,
    this.totalMaxExposure = 0.0,
    this.riskModeLabel,
    this.assumedEquityDollars,
    this.version,
    this.timestamp,
    this.planId,
    this.identityVersion,
    this.selectionReason,
    this.selectedPlanPath,
    this.orders = const [],
    this.riskSummary,
    this.blocks = const [],
    this.snapshotMeta,
    this.snapshotMetaRaw,
    this.positions = const [],
    this.allowedSymbols,
    this.inventoryWarnings = const [],
    this.locatorWarnings = const [],
  });
}

class SharedPlanLoader {
  Future<SharedPlanSummary> load() async {
    try {
      final basePath = await SharedStorage.getAppGroupPath();
      if (basePath == null || basePath.isEmpty) {
        debugPrint('SharedPlanLoader: no AppGroup path available.');
        return const SharedPlanSummary(exists: false, orderCount: 0);
      }
      // Prefer active-account pointer -> per-account plan file (INV-144 parity).
      // Selection is governed by au_core SharedPlanLocatorV1 over a normalized StorageInventoryV1.
      final dir = Directory(basePath);
      final raw = <StorageArtifact>[];

      // Build raw inventory from the App Group directory (no deletion, read-only).
      try {
        if (await dir.exists()) {
          for (final ent in dir.listSync()) {
            if (ent is! File) continue;
            try {
              final p = ent.path;
              final fn = p.split(Platform.pathSeparator).last;
              final bytes = ent.lengthSync();
              final mod = ent.lastModifiedSync().toUtc().millisecondsSinceEpoch;
              raw.add(
                StorageArtifact(
                  path: p,
                  fileName: fn,
                  bytes: bytes,
                  modifiedAtEpochMsUtc: mod,
                ),
              );
            } catch (e) {
              debugPrint(
                'SharedPlanLoader: skipping inventory entry due to error: $e',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('SharedPlanLoader: inventory scan failed: $e');
      }

      final inventory = StorageInventoryNormalizer.normalize(raw);
      final invWarnings = <String>[];
      for (final w in inventory.warnings) {
        final msg = w.toString();
        invWarnings.add(msg);
        debugPrint('SharedPlanLoader: inventory warning: $msg');
      }

      String? activeAccountId;
      try {
        final pointer = File('$basePath/${SharedActiveAccountV1.kFileName}');
        if (await pointer.exists()) {
          final text = await pointer.readAsString();
          final parsed = SharedActiveAccountV1.tryParseJsonText(text);
          if (parsed != null) {
            final aid = parsed.activeAccountId.trim();
            if (aid.isNotEmpty) {
              activeAccountId = aid;
            }
          }
        }
      } catch (e) {
        debugPrint('SharedPlanLoader: active-account pointer read failed: $e');
      }

      const locator = SharedPlanLocatorV1();
      final sel = locator.locate(
        inventory: inventory,
        activeAccountId: activeAccountId,
        allowLegacyFallback: true,
      );
      final locWarnings = <String>[];
      for (final w in sel.warnings) {
        final msg = w.toString();
        locWarnings.add(msg);
        debugPrint('SharedPlanLoader: locator warning: $msg');
      }

      final selectedPath = sel.selected?.path;
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        debugPrint(
          'SharedPlanLoader: no shared plan file selected (reason=${sel.reason}).',
        );
        return SharedPlanSummary(
          exists: false,
          orderCount: 0,
          inventoryWarnings: invWarnings,
          locatorWarnings: locWarnings,
        );
      }

      final File f = File(selectedPath);
      final text = await f.readAsString();

      // Contract-first parse (Shared Plan v3 wrapper) using au_core canonical model.
      // If this succeeds, prefer it over ad-hoc field extraction to prevent schema drift.
      final env = SharedPlanV3Envelope.tryParseJsonText(text);
      if (env != null && env.version == 3) {
        // Orders (v1) -> AU Insights view model.
        final orders = <SharedPlannedOrder>[];
        for (final o in env.ordersV1) {
          orders.add(
            SharedPlannedOrder(
              symbol: o.symbol,
              side: (o.side == SharedOrderSideV1.sell)
                  ? SharedOrderSide.sell
                  : SharedOrderSide.buy,
              maxDollarExposure: o.maxDollarExposure,
              stopLossPrice: o.stopLossPrice,
              targetPrice: o.targetPrice,
              rationale: o.rationale,
            ),
          );
        }

        // Blocks v1: au_core provides these as raw maps; reuse AU Insights model.
        final blocks = <SharedBlock>[];
        final rawBlocks = env.blocksV1;
        if (rawBlocks != null) {
          for (final b in rawBlocks) {
            try {
              blocks.add(SharedBlock.fromJson(b));
            } catch (e, st) {
              debugPrint(
                'SharedPlanLoader: skipping bad block entry (contract): $e\n$st',
              );
              // Make this visible to the operator (non-fatal consumer warning).
              invWarnings.add('WARN: bad blocksV1 entry skipped: $e');
            }
          }
        }

        // Producer-owned governance: allowed symbol universe (optional).
        // Null/empty means "not enforced".
        final List<String>? allowedSymbolsOrNull = _normalizeAllowedSymbols(
          env.allowedSymbols,
        );
        // Preserve v3 envelope snapshotMeta + positions for provider wiring and diagnostics.
        // Use contract-first extraction via env.toJson() to avoid schema drift.
        Map<String, Object?>? snapshotMetaRaw;
        SharedSnapshotMeta? snapshotMeta;
        final positions = <SharedPosition>[];
        try {
          final envJson = Map<String, dynamic>.from(env.toJson());

          final sm = envJson['snapshotMeta'];
          if (sm is Map) {
            snapshotMetaRaw = Map<String, Object?>.from(sm);
            try {
              snapshotMeta = SharedSnapshotMeta.fromJson(
                Map<String, dynamic>.from(sm),
              );
            } catch (e, st) {
              debugPrint(
                'SharedPlanLoader: skipping bad v3 snapshotMeta entry: $e\n$st',
              );
            }
          }

          final pos = envJson['positionsV1'];
          if (pos is List) {
            for (final item in pos) {
              if (item is Map<String, dynamic>) {
                try {
                  positions.add(SharedPosition.fromJson(item));
                } catch (e, st) {
                  debugPrint(
                    'SharedPlanLoader: skipping bad v3 position entry (Map<String,dynamic>): $e\n$st',
                  );
                }
              } else if (item is Map) {
                try {
                  positions.add(
                    SharedPosition.fromJson(Map<String, dynamic>.from(item)),
                  );
                } catch (e, st) {
                  debugPrint(
                    'SharedPlanLoader: skipping bad v3 position entry (Map): $e\n$st',
                  );
                }
              }
            }
          }
        } catch (e, st) {
          debugPrint(
            'SharedPlanLoader: v3 snapshotMeta/positions extraction failed: $e\n$st',
          );
        }

        // --- AU Audit (read-only consumer) ---
        // Run the au_core Audit Wall on the *plan we are about to display*.
        // This is non-gating: we log summary + WARN/FAIL lines for visibility.
        try {
          final ordersV1 = env.ordersV1
              .map((o) => Map<String, Object?>.from(o.toJson()))
              .toList(growable: false);

          final blocksV1 = (env.blocksV1 ?? const <Map<String, dynamic>>[])
              .map((b) => Map<String, Object?>.from(b))
              .toList(growable: false);

          final ctx = AuditContext(
            now: DateTime.now(),
            snapshotMeta: snapshotMetaRaw ?? const <String, Object?>{},
            ordersV1: ordersV1,
            blocksV1: blocksV1,
            executionsV1: const <Map<String, Object?>>[],
            priorBlocksV1: const <Map<String, Object?>>[],
            strictMode: false,
            riskModeLabel: env.riskModeLabel,
            assumedEquityDollars: env.assumedEquityDollars,
            accountId: env.accountId,
            accountLabel: env.accountLabel,
            planId: env.planId,
            planSource: env.source,
            planTimestampIso: env.timestamp,
            identityVersion: env.identityVersion,
            allowedSymbols: allowedSymbolsOrNull,
          );

          final report = const AuditRunner().run(ctx);
          debugPrint('=== AU INSIGHTS AUDIT REPORT ===');
          debugPrint(report.summaryLine());
          for (final r in report.results) {
            if (r.status.label == 'FAIL' || r.status.label == 'WARN') {
              debugPrint(
                '[${r.id}] ${r.status.label}: ${r.title} — ${r.message}',
              );
            }
          }
          debugPrint('=== END AU INSIGHTS AUDIT REPORT ===');
        } catch (e, st) {
          debugPrint('AU Insights: audit run failed (non-gating): $e\n$st');
        }

        return SharedPlanSummary(
          exists: true,
          orderCount: orders.length,
          symbolCount: orders.map((o) => o.symbol).toSet().length,
          buyCount: orders.where((o) => o.side == SharedOrderSide.buy).length,
          sellCount: orders.where((o) => o.side == SharedOrderSide.sell).length,
          totalMaxExposure: orders.fold(
            0.0,
            (sum, o) => sum + o.maxDollarExposure,
          ),
          riskModeLabel: env.riskModeLabel,
          assumedEquityDollars: env.assumedEquityDollars,
          version: env.version,
          timestamp: (env.timestamp != null)
              ? DateTime.tryParse(env.timestamp!)
              : null,
          orders: orders,
          riskSummary: null,
          blocks: blocks,
          allowedSymbols: allowedSymbolsOrNull,
          snapshotMeta: snapshotMeta,
          snapshotMetaRaw: snapshotMetaRaw,
          positions: positions,
          inventoryWarnings: invWarnings,
          locatorWarnings: locWarnings,
        );
      }

      final decoded = json.decode(text);

      // Producer-owned governance: allowed symbol universe (optional).
      // Prefer the envelope field (contract-first). For legacy JSON, read root key if present.
      List<String>? allowedSymbols;
      if (decoded is Map) {
        allowedSymbols = _normalizeAllowedSymbols(decoded['allowedSymbols']);
      }

      List<SharedPlannedOrder> orders = <SharedPlannedOrder>[];
      SharedRiskSnapshot? riskSummary;
      List<SharedBlock> blocks = <SharedBlock>[];

      int? version;
      DateTime? timestamp;
      String? riskModeLabel;
      double? assumedEquityDollars;
      SharedSnapshotMeta? snapshotMeta;
      Map<String, Object?>? snapshotMetaRaw;
      List<SharedPosition> positions = <SharedPosition>[];

      void addOrdersFromList(List list) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            try {
              orders.add(SharedPlannedOrder.fromJson(item));
            } catch (e, st) {
              debugPrint(
                'SharedPlanLoader: skipping bad order entry (Map<String,dynamic>): $e\n$st',
              );
            }
          } else if (item is Map) {
            try {
              orders.add(
                SharedPlannedOrder.fromJson(Map<String, dynamic>.from(item)),
              );
            } catch (e, st) {
              debugPrint(
                'SharedPlanLoader: skipping bad order entry (Map): $e\n$st',
              );
            }
          }
        }
      }

      if (decoded is List) {
        addOrdersFromList(decoded);
      } else if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);

        final ver = map['version'];
        if (ver is int) {
          version = ver;
        }

        final ts = map['timestamp'];
        if (ts is String) {
          timestamp = DateTime.tryParse(ts);
        }

        final rm = map['riskModeLabel'];
        if (rm is String) {
          riskModeLabel = rm;
        }

        final ae = map['assumedEquityDollars'];
        final aeVal = _toDouble(ae);
        if (aeVal != null) {
          assumedEquityDollars = aeVal;
        }

        final rs = map['riskSummary'];
        if (rs is Map) {
          riskSummary = SharedRiskSnapshot.fromJson(
            Map<String, dynamic>.from(rs),
          );
        }

        final blocksJson = map['blocks'];
        if (blocksJson is List) {
          for (final b in blocksJson) {
            if (b is Map<String, dynamic>) {
              try {
                blocks.add(SharedBlock.fromJson(b));
              } catch (e, st) {
                debugPrint(
                  'SharedPlanLoader: skipping bad block entry (Map<String,dynamic>): $e\n$st',
                );
              }
            } else if (b is Map) {
              try {
                blocks.add(SharedBlock.fromJson(Map<String, dynamic>.from(b)));
              } catch (e, st) {
                debugPrint(
                  'SharedPlanLoader: skipping bad block entry (Map): $e\n$st',
                );
              }
            }
          }
        }

        final snapshotJson = map['snapshotMeta'];
        if (snapshotJson is Map) {
          snapshotMetaRaw = Map<String, Object?>.from(snapshotJson);
          try {
            snapshotMeta = SharedSnapshotMeta.fromJson(
              Map<String, dynamic>.from(snapshotJson),
            );
          } catch (e, st) {
            debugPrint(
              'SharedPlanLoader: skipping bad snapshotMeta entry: $e\n$st',
            );
          }
        }

        final positionsJson = map['positionsV1'];
        if (positionsJson is List) {
          for (final item in positionsJson) {
            if (item is Map<String, dynamic>) {
              try {
                positions.add(SharedPosition.fromJson(item));
              } catch (e, st) {
                debugPrint(
                  'SharedPlanLoader: skipping bad position entry (Map<String,dynamic>): $e\n$st',
                );
              }
            } else if (item is Map) {
              try {
                positions.add(
                  SharedPosition.fromJson(Map<String, dynamic>.from(item)),
                );
              } catch (e, st) {
                debugPrint(
                  'SharedPlanLoader: skipping bad position entry (Map): $e\n$st',
                );
              }
            }
          }
        }

        final dynamic v2 = map['ordersV2'];
        final dynamic v1 = map['ordersV1'] ?? map['orders'];

        if (v2 is List && v2.isNotEmpty) {
          addOrdersFromList(v2);
        } else if (v1 is List) {
          addOrdersFromList(v1);
        }
      }

      if (orders.isEmpty) {
        return SharedPlanSummary(
          exists: true,
          orderCount: 0,
          symbolCount: 0,
          buyCount: 0,
          sellCount: 0,
          totalMaxExposure: 0.0,
          riskModeLabel: riskModeLabel,
          assumedEquityDollars: assumedEquityDollars,
          version: version,
          timestamp: timestamp,
          planId: env?.planId,
          identityVersion: (env?.planId == null) ? null : env?.identityVersion,
          selectionReason: sel.reason.name,
          selectedPlanPath: selectedPath,
          orders: const [],
          riskSummary: riskSummary,
          blocks: blocks,
          snapshotMeta: snapshotMeta,
          snapshotMetaRaw: snapshotMetaRaw,
          allowedSymbols: allowedSymbols,
          positions: positions,
          inventoryWarnings: invWarnings,
          locatorWarnings: locWarnings,
        );
      }

      final symbols = <String>{};
      int buyCount = 0;
      int sellCount = 0;
      double totalExposure = 0.0;

      for (final o in orders) {
        symbols.add(o.symbol);
        if (o.side == SharedOrderSide.buy) {
          buyCount++;
        } else {
          sellCount++;
        }
        totalExposure += o.maxDollarExposure;
      }

      return SharedPlanSummary(
        exists: true,
        orderCount: orders.length,
        selectionReason: sel.reason.name,
        selectedPlanPath: selectedPath,
        symbolCount: symbols.length,
        buyCount: buyCount,
        sellCount: sellCount,
        totalMaxExposure: totalExposure,
        riskModeLabel: riskModeLabel,
        assumedEquityDollars: assumedEquityDollars,
        version: version,
        timestamp: timestamp,
        orders: orders,
        riskSummary: riskSummary,
        blocks: blocks,
        snapshotMeta: snapshotMeta,
        positions: positions,
        inventoryWarnings: invWarnings,
        locatorWarnings: locWarnings,
      );
    } catch (e, st) {
      debugPrint('SharedPlanLoader: error reading shared plan: $e\n$st');
      return const SharedPlanSummary(exists: false, orderCount: 0);
    }
  }
}
