import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../shared/storage.dart';
import '../models/shared_planned_order.dart';

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
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

  const SharedSnapshotMeta({this.accountLabel, this.asOf, this.totalTrades});

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

    return SharedSnapshotMeta(
      accountLabel: json['accountLabel'] as String?,
      asOf: asOf,
      totalTrades: totalTrades,
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

      // Prefer account-scoped shared plan (matches IQ/HQ V3 behavior).
      // Fallback to legacy filename for older builds.
      final preferred = File('$basePath/shared_plan_v3_default.json');
      final legacy = File('$basePath/shared_plan_v3.json');
      final file = await preferred.exists() ? preferred : legacy;
      if (!await file.exists()) {
        debugPrint('SharedPlanLoader: shared_plan_v3.json does not exist.');
        return const SharedPlanSummary(exists: false, orderCount: 0);
      }

      final text = await file.readAsString();
      final decoded = json.decode(text);

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
