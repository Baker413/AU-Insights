import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'services/shared_plan_loader.dart';
import 'screens/plan_details_screen.dart';
import 'screens/blocks_screen.dart';
import 'screens/symbols_screen.dart';
import 'trim_helper_screen.dart';
import 'package:au_core/theme/au_theme.dart';

void main() {
  runApp(const AuInsightsApp());
}

class AuInsightsApp extends StatelessWidget {
  const AuInsightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AU Insights',
      theme: AuTheme.light(),
      home: const InsightsHomeScreen(),
    );
  }
}

class InsightsHomeScreen extends StatefulWidget {
  const InsightsHomeScreen({super.key});

  @override
  State<InsightsHomeScreen> createState() => _InsightsHomeScreenState();
}

class _InsightsHomeScreenState extends State<InsightsHomeScreen> {
  final SharedPlanLoader _loader = SharedPlanLoader();
  late Future<SharedPlanSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _loader.load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AU Insights'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<SharedPlanSummary>(
          future: _future,
          builder: (context, snapshot) {
            final bool loading =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            final SharedPlanSummary? plan = snapshot.data;
            final bool hasPlan =
                plan != null && plan.exists && plan.orderCount > 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account & Block Overview',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: loading
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading shared plan from App Group…',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          )
                        : _buildOverviewCard(context, plan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Risk & Exposure',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: loading
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading risk summary…',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          )
                        : _buildRiskCard(context, plan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Shared Plan (IQ + HQ)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: loading
                        ? Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Loading shared plan from App Group…',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          )
                        : !hasPlan
                            ? Text(
                                'No shared plan found yet.\n\n'
                                'Once IQ Pro saves a shared plan on this device, '
                                'AU Insights will display full details here.',
                                style: theme.textTheme.bodyMedium,
                              )
                            : _buildPlanSummary(context, plan),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Trim Helper',
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
                          'Use Trim Helper to turn \'consider trimming\' insights into mock tickets you can follow in your broker. '
                          'AU Insights never places trades for you; it only helps you translate plan-level risk guidance into step-by-step instructions.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: !hasPlan
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => TrimHelperScreen(plan: plan),
                                      ),
                                    );
                                  },
                            child: const Text('Open Trim Helper'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Next Steps:',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '• Reuse the shared V3 plan parser from au_core for richer metrics.\n'
                  '• Add per-account, per-symbol, and per-block history views.\n'
                  '• Show risk-mode history and drawdown bands over time.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'AU Insights is read-only. It never places trades or changes your orders; '
                  'it only reads the shared plan written by IQ Pro on this device to help you '
                  'understand risk, blocks, and history.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, SharedPlanSummary? plan) {
    final theme = Theme.of(context);

    if (plan == null || !plan.exists) {
      return Text(
        'Waiting for IQ Pro to write a shared plan on this device.\n\n'
        'Once a plan exists, AU Insights will summarize equity, drawdown, and block status here.',
        style: theme.textTheme.bodyMedium,
      );
    }

    final p = plan;
    final double? equity = p.assumedEquityDollars;
    final double exposure = p.totalMaxExposure;
    final SharedRiskSnapshot? risk = p.riskSummary;
    final List<SharedBlock> blocks = p.blocks;

    final Map<String, int> statusCounts = <String, int>{};
    for (final b in blocks) {
      final status = b.status.isEmpty ? 'UNKNOWN' : b.status;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    String statusLine;
    if (blocks.isEmpty) {
      statusLine = 'Blocks: 0';
    } else {
      final entries = statusCounts.entries
          .map((e) => '${e.key}: ${e.value}')
          .toList()
        ..sort((a, b) => a.compareTo(b));
      statusLine = 'Blocks: ${blocks.length} • ${entries.join(' • ')}';
    }

    String drawdownLine = 'Drawdown vs peak: n/a';
    final double? dd = risk?.drawdownPercent;
    if (dd != null) {
      drawdownLine = 'Drawdown vs peak: ${dd.toStringAsFixed(1)}%';
    }

    String equityLine = 'Plan equity: n/a';
    if (equity != null && equity > 0) {
      equityLine = 'Plan equity: \$${equity.toStringAsFixed(0)}';
    }

    String exposureLine = 'Planned exposure: n/a';
    if (exposure > 0) {
      exposureLine = 'Planned exposure: \$${exposure.toStringAsFixed(0)}';
    }

    String exposurePctLine = '';
    if (equity != null && equity > 0 && exposure > 0) {
      final double expPct = (exposure / equity) * 100.0;
      exposurePctLine =
          'Planned exposure vs equity: ${expPct.toStringAsFixed(1)}%';
    }

    final bool hasBlocks = blocks.isNotEmpty;
    final bool hasOrders = p.orderCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          equityLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          exposureLine,
          style: theme.textTheme.bodyMedium,
        ),
        if (exposurePctLine.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            exposurePctLine,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          drawdownLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          statusLine,
          style: theme.textTheme.bodyMedium,
        ),
        if (hasBlocks || hasOrders) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8,
              children: <Widget>[
                if (hasBlocks)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              BlocksScreen(plan: p),
                        ),
                      );
                    },
                    child: const Text('View blocks'),
                  ),
                if (hasOrders)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              SymbolsScreen(plan: p),
                        ),
                      );
                    },
                    child: const Text('View symbols'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }



  double? _toFiniteDoubleOrNull(Object? v) {
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

  double? _drawdownPercentFromSnapshotMetaRaw(Map<String, Object?>? raw) {
    if (raw == null || raw.isEmpty) return null;

    double? fraction = _toFiniteDoubleOrNull(raw['drawdownPct']);

    if (fraction == null) {
      final nested = raw['drawdownTruthV1'];
      if (nested is Map) {
        fraction = _toFiniteDoubleOrNull(nested['drawdownPct']);
      }
    }

    if (fraction == null || fraction < 0.0 || fraction > 0.95) return null;
    return fraction * 100.0;
  }

  double _bestEffortCurrentInvestedDollars(SharedPlanSummary p) {
    final fromSnapshot = p.snapshotMeta?.currentExposureDollars;
    if (fromSnapshot != null && fromSnapshot.isFinite && fromSnapshot >= 0.0) {
      return fromSnapshot;
    }

    final fromLegacy = p.riskSummary?.currentInvestedDollars;
    if (fromLegacy != null && fromLegacy.isFinite && fromLegacy >= 0.0) {
      return fromLegacy;
    }

    return 0.0;
  }

  double? _bestEffortEquityBasis(SharedPlanSummary p) {
    final equity = p.assumedEquityDollars;
    if (equity != null && equity.isFinite && equity > 0.0) return equity;

    final legacyMaxInvest = p.riskSummary?.maxInvestDollars;
    if (legacyMaxInvest != null &&
        legacyMaxInvest.isFinite &&
        legacyMaxInvest > 0.0) {
      return legacyMaxInvest;
    }

    return null;
  }

  Widget _buildRiskCard(BuildContext context, SharedPlanSummary? plan) {
    final theme = Theme.of(context);

    if (plan == null || !plan.exists) {
      return Text(
        'No shared plan risk data yet.\n\n'
        'Once IQ Pro writes a shared plan on this device, AU Insights will summarize risk posture here.',
        style: theme.textTheme.bodyMedium,
      );
    }

    final p = plan;
    final SharedRiskSnapshot? risk = p.riskSummary;
    final double? equity = p.assumedEquityDollars;
    final double? maxInvest = risk?.maxInvestDollars;

    final double invested = _bestEffortCurrentInvestedDollars(p);
    final double hedge = risk?.currentHedgeDollars ?? 0.0;
    final double net = invested - hedge;

    double? equityForPct = _bestEffortEquityBasis(p);
    if (equityForPct != null && equityForPct <= 0) {
      equityForPct = null;
    }

    double? netPct;
    if (equityForPct != null && equityForPct > 0) {
      netPct = (net / equityForPct) * 100.0;
    }

    final String riskMode = p.riskModeLabel ?? 'Unknown';

    String equityLine = 'Plan equity: n/a';
    if (equity != null && equity > 0) {
      equityLine = 'Plan equity: \$${equity.toStringAsFixed(0)}';
    }

    String exposureLine = 'Planned exposure: n/a';
    if (p.totalMaxExposure > 0) {
      if (equityForPct != null && equityForPct > 0) {
        final double expPct = (p.totalMaxExposure / equityForPct) * 100.0;
        exposureLine =
            'Planned exposure: \$${p.totalMaxExposure.toStringAsFixed(0)} '
            '(${expPct.toStringAsFixed(1)}% of equity)';
      } else {
        exposureLine =
            'Planned exposure: \$${p.totalMaxExposure.toStringAsFixed(0)}';
      }
    }

    String allowedLine = 'Max allowed exposure: n/a';
    if (maxInvest != null && maxInvest > 0) {
      allowedLine =
          'Max allowed exposure: \$${maxInvest.toStringAsFixed(0)}';
    }

    String drawdownLine = 'Drawdown vs peak: n/a';
    final double? dd =
        _drawdownPercentFromSnapshotMetaRaw(p.snapshotMetaRaw) ??
        risk?.drawdownPercent;
    if (dd != null) {
      drawdownLine = 'Drawdown vs peak: ${dd.toStringAsFixed(1)}%';
    }

    String tiltLine;
    if (equityForPct == null || netPct == null) {
      tiltLine =
          'Net tilt: neutral (no clear long or hedge bias in this plan).';
    } else if (netPct.abs() < 5.0) {
      tiltLine =
          'Net tilt: roughly neutral (net exposure within about 5% of equity).';
    } else if (netPct > 0) {
      tiltLine =
          'Net tilt: long (net ${netPct.toStringAsFixed(1)}% of equity is invested on the long side).';
    } else {
      tiltLine =
          'Net tilt: hedged (net ${netPct.abs().toStringAsFixed(1)}% of equity is offset by hedges).';
    }

    bool showTrimHelperAction = false;

    String postureLine;
    if (equityForPct == null || netPct == null) {
      postureLine =
          'Risk posture: cannot compute net % of equity yet (missing equity basis).';
    } else if (netPct > 25.0) {
      postureLine =
          'Risk posture: meaningfully long – net exposure is above about 25% of equity. '
          'Stay within your guardrails. Tap "Trim Helper" below to explore mock trim ideas within your guardrails.';
      showTrimHelperAction = true;
    } else if (netPct > 0.0) {
      postureLine =
          'Risk posture: mildly long – net exposure is positive but still within a balanced band.';
      showTrimHelperAction = true;
    } else if (netPct < -25.0) {
      postureLine =
          'Risk posture: heavily hedged – net exposure is more than 25% of equity on the hedge side. '
          'Confirm this aligns with your risk mode and market view.';
      showTrimHelperAction = true;
    } else {
      postureLine =
          'Risk posture: mildly hedged – net exposure is slightly tilted toward hedges.';
      showTrimHelperAction = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Risk mode: $riskMode',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          equityLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          exposureLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          allowedLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          drawdownLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          tiltLine,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          postureLine,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        if (showTrimHelperAction) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.content_cut),
              label: const Text('Open Trim Helper'),
              onPressed: (!plan.exists)
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TrimHelperScreen(plan: plan),
                        ),
                      );
                    },
            ),
          ),
        ],
      ],
    );
  }



  void _showWarningsSheet(BuildContext context, SharedPlanSummary plan) {
    final inv = plan.inventoryWarnings;
    final loc = plan.locatorWarnings;

    final lines = <String>[];
    if (inv.isNotEmpty) {
      lines.add('Inventory warnings (${inv.length})');
      for (final w in inv) {
        lines.add('• $w');
      }
      lines.add('');
    }
    if (loc.isNotEmpty) {
      lines.add('Selector warnings (${loc.length})');
      for (final w in loc) {
        lines.add('• $w');
      }
    }

    final text = lines.join('\n').trim();
    if (text.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Warnings',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: text));
                        if (!sheetContext.mounted) return;
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Warnings copied to clipboard.')),
                        );
                      },
                      child: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        // Main screen only: allow quick rescan.
                        setState(() {
                          _future = _loader.load();
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Rescan'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(text),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanSummary(BuildContext context, SharedPlanSummary plan) {
    final theme = Theme.of(context);
    final equity = plan.assumedEquityDollars;
    final exposure = plan.totalMaxExposure;
    final timestamp = plan.timestamp;

    final snapshot = plan.snapshotMeta;
    final positions = plan.positions;

    List<SharedPosition> topPositions = <SharedPosition>[];
    if (positions.isNotEmpty) {
      topPositions = List<SharedPosition>.from(positions);
      topPositions.sort((a, b) {
        final aPx = a.lastPrice ?? 0;
        final bPx = b.lastPrice ?? 0;
        final aQty = a.netQuantity ?? 0;
        final bQty = b.netQuantity ?? 0;
        final aD = aPx * (aQty > 0 ? aQty : 0);
        final bD = bPx * (bQty > 0 ? bQty : 0);
        return bD.compareTo(aD);
      });
      if (topPositions.length > 3) {
        topPositions = topPositions.sublist(0, 3);
      }
    }

    String metaLine = '';
    if (plan.version != null) {
      metaLine = 'Version ${plan.version}';
    }
    if (timestamp != null) {
      final ts = timestamp.toLocal().toIso8601String();
      metaLine = metaLine.isEmpty ? ts : '$metaLine • $ts';
    }

    final ordersPreview = plan.orders.length <= 5
        ? plan.orders
        : plan.orders.sublist(0, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shared plan found.',
          style: theme.textTheme.titleMedium,
        ),
        if (metaLine.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            metaLine,
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 8),
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
        if (plan.inventoryWarnings.isNotEmpty || plan.locatorWarnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Warnings (read-only):', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (plan.inventoryWarnings.isNotEmpty) ...[
            
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Warnings',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showWarningsSheet(context, plan),
                          child: const Text('View all'),
                        ),
                      ],
                    ),
                        Text('Inventory warnings: ${plan.inventoryWarnings.length}', style: theme.textTheme.bodySmall),
            ...plan.inventoryWarnings.take(3).map((w) => Text('• $w', style: theme.textTheme.bodySmall)),
            if (plan.inventoryWarnings.length > 3)
              Text('• (+${plan.inventoryWarnings.length - 3} more)', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
          ],
          if (plan.locatorWarnings.isNotEmpty) ...[
            Text('Selector warnings: ${plan.locatorWarnings.length}', style: theme.textTheme.bodySmall),
            ...plan.locatorWarnings.take(3).map((w) => Text('• $w', style: theme.textTheme.bodySmall)),
            if (plan.locatorWarnings.length > 3)
              Text('• (+${plan.locatorWarnings.length - 3} more)', style: theme.textTheme.bodySmall),
          ],
        ],
        const SizedBox(height: 12),
        if (snapshot != null || topPositions.isNotEmpty) ...[
          Text(
            'Snapshot overview:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          if (snapshot != null) ...[
            if (snapshot.accountLabel != null && snapshot.accountLabel!.isNotEmpty)
              Text(
                'Account: ${snapshot.accountLabel}',
                style: theme.textTheme.bodySmall,
              ),
            if (snapshot.asOf != null)
              Text(
                'Snapshot as of: ${snapshot.asOf}',
                style: theme.textTheme.bodySmall,
              ),
            if (snapshot.totalTrades != null)
              Text(
                'Total trades in snapshot: ${snapshot.totalTrades}',
                style: theme.textTheme.bodySmall,
              ),
          ],
          if (topPositions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Largest current positions (approx):',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: topPositions.map((pos) {
                final qty = pos.netQuantity ?? 0;
                final px = pos.lastPrice ?? 0;
                final dollars =
                    qty > 0 && px > 0 ? qty * px : 0.0;
                return Text(
                  '${pos.symbol}: \$${dollars.toStringAsFixed(0)} (qty ${qty.toStringAsFixed(0)})',
                  style: theme.textTheme.bodySmall,
                );
              }).toList(),
            ),
          ],
        ],
        const SizedBox(height: 12),
        if (ordersPreview.isNotEmpty) ...[
          Text(
            'Order preview:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ordersPreview.length,
            itemBuilder: (context, index) {
              final o = ordersPreview[index];
              final side = o.side.toString().split('.').last.toUpperCase();
              final price = o.targetPrice ?? o.stopLossPrice;
              final priceStr =
                  price != null ? '\$${price.toStringAsFixed(2)}' : 'n/a';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${o.symbol} • $side',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${o.maxDollarExposure.toStringAsFixed(0)} @ $priceStr',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PlanDetailsScreen(plan: plan),
                ),
              );
            },
            child: const Text('View plan details'),
          ),
        ),
      ],
    );
  }
}
