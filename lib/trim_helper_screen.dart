import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:au_core/au_core.dart';

import 'services/shared_plan_loader.dart';

/// AU Insights Trim Helper (beta).
///
/// Turns "consider trimming" into simple Fidelity-style mock SELL tickets.
/// AU Insights never places trades and never connects to your brokerage.
///
/// Sizing logic (current):
/// - Uses REAL positions market value: netQuantity * lastPrice (long only).
/// - Caps to min( risk.maxPerSymbolDollars , equity * 20% ) when available.
/// - Suggests a trim only if it exceeds a small threshold (default $1,000).
class TrimHelperScreen extends StatelessWidget {
  final SharedPlanSummary plan;

  const TrimHelperScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String fmtMoney(double v) => '\$${v.toStringAsFixed(2)}';

    final double? equity = plan.assumedEquityDollars;
    final SharedRiskSnapshot? risk = plan.riskSummary;

    // Best-effort account label (older plans may not have this).
    final String accountLabel =
        ((plan.snapshotMeta?.accountLabel ?? '').trim().isNotEmpty)
        ? plan.snapshotMeta!.accountLabel!.trim()
        : '—';

    // lastPrice lookup (from shared snapshot positions) for share sizing.
    final Map<String, double> lastPriceBySymbol = <String, double>{};
    for (final p in plan.positions) {
      final px = p.lastPrice;
      if (px != null && px > 0) {
        lastPriceBySymbol[p.symbol.toUpperCase()] = px;
      }
    }

    // 1) Build per-symbol CURRENT market value from REAL positions:
    //    marketValue ≈ netQuantity * lastPrice (long positions only).
    final Map<String, double> dollarsBySymbol = <String, double>{};
    for (final p in plan.positions) {
      final qty = p.netQuantity;
      final px = p.lastPrice;
      if (qty != null && qty > 0 && px != null && px > 0) {
        final symbol = p.symbol.toUpperCase();
        dollarsBySymbol[symbol] = qty * px;
      }
    }

    // 2) Determine caps:
    //    - risk.maxPerSymbolDollars from IQ/HQ risk engine, when present.
    //    - equityCap (20% of equity) as sanity check.
    final double? maxPerSymbol = risk?.maxPerSymbolDollars;
    final double? equityCap = (equity != null && equity > 0)
        ? equity * 0.20
        : null;

    double? effectiveCap() {
      double? cap = maxPerSymbol;
      if (equityCap != null) {
        cap = (cap == null) ? equityCap : (cap < equityCap ? cap : equityCap);
      }
      return cap;
    }

    final double? cap = effectiveCap();

    // 3) Build trim suggestions.
    final List<_TrimSuggestion> suggestions = <_TrimSuggestion>[];

    dollarsBySymbol.forEach((symbol, currentDollars) {
      double targetDollars = currentDollars;

      if (cap != null && targetDollars > cap) {
        targetDollars = cap;
      }

      final trimDollars = currentDollars - targetDollars;

      // Only suggest a trim if it is meaningful in dollars.
      if (trimDollars >= 1000) {
        suggestions.add(
          _TrimSuggestion(
            symbol: symbol,
            currentDollars: currentDollars,
            targetDollars: targetDollars,
            rationale: _buildRationale(
              symbol: symbol,
              current: currentDollars,
              target: targetDollars,
              equity: equity,
              maxPerSymbol: maxPerSymbol,
              equityCap: equityCap,
            ),
          ),
        );
      }
    });

    // Sort largest trims first.
    suggestions.sort((a, b) => b.trimDollars.compareTo(a.trimDollars));

    final bool hasSuggestions = suggestions.isNotEmpty;

    // Diagnostics: show top positions by market value.
    final ranked = dollarsBySymbol.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.take(5).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Trim Helper (beta)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Trim Helper (beta)', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This tool reads your shared snapshot positions and highlights symbols that may be large '
              'relative to your guardrails. It expresses those as mock SELL tickets you can enter manually '
              'in Fidelity (or similar). AU Insights never places trades.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),

            // Diagnostics card so we can see why it’s not triggering.
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Diagnostics', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Equity: ${equity != null ? fmtMoney(equity) : "—"}\n'
                      'Per-symbol cap (from IQ/HQ): ${maxPerSymbol != null ? fmtMoney(maxPerSymbol) : "—"}\n'
                      'Equity cap (20%): ${equityCap != null ? fmtMoney(equityCap) : "—"}\n'
                      'Effective cap used: ${cap != null ? fmtMoney(cap) : "—"}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Top positions (market value)',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),

                    for (final e in top)
                      Builder(
                        builder: (context) {
                          final double v = e.value;
                          final double? over = (cap != null)
                              ? (v - cap)
                              : null; // cap is effective cap used
                          final String overText = (over == null)
                              ? ''
                              : (over > 0
                                    ? ' • over cap by ${fmtMoney(over)}'
                                    : ' • under cap by ${fmtMoney(-over)}');

                          final String pctText = (equity != null && equity > 0)
                              ? ' • ${(v / equity * 100).toStringAsFixed(1)}% equity'
                              : '';

                          return Text(
                            '• ${e.key}: ${fmtMoney(v)}$overText$pctText',
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),

                    const SizedBox(height: 6),
                    Text(
                      'Suggestion threshold: \$1,000 over the effective cap.',
                      style: theme.textTheme.bodySmall,
                    ),

                    if (ranked.isEmpty)
                      Text(
                        '• No positions with netQuantity + lastPrice found in snapshot.',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            if (!hasSuggestions)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Right now, no symbols stand out as clearly oversized based on your current positions '
                    'and the caps being applied here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else ...[
              Text('Suggested trims', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final s in suggestions)
                _TrimTicketCard(
                  suggestion: s,
                  accountLabel: accountLabel,
                  lastPrice: lastPriceBySymbol[s.symbol],
                ),
            ],
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Important:\n'
                  '• These are mock tickets only.\n'
                  '• AU Insights is read-only and never uses margin.\n'
                  '• You stay fully in control of what you execute in Fidelity.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrimSuggestion {
  final String symbol;
  final double currentDollars;
  final double targetDollars;
  final String rationale;

  const _TrimSuggestion({
    required this.symbol,
    required this.currentDollars,
    required this.targetDollars,
    required this.rationale,
  });

  double get trimDollars => currentDollars - targetDollars;
}

class _TrimTicketCard extends StatelessWidget {
  final _TrimSuggestion suggestion;
  final String accountLabel;

  /// Best-effort last price from shared snapshot positions (may be null).
  final double? lastPrice;

  const _TrimTicketCard({
    required this.suggestion,
    required this.accountLabel,
    this.lastPrice,
  });

  @override
  Widget build(BuildContext context) {
    String fmtMoney(double v) => '\$${v.toStringAsFixed(2)}';
    String fmtQty(double v) => v.toStringAsFixed(3);

    final trim = suggestion.trimDollars;
    // If lastPrice is available, we can compute a LIMIT price + shares suggestion.
    final double? lp = lastPrice;
    final double? limitPx = (lp != null && lp > 0) ? lp : null;
    final double? shares = (limitPx != null && trim > 0)
        ? (trim / limitPx)
        : null;
    final ticket = FidelityTicketFields(
      symbol: suggestion.symbol,
      side: 'SELL',
      accountLabel: accountLabel,
      orderType: (limitPx != null) ? 'LIMIT' : 'MARKET',
      dollarAmount: trim,
      quantityShares: shares,
      limitPrice: limitPx,
      stopPrice: null,
      timeInForce: 'DAY',
      extendedHours: false,
      notes: 'Trim Helper: reduce oversized position. ${suggestion.rationale}',
      lastEdited: 'AUTOFILL',
      editedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    final bool effectiveIsLimit = ticket.effectiveOrderType != 'MARKET';
    final String priceLabel = 'Price';

    final primaryLines = <FidelityTicketLine>[
      FidelityTicketLine('Side', ticket.side),
      FidelityTicketLine('Order type', ticket.effectiveOrderType),
      FidelityTicketLine('Dollars', trim > 0 ? fmtMoney(trim) : '—'),
      FidelityTicketLine(
        'Shares',
        (shares != null && shares > 0) ? fmtQty(shares) : '—',
      ),
      FidelityTicketLine(
        priceLabel,
        ticket.effectivePriceDisplay,
        // Market has no entered price; visually mute that row.
        isMuted: !effectiveIsLimit,
      ),
      FidelityTicketLine('TIF', ticket.timeInForce),
      FidelityTicketLine('Account', ticket.accountLabel),
    ];

    final detailsLines = <FidelityTicketLine>[
      if ((ticket.notes ?? '').trim().isNotEmpty)
        FidelityTicketLine('Notes', ticket.notes!.trim()),
      if ((ticket.lastEdited ?? '').trim().isNotEmpty)
        FidelityTicketLine('Last edited', ticket.lastEdited!.trim()),
      if ((ticket.editedAtIso ?? '').trim().isNotEmpty)
        FidelityTicketLine('Edited at (UTC)', ticket.editedAtIso!.trim(), isMuted: true),
      FidelityTicketLine(
        'Last price (approx)',
        (lp != null && lp > 0) ? fmtMoney(lp) : '—',
        isMuted: true,
      ),
      FidelityTicketLine(
        'Shares basis',
        (lp != null && lp > 0) ? 'shares ≈ dollars ÷ lastPrice' : '—',
        isMuted: true,
      ),
      FidelityTicketLine(
        'Extended hours',
        ticket.extendedHours ? 'Yes' : 'No',
        isMuted: true,
      ),
    ];




final badges = <String>[
      ticket.side,
      ticket.effectiveOrderType,
      ticket.timeInForce,
    ];

    String buildCopyText() {
      final b = StringBuffer();
      b.writeln('Symbol: ${ticket.symbol}');
      b.writeln('Side: ${ticket.side}');
      b.writeln('Order type: ${ticket.effectiveOrderType}');
      b.writeln('Dollars: ${trim > 0 ? fmtMoney(trim) : "—"}');
      b.writeln(
        'Shares: ${(shares != null && shares > 0) ? fmtQty(shares) : "—"}',
      );
      b.writeln('$priceLabel: ${ticket.effectivePriceDisplay}');
      b.writeln('TIF: ${ticket.timeInForce}');
      b.writeln('Account: ${ticket.accountLabel}');
      if ((ticket.notes ?? '').trim().isNotEmpty) {
        b.writeln('Notes: ${ticket.notes!.trim()}');
      }
      if ((ticket.lastEdited ?? '').trim().isNotEmpty) {
        b.writeln('Last edited: ${ticket.lastEdited!.trim()}');
      }
      return b.toString().trimRight();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              suggestion.symbol,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Current approx: ${fmtMoney(suggestion.currentDollars)}\n'
              'Target approx:  ${fmtMoney(suggestion.targetDollars)}\n'
              'Planned trim:   ${fmtMoney(trim)}',
            ),
            const SizedBox(height: 8),
            Text('Rationale: ${suggestion.rationale}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: buildCopyText()));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied mock ticket')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
              ),
            ),
FidelityTicketCard(
              title: '${ticket.symbol} • ${ticket.side}',
              badges: badges,
              lines: primaryLines,
              detailsLines: detailsLines,
              detailsTitle: 'Details',
              detailsInitiallyExpanded: true,
              footnote:
                  'Mock ticket for Fidelity entry only. AU Insights does not place trades.',
            ),
          ],
        ),
      ),
    );
  }
}

String _buildRationale({
  required String symbol,
  required double current,
  required double target,
  required double? equity,
  required double? maxPerSymbol,
  required double? equityCap,
}) {
  final parts = <String>[];

  if (maxPerSymbol != null && current > maxPerSymbol) {
    parts.add('Above per-symbol cap (≈ \$${maxPerSymbol.toStringAsFixed(0)}).');
  }
  if (equityCap != null && current > equityCap) {
    parts.add('Above equity sanity cap (≈ \$${equityCap.toStringAsFixed(0)}).');
  }

  if (equity != null && equity > 0) {
    final currPct = (current / equity) * 100.0;
    final tgtPct = (target / equity) * 100.0;
    parts.add(
      '≈ ${currPct.toStringAsFixed(1)}% of plan equity → ≈ ${tgtPct.toStringAsFixed(1)}%.',
    );
  }

  if (parts.isEmpty) {
    return 'Symbol $symbol is large relative to the snapshot. Trimming keeps risk aligned with guardrails.';
  }
  return '${parts.join(" ")} Trimming helps reduce concentration without exiting completely.';
}
