import 'dart:convert';

// Simple side enum for shared planned orders coming from IQ Pro.
enum SharedOrderSide {
  buy,
  sell,
}

// Model representing a symbol-level planned order that AU Insights reads
// from the shared JSON written by IQ Pro.
class SharedPlannedOrder {
  final String symbol;
  final SharedOrderSide side;
  final double maxDollarExposure;
  final double? stopLossPrice;
  final double? targetPrice;
  final String rationale;
  final String? nextActionLabel;

  const SharedPlannedOrder({
    required this.symbol,
    required this.side,
    required this.maxDollarExposure,
    this.stopLossPrice,
    this.targetPrice,
    this.rationale = '',
    this.nextActionLabel,
  });

  factory SharedPlannedOrder.fromJson(Map<String, dynamic> json) {
    String readString(dynamic v) =>
        v is String ? v : (v?.toString() ?? '');

    double? readDoubleOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        return parsed;
      }
      return null;
    }

    double readDoubleOrZero(dynamic v) =>
        readDoubleOrNull(v) ?? 0.0;

    final symbol = readString(json['symbol']).toUpperCase();

    final sideStr = readString(json['side']).toLowerCase();
    final SharedOrderSide side =
        sideStr == 'sell' ? SharedOrderSide.sell : SharedOrderSide.buy;

    return SharedPlannedOrder(
      symbol: symbol,
      side: side,
      maxDollarExposure: readDoubleOrZero(json['maxDollarExposure']),
      stopLossPrice: readDoubleOrNull(json['stopLossPrice']),
      targetPrice: readDoubleOrNull(json['targetPrice']),
      rationale: readString(json['rationale']),
      nextActionLabel: json['nextActionLabel'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'symbol': symbol,
      'side': side == SharedOrderSide.buy ? 'BUY' : 'SELL',
      'maxDollarExposure': maxDollarExposure,
      'stopLossPrice': stopLossPrice,
      'targetPrice': targetPrice,
      'rationale': rationale,
      'nextActionLabel': nextActionLabel,
    };
  }

  static List<SharedPlannedOrder> listFromJsonText(String text) {
    final decoded = json.decode(text);
    if (decoded is List) {
      return decoded
          .map((e) => SharedPlannedOrder.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final List<dynamic>? orders =
          (map['ordersV2'] as List?) ??
          (map['ordersV1'] as List?) ??
          (map['orders'] as List?);
      if (orders == null) return const [];
      return orders
          .map((e) => SharedPlannedOrder.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    }
    return const [];
  }
}
