import 'package:flutter/material.dart';

import '../services/shared_execution_loader.dart';
import '../services/shared_plan_loader.dart';
import '../widgets/plan_selection_banner.dart';

class BlocksScreen extends StatefulWidget {
  final SharedPlanSummary plan;

  const BlocksScreen({
    super.key,
    required this.plan,
  });

  @override
  State<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends State<BlocksScreen> {
  String _statusFilter = 'ALL';
  String _sortKey = 'EXPOSURE_DESC';

  final SharedExecutionLoader _execLoader = SharedExecutionLoader();
  Future<SharedExecutionLoaderResult>? _liveExecFuture;

  void _refreshLiveBlocksFuture() {
    final planned = <String>[];
    final legacy = widget.plan.blocks
        .where((b) => b.isLegacy)
        .map((b) => '${b.symbol}|${b.direction}'.toUpperCase())
        .toList(growable: false);
    for (final b in widget.plan.blocks) {
      final sym = b.symbol.trim().toUpperCase();
      final side = b.direction.trim().toUpperCase();
      if (sym.isEmpty || side.isEmpty) continue;
      planned.add('$sym|$side');
    }

    _liveExecFuture = _execLoader.loadForPlan(
      planId: widget.plan.planId,
      plannedSymbolSides: planned,
      legacySymbolSides: legacy,
    );
  }

  @override
  void initState() {
    super.initState();
    _refreshLiveBlocksFuture();
  }

  @override
  void didUpdateWidget(covariant BlocksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plan.planId != widget.plan.planId ||
        oldWidget.plan.blocks.length != widget.plan.blocks.length) {
      _refreshLiveBlocksFuture();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allBlocks = widget.plan.blocks;

    final blocks = _buildVisibleBlocks(allBlocks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocks'),
      ),
      body: Column(
        children: [
          PlanSelectionBanner(
            selectionReason: widget.plan.selectionReason,
            selectedPlanPath: widget.plan.selectedPlanPath,
          ),
          _buildLiveBlocksCard(theme),
          if (allBlocks.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'No blocks in this plan.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatusFilter(theme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSortPicker(theme),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: blocks.length,
                itemBuilder: (context, index) {
                  final b = blocks[index];
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
                        '${b.symbol} • ${b.blockId}',
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                BlockDetailsScreen(block: b),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveBlocksCard(ThemeData theme) {
    final f = _liveExecFuture;
    if (f == null) return const SizedBox.shrink();

    return FutureBuilder<SharedExecutionLoaderResult>(
      future: f,
      builder: (context, snap) {
        final waiting =
            snap.connectionState == ConnectionState.waiting && !snap.hasData;

        final data = snap.data;
        final rows = data?.liveBlocks ?? const <LiveBlockRow>[];

        String subtitle;
        if (waiting) {
          subtitle = 'Loading execution journal…';
        } else if (snap.hasError) {
          subtitle = 'Execution journal unavailable (best-effort).';
        } else if (data == null) {
          subtitle = 'Execution journal: n/a';
        } else {
          final aid = (data.activeAccountId ?? '').trim();
          subtitle =
              'Execution journal: ${data.journalEntryCount} entries'
              ' • Legacy receipts: ${data.legacyReceiptCount}'
              '${aid.isNotEmpty ? ' • Active acct: $aid' : ''}';
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Live blocks (executions)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                else if (rows.isEmpty)
                  Text(
                    'No execution entries grouped into live blocks yet.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  Column(
                    children: rows.map((r) {
                      final planned = r.matchesPlannedBlock ? 'Planned' : 'Unplanned';
                      final planId = r.matchesPlanId ? 'Plan✓' : 'Plan✗';
                      final acct = r.matchesActiveAccount ? 'Acct✓' : 'Acct✗';
                      final last = (r.lastConfirmedAtUtc ?? '').trim();
                      final lastLine = last.isNotEmpty ? ' • Last: $last' : '';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                '${r.symbol} • ${r.side}\n$planned • $planId • $acct$lastLine',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (r.isLegacyOrigin)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: theme.dividerColor,
                                  ),
                                ),
                                child: Text(
                                  'LEGACY',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                            if (r.isLegacyOrigin) const SizedBox(width: 8),
                            Text(
                              '${r.uniqueOrderCount} orders',
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
        );
      },
    );
  }

  List<SharedBlock> _buildVisibleBlocks(List<SharedBlock> allBlocks) {
    final List<SharedBlock> result = List<SharedBlock>.from(allBlocks);

    if (_statusFilter != 'ALL') {
      final filterUpper = _statusFilter.toUpperCase();
      result.retainWhere((b) {
        final status = (b.status.isEmpty ? 'UNKNOWN' : b.status).toUpperCase();
        if (filterUpper == 'OTHER') {
          return status != 'PLANNED' &&
              status != 'LIVE' &&
              status != 'CLOSING' &&
              status != 'CLOSED' &&
              status != 'RETIRED';
        }
        return status == filterUpper;
      });
    }

    result.sort((a, b) {
      switch (_sortKey) {
        case 'SYMBOL_ASC':
          return a.symbol.toUpperCase().compareTo(b.symbol.toUpperCase());
        case 'AGE_DESC':
          final aAge = a.ageDays ?? 0.0;
          final bAge = b.ageDays ?? 0.0;
          return bAge.compareTo(aAge);
        case 'EXPOSURE_DESC':
        default:
          final aExp = a.maxBlockDollars ?? 0.0;
          final bExp = b.maxBlockDollars ?? 0.0;
          return bExp.compareTo(aExp);
      }
    });

    return result;
  }

  Widget _buildStatusFilter(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _statusFilter,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Status',
        labelStyle: theme.textTheme.bodySmall,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'ALL', child: Text('All')),
        DropdownMenuItem(value: 'PLANNED', child: Text('Planned')),
        DropdownMenuItem(value: 'LIVE', child: Text('Live')),
        DropdownMenuItem(value: 'CLOSING', child: Text('Closing')),
        DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
        DropdownMenuItem(value: 'RETIRED', child: Text('Retired')),
        DropdownMenuItem(value: 'OTHER', child: Text('Other')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildSortPicker(ThemeData theme) {
    return DropdownButtonFormField<String>(
      initialValue: _sortKey,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Sort',
        labelStyle: theme.textTheme.bodySmall,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'EXPOSURE_DESC', child: Text('Exposure')),
        DropdownMenuItem(value: 'AGE_DESC', child: Text('Age')),
        DropdownMenuItem(value: 'SYMBOL_ASC', child: Text('Symbol')),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _sortKey = value;
        });
      },
    );
  }
}

class BlockDetailsScreen extends StatelessWidget {
  final SharedBlock block;

  const BlockDetailsScreen({
    super.key,
    required this.block,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = block.createdAt?.toLocal();
    final updated = block.lastUpdatedAt?.toLocal();

    final String direction =
        block.direction.isEmpty ? 'UNKNOWN' : block.direction.toUpperCase();
    final String status =
        block.status.isEmpty ? 'UNKNOWN' : block.status.toUpperCase();

    String ageLine = 'Age: n/a';
    String ageBucketLabel = '';
    if (block.ageDays != null) {
      final double age = block.ageDays!;
      String bucket;
      if (age < 7) {
        bucket = 'new';
      } else if (age < 30) {
        bucket = 'mid';
      } else {
        bucket = 'old';
      }
      ageBucketLabel = ' ($bucket)';
      ageLine = 'Age: ${age.toStringAsFixed(1)} days$ageBucketLabel';
    }

    final int orderCount = block.plannedOrderCount;
    String ordersLine;
    if (orderCount <= 0) {
      ordersLine = '0 planned orders in this block.';
    } else if (orderCount == 1) {
      ordersLine = '1 planned order in this block.';
    } else {
      ordersLine = '$orderCount planned orders in this block.';
    }

    final String statusLine =
        (block.regimeTag != null && block.regimeTag!.isNotEmpty)
            ? 'Status: $status • Regime: ${block.regimeTag}'
            : 'Status: $status';

    return Scaffold(
      appBar: AppBar(
        title: Text('${block.symbol} ($direction)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              block.blockId,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              statusLine,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              ageLine,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              ordersLine,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (block.maxBlockDollars != null)
              Text(
                'Max block dollars: \$${block.maxBlockDollars!.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium,
              ),
            if (block.initialRiskDollars != null) ...[
              const SizedBox(height: 4),
              Text(
                'Initial risk (planned): \$${block.initialRiskDollars!.toStringAsFixed(0)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            if (created != null)
              Text(
                'Created: $created',
                style: theme.textTheme.bodySmall,
              ),
            if (updated != null) ...[
              const SizedBox(height: 2),
              Text(
                'Last updated: $updated',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (block.note != null && block.note!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Note',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                block.note!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
