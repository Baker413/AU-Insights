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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final reason = (selectionReason ?? '').trim();
    final fileName = _baseName(selectedPlanPath);

    String title;
    String subtitle;

    // Contract truth (au_core SharedPlanLocatorV1):
    // - activeAccountPointer = ACTIVE
    // - newestPerAccountScan / legacyFallback = ALT/DRAFT-like selection
    // - none/unknown = no plan
    if (reason == 'activeAccountPointer') {
      title = 'ACTIVE PLAN';
      subtitle = 'Selected by active-account pointer.';
    } else if (reason == 'newestPerAccountScan') {
      title = 'DRAFT / ALT PLAN';
      subtitle = 'Selected by newest per-account scan (no active pointer).';
    } else if (reason == 'legacyFallback') {
      title = 'DRAFT / ALT PLAN (LEGACY)';
      subtitle = 'Selected by legacy fallback.';
    } else if (reason == 'none' || reason.isEmpty) {
      title = 'NO PLAN SELECTED';
      subtitle = 'No shared plan file was selected by the locator.';
    } else {
      title = 'PLAN SELECTION (UNKNOWN)';
      subtitle = 'Selection reason token is not recognized by this UI.';
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
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(subtitle, style: theme.textTheme.bodySmall),
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
