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
      drawdownPercent: _toDouble(json['drawdownPercent']),
    );
  }
}

class SharedSnapshotMeta {
  final String? accountLabel;
  final DateTime? asOf;
  final int? totalTrades;

  /// Canonical (preferred) long exposure dollars, producer-supplied.
  ///
  /// Backwards-compatible: if absent, we fall back to legacy `exposureDollars`.
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
        _toDouble(json['currentExposureDollars']) ?? _toDouble(json['exposureDollars']);

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
    this.lifecycleVersion,
    this.maxBlockDollars,
    this.initialRiskDollars,
    this.ageDays,
    this.regimeTag,
    this.plannedOrderCount = 0,
  });

  factory SharedBlock.fromJson(Map<String, dynamic> json) {
    final plannedOrders = json['plannedOrders'];
    int count = 0;
    if (plannedOrders is List) {
      count = plannedOrders.length;
    }

    return SharedBlock(
      blockId: _toString(json['blockId']),
      symbol: _toString(json['symbol']).toUpperCase(),
      direction: _toString(json['direction']).toUpperCase(),
      status: _toString(json['status']).toUpperCase(),
      createdAt: json['createdAt'] is String
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastUpdatedAt: json['lastUpdatedAt'] is String
          ? DateTime.tryParse(json['lastUpdatedAt'] as String)
          : null,
      note: json['note'] as String?,
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
  final List<SharedPlannedOrder> orders;
  final SharedRiskSnapshot? riskSummary;
  final List<SharedBlock> blocks;
  final SharedSnapshotMeta? snapshotMeta;
  final List<SharedPosition> positions;
  final List<String>? allowedSymbols;

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
    this.orders = const [],
    this.riskSummary,
    this.blocks = const [],
    this.snapshotMeta,
    this.positions = const [],
    this.allowedSymbols,
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

      // Prefer active-account pointer -> per-account plan file (HQ parity).
      // If pointer missing/invalid, fall back to newest per-account plan file.
      // Finally fall back to legacy shared_plan_v3.json.
      final legacy = File('$basePath/shared_plan_v3.json');
      File? file;

      // 1) Pointer-first: shared_active_account_v1.json -> shared_plan_v3_<safeAccountId>.json
      try {
        final pointer = File('$basePath/shared_active_account_v1.json');
        if (await pointer.exists()) {
          final decoded = json.decode(await pointer.readAsString());
          if (decoded is Map) {
            final m = Map<String, dynamic>.from(decoded);
            final aid = m['accountId'];
            if (aid is String && aid.trim().isNotEmpty) {
              final safe = aid.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
              final perAccount = File('$basePath/shared_plan_v3_$safe.json');
              if (await perAccount.exists()) {
                file = perAccount;
                debugPrint('SharedPlanLoader: using active-account plan file: ${file.path}');
              } else {
                debugPrint('SharedPlanLoader: active pointer found but plan file missing: ${perAccount.path}');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('SharedPlanLoader: active-account pointer read failed: $e');
      }

      // 2) Newest-file scan: shared_plan_v3_*.json (per-account files)
      if (file == null) {
        try {
          final dir = legacy.parent;
          if (await dir.exists()) {
            final candidates = dir
                .listSync()
                .whereType<File>()
                .where((f) => f.path.contains('/shared_plan_v3_') && f.path.endsWith('.json'))
                .toList();
            candidates.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
            if (candidates.isNotEmpty) {
              file = candidates.first;
              debugPrint('SharedPlanLoader: using newest shared plan file: ${file.path}');
            }
          }
        } catch (e) {
          debugPrint('SharedPlanLoader: newest-file scan failed: $e');
        }
      }

      // 3) Legacy fallback
      file ??= (await legacy.exists()) ? legacy : null;
      if (file == null || !await file.exists()) {
        debugPrint('SharedPlanLoader: no shared plan file found.');
        return const SharedPlanSummary(exists: false, orderCount: 0);
      }

      final File f = file;
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
              debugPrint('SharedPlanLoader: skipping bad block entry (contract): $e\n$st');
            }
          }
        }

        // Producer-owned governance: allowed symbol universe (optional).
        // Null/empty means "not enforced".
        final List<String>? allowedSymbolsOrNull = _normalizeAllowedSymbols(env.allowedSymbols);

        return SharedPlanSummary(
          exists: true,
          orderCount: orders.length,
          symbolCount: orders.map((o) => o.symbol).toSet().length,
          buyCount: orders.where((o) => o.side == SharedOrderSide.buy).length,
          sellCount: orders.where((o) => o.side == SharedOrderSide.sell).length,
          totalMaxExposure: orders.fold(0.0, (sum, o) => sum + o.maxDollarExposure),
          riskModeLabel: env.riskModeLabel,
          assumedEquityDollars: env.assumedEquityDollars,
          version: env.version,
          timestamp: (env.timestamp != null) ? DateTime.tryParse(env.timestamp!) : null,
          orders: orders,
          riskSummary: null,
          blocks: blocks,
          allowedSymbols: allowedSymbolsOrNull,
          snapshotMeta: null,
          positions: const [],
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
          orders: const [],
          riskSummary: riskSummary,
          blocks: blocks,
          snapshotMeta: snapshotMeta,
          allowedSymbols: allowedSymbols,
          positions: positions,
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
      );
    } catch (e, st) {
      debugPrint('SharedPlanLoader: error reading shared plan: $e\n$st');
      return const SharedPlanSummary(exists: false, orderCount: 0);
    }
  }
}
