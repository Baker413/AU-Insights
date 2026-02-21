import 'dart:io';

import 'package:flutter/material.dart';

class PlanSelectionBanner extends StatelessWidget {
  final String? selectionReason;
  final String? selectedPlanPath;

  const PlanSelectionBanner({
    super.key,
    required this.selectionReason,
    required this.selectedPlanPath,
  });

  static String _baseName(String? p) {
    final v = (p ?? '').trim();
    if (v.isEmpty) return '';
    return v.split(Platform.pathSeparator).last;
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Plan selection'),
          content: const SingleChildScrollView(
            child: Text(
              'AU Insights shows how the shared plan file was selected.\n\n'
              'ACTIVE PLAN\n'
              '• Selected by active-account pointer (the intended, stable selection).\n\n'
              'DRAFT / ALT PLAN\n'
              '• Selected by newest per-account scan when no active pointer exists.\n\n'
              'DRAFT / ALT (LEGACY)\n'
              '• Selected by legacy fallback logic for older artifacts.\n\n'
              'NO PLAN\n'
              '• The locator did not select any shared plan file.\n\n'
              'UNKNOWN\n'
              '• The token is not recognized by this UI (may indicate version drift).',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final reason = (selectionReason ?? '').trim();
    final fileName = _baseName(selectedPlanPath);

    String title;
    String subtitle;
    String actionLine = '';
    IconData icon;
    Color bg;
    Color fg;

    // Contract truth (au_core SharedPlanLocatorV1):
    // - activeAccountPointer = ACTIVE
    // - newestPerAccountScan / legacyFallback = ALT/DRAFT-like selection
    // - none/unknown = no plan / drift
    if (reason == 'activeAccountPointer') {
      title = 'ACTIVE PLAN';
      subtitle = 'Selected by active-account pointer.';
      actionLine = 'Action: none (this is the intended, stable selection).';
      icon = Icons.verified_rounded;
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
    } else if (reason == 'newestPerAccountScan') {
      title = 'DRAFT / ALT PLAN';
      subtitle = 'Selected by newest per-account scan (no active pointer).';
      actionLine = 'Action: set an active account in IQ Pro to lock selection.';
      icon = Icons.history_rounded;
      bg = cs.secondaryContainer;
      fg = cs.onSecondaryContainer;
    } else if (reason == 'legacyFallback') {
      title = 'DRAFT / ALT PLAN (LEGACY)';
      subtitle = 'Selected by legacy fallback.';
      actionLine = 'Action: consider regenerating the shared plan (reduce legacy drift).';
      icon = Icons.inventory_2_rounded;
      bg = cs.tertiaryContainer;
      fg = cs.onTertiaryContainer;
    } else if (reason == 'none' || reason.isEmpty) {
      title = 'NO PLAN SELECTED';
      subtitle = 'No shared plan file was selected by the locator.';
      actionLine = 'Action: generate a plan in IQ Pro (or verify App Group artifacts).';
      icon = Icons.remove_circle_outline_rounded;
      bg = cs.errorContainer;
      fg = cs.onErrorContainer;
    } else {
      title = 'PLAN SELECTION (UNKNOWN)';
      subtitle = 'Selection reason token is not recognized by this UI.';
      actionLine = 'Action: update apps together (likely version drift).';
      icon = Icons.help_outline_rounded;
      bg = cs.surfaceContainerHighest;
      fg = cs.onSurface;
    }

    final metaBits = <String>[];
    if (reason.isNotEmpty) metaBits.add('Reason: $reason');
    if (fileName.isNotEmpty) metaBits.add('File: $fileName');

    final metaLine = metaBits.join(' • ');

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'What is this?',
                  onPressed: () => _showHelp(context),
                  icon: const Icon(Icons.info_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodySmall),
            if (actionLine.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(actionLine, style: theme.textTheme.bodySmall),
            ],
            if (metaLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(metaLine, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
