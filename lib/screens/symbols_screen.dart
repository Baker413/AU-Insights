import 'package:flutter/material.dart';

import '../services/shared_plan_loader.dart';
import '../models/shared_planned_order.dart';

class SymbolsScreen extends StatelessWidget {
  final SharedPlanSummary plan;

  const SymbolsScreen({
    super.key,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final aggregates = _buildAggregates(plan);

    if (aggregates.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Symbols'),
        ),
        body: Center(
          child: Text(
            'No symbol-level exposure found in this plan.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    aggregates.sort(
      (a, b) => b.totalExposure.compareTo(a.totalExposure),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Symbols'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: aggregates.length,
        itemBuilder: (context, index) {
          final agg = aggregates[index];
          final exposureStr = '\$${agg.totalExposure.toStringAsFixed(0)}';

          final buySellText =
              'BUY ${agg.buyCount} • SELL ${agg.sellCount}';

          final blocksText = agg.blockCount > 0
              ? 'Blocks: ${agg.blockCount}'
              : 'Blocks: 0';

          return Card(
            child: ListTile(
              title: Text(
                agg.symbol,
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(
                '$buySellText\n$blocksText',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Text(
                exposureStr,
                style: theme.textTheme.bodyMedium,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SymbolDetailsScreen(
                      symbol: agg.symbol,
                      plan: plan,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  List<_SymbolAggregate> _buildAggregates(SharedPlanSummary plan) {
    final Map<String, _SymbolAggregateBuilder> builders = {};

    for (final order in plan.orders) {
      final symbol = order.symbol.toUpperCase();
      if (symbol.isEmpty) continue;

      final builder =
          builders.putIfAbsent(symbol, () => _SymbolAggregateBuilder(symbol));

      builder.totalExposure += order.maxDollarExposure;
      if (order.side.toString().toLowerCase().contains('buy')) {
        builder.buyCount++;
      } else {
        builder.sellCount++;
      }
    }

    final Map<String, Set<String>> symbolBlocks = {};
    for (final block in plan.blocks) {
      final symbol = block.symbol.toUpperCase();
      if (symbol.isEmpty) continue;

      final set = symbolBlocks.putIfAbsent(symbol, () => <String>{});
      set.add(block.blockId);
    }

    symbolBlocks.forEach((symbol, blockIds) {
      final builder =
          builders.putIfAbsent(symbol, () => _SymbolAggregateBuilder(symbol));
      builder.blockCount = blockIds.length;
    });

    return builders.values.map((b) => b.build()).toList();
  }
}

class _SymbolAggregate {
  final String symbol;
  final double totalExposure;
  final int buyCount;
  final int sellCount;
  final int blockCount;

  const _SymbolAggregate({
    required this.symbol,
    required this.totalExposure,
    required this.buyCount,
    required this.sellCount,
    required this.blockCount,
  });
}

class _SymbolAggregateBuilder {
  final String symbol;
  double totalExposure = 0.0;
  int buyCount = 0;
  int sellCount = 0;
  int blockCount = 0;

  _SymbolAggregateBuilder(this.symbol);

  _SymbolAggregate build() {
    return _SymbolAggregate(
      symbol: symbol,
      totalExposure: totalExposure,
      buyCount: buyCount,
      sellCount: sellCount,
      blockCount: blockCount,
    );
  }
}

class SymbolDetailsScreen extends StatelessWidget {
  final String symbol;
  final SharedPlanSummary plan;

  const SymbolDetailsScreen({
    super.key,
    required this.symbol,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upper = symbol.toUpperCase();

    final List<SharedPlannedOrder> orders = plan.orders
        .where((o) => o.symbol.toUpperCase() == upper)
        .toList();

    final List<SharedBlock> blocks = plan.blocks
        .where((b) => b.symbol.toUpperCase() == upper)
        .toList();

    double totalExposure = 0.0;
    double buyExposure = 0.0;
    double sellExposure = 0.0;
    int buyCount = 0;
    int sellCount = 0;

    for (final o in orders) {
      totalExposure += o.maxDollarExposure;
      final isBuy =
          o.side.toString().toLowerCase().contains('buy');
      if (isBuy) {
        buyExposure += o.maxDollarExposure;
        buyCount++;
      } else {
        sellExposure += o.maxDollarExposure;
        sellCount++;
      }
    }

    final hasOrders = orders.isNotEmpty;
    final hasBlocks = blocks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(upper),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Symbol Overview',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildOverviewCard(
                  context,
                  totalExposure: totalExposure,
                  buyExposure: buyExposure,
                  sellExposure: sellExposure,
                  buyCount: buyCount,
                  sellCount: sellCount,
                  blockCount: blocks.length,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (hasBlocks) ...[
              Text(
                'Blocks for $upper',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildBlocksSection(context, blocks),
              const SizedBox(height: 16),
            ],
            if (hasOrders) ...[
              Text(
                'Planned orders for $upper',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildOrdersSection(context, orders),
            ],
            if (!hasBlocks && !hasOrders)
              Text(
                'No blocks or planned orders found for $upper in this plan.',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required double totalExposure,
    required double buyExposure,
    required double sellExposure,
    required int buyCount,
    required int sellCount,
    required int blockCount,
  }) {
    final theme = Theme.of(context);

    final exposureLine = totalExposure > 0
        ? 'Total planned exposure: \$${totalExposure.toStringAsFixed(0)}'
        : 'Total planned exposure: n/a';

    final buyLine = buyCount > 0
        ? 'BUY: $buyCount (\$${buyExposure.toStringAsFixed(0)})'
        : 'BUY: 0';

    final sellLine = sellCount > 0
        ? 'SELL: $sellCount (\$${sellExposure.toStringAsFixed(0)})'
        : 'SELL: 0';

    final blocksLine = 'Blocks: $blockCount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exposureLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          buyLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 2),
        Text(
          sellLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          blocksLine,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildBlocksSection(BuildContext context, List<SharedBlock> blocks) {
    final theme = Theme.of(context);

    return Column(
      children: blocks.map((b) {
        final status =
            (b.status.isEmpty ? 'UNKNOWN' : b.status).toUpperCase();
        final regime = b.regimeTag ?? '';
        final maxDollars = b.maxBlockDollars;
        final riskDollars = b.initialRiskDollars;
        final ageDays = b.ageDays;

        String subtitle = status;
        if (regime.isNotEmpty) {
          subtitle = '$subtitle • $regime';
        }
        if (ageDays != null) {
          subtitle =
              '$subtitle • Age: ${ageDays.toStringAsFixed(1)}d';
        }

        String trailing = '';
        if (maxDollars != null) {
          trailing = '\$${maxDollars.toStringAsFixed(0)}';
        }

        return Card(
          child: ListTile(
            title: Text(
              b.blockId,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              subtitle,
              style: theme.textTheme.bodySmall,
            ),
            trailing: trailing.isNotEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trailing,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (riskDollars != null)
                        Text(
                          'Risk \$${riskDollars.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOrdersSection(
      BuildContext context, List<SharedPlannedOrder> orders) {
    final theme = Theme.of(context);

    return Column(
      children: orders.map((o) {
        final side = o.side.toString().split('.').last.toUpperCase();
        final price = o.targetPrice ?? o.stopLossPrice;
        final priceStr =
            price != null ? '\$${price.toStringAsFixed(2)}' : 'n/a';

        return Card(
          child: ListTile(
            title: Text(
              '$side • \$${o.maxDollarExposure.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: Text(
              'Price: $priceStr',
              style: theme.textTheme.bodySmall,
            ),
          ),
        );
      }).toList(),
    );
  }
}
