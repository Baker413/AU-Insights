import 'package:flutter/material.dart';

import '../services/shared_plan_loader.dart';
import '../models/shared_planned_order.dart';

class PlanDetailsScreen extends StatelessWidget {
  final SharedPlanSummary plan;

  const PlanDetailsScreen({
    super.key,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equity = plan.assumedEquityDollars;
    final exposure = plan.totalMaxExposure;
    final timestamp = plan.timestamp;
    final risk = plan.riskSummary;
    final blocks = plan.blocks;

    String metaLine = '';
    if (plan.version != null) {
      metaLine = 'Version ${plan.version}';
    }
    if (timestamp != null) {
      final ts = timestamp.toLocal().toIso8601String();
      metaLine = metaLine.isEmpty ? ts : '$metaLine • $ts';
    }

    final orders = plan.orders;
    final symbolAgg = _buildSymbolAggregates(orders);
    final blockStatusAgg = _buildBlockStatusAggregates(blocks);

    double totalBuyDollars = 0;
    double totalSellDollars = 0;
    for (final o in orders) {
      if (o.side == SharedOrderSide.buy) {
        totalBuyDollars += o.maxDollarExposure;
      } else {
        totalSellDollars += o.maxDollarExposure;
      }
    }

    final double netDollars = totalBuyDollars - totalSellDollars;

    double? netPctOfEquity;
    if (equity != null && equity > 0) {
      netPctOfEquity = (netDollars / equity) * 100;
    }

    double? investedVsMaxPct;
    if (risk != null &&
        risk.maxInvestDollars != null &&
        risk.currentInvestedDollars != null &&
        risk.maxInvestDollars! > 0) {
      final double maxInvest = risk.maxInvestDollars!;
      final double currentInvest = risk.currentInvestedDollars!;
      investedVsMaxPct = (currentInvest / maxInvest) * 100;
    }

    String coachLine;
    if (equity == null || equity <= 0) {
      coachLine =
          'This plan does not include a specific equity value. AU Insights can summarize dollar exposure but cannot show percentages of equity.';
    } else if (netPctOfEquity == null) {
      coachLine =
          'AU Insights could not compute a net tilt for this plan, but all IQ and HQ guardrails still apply.';
    } else {
      final double absNet = netPctOfEquity.abs();
      final double investPct = investedVsMaxPct ?? 0.0;

      if (absNet < 5 && investPct < 60) {
        coachLine =
            'This plan has a modest net tilt relative to your equity and appears well within typical guardrails for most risk modes. Continue to follow your IQ Pro block rules and HQ Pro hedge caps.';
      } else if (absNet < 15 && investPct <= 80) {
        coachLine =
            'This plan adds a noticeable net tilt while remaining inside typical guardrails. Make sure the size of this tilt matches your chosen risk mode and your comfort level.';
      } else {
        coachLine =
            'This plan has a large net tilt relative to your equity. Before placing any trades, consider double-checking block sizes, aging, and your chosen risk mode so everything stays inside your personal guardrails.';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Shared Plan Snapshot',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (metaLine.isNotEmpty) ...[
                      Text(
                        metaLine,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Orders: ${plan.orderCount} • Symbols: ${plan.symbolCount}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      'BUY: ${plan.buyCount} • SELL: ${plan.sellCount}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (exposure > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Max planned exposure: \$${exposure.toStringAsFixed(0)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (plan.riskModeLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'IQ Risk Mode: ${plan.riskModeLabel}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (equity != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Assumed Equity: \$${equity.toStringAsFixed(0)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exposure & Tilt Overview',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buys: \$${totalBuyDollars.toStringAsFixed(0)} • Sells: \$${totalSellDollars.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      equity != null && equity > 0 && netPctOfEquity != null
                          ? 'Net tilt: \$${netDollars.toStringAsFixed(0)} '
                            '(${netPctOfEquity.toStringAsFixed(1)}% of equity)'
                          : 'Net tilt: \$${netDollars.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (investedVsMaxPct != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Planned invested vs max: ${investedVsMaxPct.toStringAsFixed(1)}% of your configured max invest.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      coachLine,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AU Insights never places trades or changes your orders; it only summarizes risk and exposure from your current shared plan.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Risk Summary',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (risk == null)
              Text(
                'No risk summary embedded in this plan yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (risk.maxInvestDollars != null) ...[
                        Text(
                          'Max Invest: \$${risk.maxInvestDollars!.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (risk.currentInvestedDollars != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Planned Invested: \$${risk.currentInvestedDollars!.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (risk.currentHedgeDollars != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Planned Hedge: \$${risk.currentHedgeDollars!.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (risk.maxPerSymbolDollars != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Max per Symbol: \$${risk.maxPerSymbolDollars!.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (risk.maxPerBlockRiskDollars != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Max per Block Risk: \$${risk.maxPerBlockRiskDollars!.toStringAsFixed(0)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      if (risk.drawdownPercent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Drawdown: ${risk.drawdownPercent!.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Block Summary',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (blocks.isEmpty)
              Text(
                'No blocks embedded in this plan yet.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Blocks: ${blocks.length}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: blockStatusAgg.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  entry.value.toString(),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Symbol Summary',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (symbolAgg.isEmpty)
              Text(
                'No symbols in this plan.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: symbolAgg.map((agg) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                agg.symbol,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            Text(
                              'BUY ${agg.buyCount} / SELL ${agg.sellCount}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '\$${agg.totalExposure.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Orders',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              Text(
                'No orders in this plan.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final o = orders[index];
                  final side = o.side.toString().split('.').last.toUpperCase();
                  final price = o.targetPrice ?? o.stopLossPrice;
                  final priceStr =
                      price != null ? '\$${price.toStringAsFixed(2)}' : 'n/a';

                  String subtitle =
                      '${o.maxDollarExposure.toStringAsFixed(0)} @ $priceStr';
                  final label = o.nextActionLabel;
                  if (label != null && label.isNotEmpty) {
                    subtitle = '$subtitle\n$label';
                  } else if (o.rationale.isNotEmpty) {
                    subtitle = '$subtitle\n${o.rationale}';
                  }

                  return Card(
                    child: ListTile(
                      title: Text(
                        '${o.symbol} • $side',
                        style: theme.textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  List<_SymbolAggregate> _buildSymbolAggregates(
      List<SharedPlannedOrder> orders) {
    final Map<String, _SymbolAggregate> map = {};
    for (final o in orders) {
      final key = o.symbol;
      final existing = map[key];
      if (existing == null) {
        map[key] = _SymbolAggregate(
          symbol: key,
          totalExposure: o.maxDollarExposure,
          buyCount: o.side == SharedOrderSide.buy ? 1 : 0,
          sellCount: o.side == SharedOrderSide.sell ? 1 : 0,
        );
      } else {
        existing.totalExposure += o.maxDollarExposure;
        if (o.side == SharedOrderSide.buy) {
          existing.buyCount += 1;
        } else {
          existing.sellCount += 1;
        }
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    return list;
  }

  Map<String, int> _buildBlockStatusAggregates(List<SharedBlock> blocks) {
    final Map<String, int> map = {};
    for (final b in blocks) {
      final status = b.status.isEmpty ? 'UNKNOWN' : b.status;
      map[status] = (map[status] ?? 0) + 1;
    }
    return map;
  }
}

class _SymbolAggregate {
  final String symbol;
  double totalExposure;
  int buyCount;
  int sellCount;

  _SymbolAggregate({
    required this.symbol,
    required this.totalExposure,
    required this.buyCount,
    required this.sellCount,
  });
}
