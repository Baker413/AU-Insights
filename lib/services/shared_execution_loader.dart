import 'dart:convert';
import 'dart:io';

import 'package:au_core/au_core.dart';
import 'package:flutter/foundation.dart';

import '../shared/storage.dart';

class LiveBlockRow {
  final String symbol;
  final String side; // e.g. 'BUY' / 'SELL'
  final int entryCount;
  final int uniqueOrderCount;
  final String? lastConfirmedAtUtc;
  final bool matchesPlanId;
  final bool matchesActiveAccount;
  final bool matchesPlannedBlock;

  /// True if this (symbol|side) is known to be a legacy-origin governed block.
  ///
  /// AU Insights uses this only for clear UI labeling (e.g., a "LEGACY" pill),
  /// not for gating or behavior changes.
  final bool isLegacyOrigin;

  const LiveBlockRow({
    required this.symbol,
    required this.side,
    required this.entryCount,
    required this.uniqueOrderCount,
    required this.lastConfirmedAtUtc,
    required this.matchesPlanId,
    required this.matchesActiveAccount,
    required this.matchesPlannedBlock,
    required this.isLegacyOrigin,
  });
}

class SharedExecutionLoaderResult {
  final List<LiveBlockRow> liveBlocks;

  /// Count of contract-valid ExecutionJournalEntryV1 items seen (best-effort).
  final int journalEntryCount;

  /// Count of contract-valid legacy ExecutionReceiptV1 items seen (best-effort).
  final int legacyReceiptCount;

  /// Active account id (from SharedActiveAccountV1 pointer), if present.
  final String? activeAccountId;

  const SharedExecutionLoaderResult({
    required this.liveBlocks,
    required this.journalEntryCount,
    required this.legacyReceiptCount,
    required this.activeAccountId,
  });
}

/// AU Insights loader for execution artifacts written to the shared App Group.
///
/// Goals (platinum):
/// - Read-only, best-effort: never throw to UI.
/// - Prefer per-account journal when active-account pointer exists.
/// - Produce deterministic, UI-friendly rows grouped by (symbol, side).
class SharedExecutionLoader {
  static const String _legacyReceiptsFileName = 'executions_v1.json';
  static const String _legacyJournalFileName = 'execution_journal_v1.json';

  static String _safeAccountId(String accountId) =>
      SharedPlanLocatorV1.safeAccountId(accountId);

  static String _receiptsFileNameForAccount(String accountId) =>
      'executions_v1_${_safeAccountId(accountId)}.json';

  static String _journalFileNameForAccount(String accountId) =>
      'execution_journal_v1_${_safeAccountId(accountId)}.json';

  Future<String?> _getBasePath() async {
    final basePath = await SharedStorage.getAppGroupPath();
    if (basePath == null || basePath.trim().isEmpty) return null;
    return basePath;
  }

  Future<String?> _loadActiveAccountIdOrNull(String basePath) async {
    try {
      final f = File('$basePath/${SharedActiveAccountV1.kFileName}');
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      final parsed = SharedActiveAccountV1.tryParseJsonText(text);
      if (parsed == null) return null;
      final aid = parsed.activeAccountId.trim();
      return aid.isEmpty ? null : aid;
    } catch (e, st) {
      debugPrint('SharedExecutionLoader: active-account read failed: $e\n$st');
      return null;
    }
  }

  Future<List<Map<String, Object?>>> _readJsonListFileOrEmpty(File f) async {
    if (!await f.exists()) return const <Map<String, Object?>>[];
    try {
      final decoded = json.decode(await f.readAsString());
      if (decoded is! List) return const <Map<String, Object?>>[];
      final out = <Map<String, Object?>>[];
      for (final item in decoded) {
        if (item is Map<String, Object?>) {
          out.add(item);
        } else if (item is Map) {
          out.add(Map<String, Object?>.from(item));
        }
      }
      return out.isEmpty ? const <Map<String, Object?>>[] : out;
    } catch (_) {
      return const <Map<String, Object?>>[];
    }
  }

  Future<List<ExecutionJournalEntryV1>> _loadJournalEntriesBestEffort({
    required String basePath,
    required String? activeAccountId,
  }) async {
    File? file;

    // Per-account preferred if pointer exists; otherwise fall back to legacy.
    final aid = (activeAccountId ?? '').trim();
    if (aid.isNotEmpty) {
      final per = File('$basePath/${_journalFileNameForAccount(aid)}');
      if (await per.exists()) file = per;
    }
    file ??= File('$basePath/$_legacyJournalFileName');

    final raw = await _readJsonListFileOrEmpty(file);
    if (raw.isEmpty) return const <ExecutionJournalEntryV1>[];

    final out = <ExecutionJournalEntryV1>[];
    for (final item in raw) {
      try {
        final v = ExecutionJournalEntryV1.fromJson(
          Map<String, dynamic>.from(item),
        );
        out.add(v);
      } catch (_) {
        // Best-effort: skip invalid entries silently.
      }
    }
    return out.isEmpty ? const <ExecutionJournalEntryV1>[] : out;
  }

  Future<int> _loadLegacyReceiptsCountBestEffort({
    required String basePath,
    required String? activeAccountId,
  }) async {
    File? file;

    final aid = (activeAccountId ?? '').trim();
    if (aid.isNotEmpty) {
      final per = File('$basePath/${_receiptsFileNameForAccount(aid)}');
      if (await per.exists()) file = per;
    }
    file ??= File('$basePath/$_legacyReceiptsFileName');

    final raw = await _readJsonListFileOrEmpty(file);
    if (raw.isEmpty) return 0;

    int count = 0;
    for (final item in raw) {
      try {
        // Parse validates contract; failures are skipped.
        ExecutionReceiptV1.fromJson(Map<String, dynamic>.from(item));
        count += 1;
      } catch (_) {}
    }
    return count;
  }

  @visibleForTesting
  static List<LiveBlockRow> buildLiveBlocks({
    required List<ExecutionJournalEntryV1> entries,
    required String? activeAccountId,
    required String? planId,
    required Set<String> plannedSymbolSides, // e.g. {"SPY|BUY"}
    required Set<String> legacySymbolSides, // e.g. {"SPY|BUY"} where origin=legacy
  }) {
    return _buildRows(
      entries: entries,
      activeAccountId: activeAccountId,
      planId: planId,
      plannedSymbolSides: plannedSymbolSides.toList(growable: false),
      legacySymbolSides: legacySymbolSides.toList(growable: false),
    );
  }

  Future<SharedExecutionLoaderResult> loadForPlan({
    required String? planId,
    required List<String> plannedSymbolSides, // e.g. ["SPY|BUY"]
        List<String> legacySymbolSides = const <String>[], // e.g. ["SPY|BUY"] where origin=legacy
  }) async {
    try {
      final basePath = await _getBasePath();
      if (basePath == null) {
        return const SharedExecutionLoaderResult(
          liveBlocks: <LiveBlockRow>[],
          journalEntryCount: 0,
          legacyReceiptCount: 0,
          activeAccountId: null,
        );
      }

      final activeAccountId = await _loadActiveAccountIdOrNull(basePath);

      final entries = await _loadJournalEntriesBestEffort(
        basePath: basePath,
        activeAccountId: activeAccountId,
      );

      final legacyReceiptsCount = await _loadLegacyReceiptsCountBestEffort(
        basePath: basePath,
        activeAccountId: activeAccountId,
      );

      final rows = _buildRows(
        entries: entries,
        activeAccountId: activeAccountId,
        planId: planId,
        plannedSymbolSides: plannedSymbolSides,
        legacySymbolSides: legacySymbolSides,
      );

      return SharedExecutionLoaderResult(
        liveBlocks: rows,
        journalEntryCount: entries.length,
        legacyReceiptCount: legacyReceiptsCount,
        activeAccountId: activeAccountId,
      );
    } catch (e, st) {
      debugPrint('SharedExecutionLoader: load failed: $e\n$st');
      return const SharedExecutionLoaderResult(
        liveBlocks: <LiveBlockRow>[],
        journalEntryCount: 0,
        legacyReceiptCount: 0,
        activeAccountId: null,
      );
    }
  }

  static List<LiveBlockRow> _buildRows({
    required List<ExecutionJournalEntryV1> entries,
    required String? activeAccountId,
    required String? planId,
    required List<String> plannedSymbolSides,
    required List<String> legacySymbolSides,
  }) {
    final aid = (activeAccountId ?? '').trim();
    final pid = (planId ?? '').trim();
    final planned = plannedSymbolSides
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final legacy = legacySymbolSides
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final Map<String, List<ExecutionJournalEntryV1>> groups =
        <String, List<ExecutionJournalEntryV1>>{};
    for (final e in entries) {
      final sym = e.symbol.trim().toUpperCase();
      final side = e.side.trim().toUpperCase();
      if (sym.isEmpty || side.isEmpty) continue;
      final k = '$sym|$side';
      groups.putIfAbsent(k, () => <ExecutionJournalEntryV1>[]).add(e);
    }

    final out = <LiveBlockRow>[];
    for (final kv in groups.entries) {
      final k = kv.key;
      final items = kv.value;

      final parts = k.split('|');
      final sym = parts.isNotEmpty ? parts[0] : '';
      final side = (parts.length >= 2) ? parts[1] : '';

      final uniqueOrders = <String>{};
      String? lastConfirmed;
      bool planMatch = false;
      bool accountMatch = false;

      for (final e in items) {
        uniqueOrders.add(e.orderId.trim());

        final c = (e.confirmedAtUtc ?? '').trim();
        if (c.isNotEmpty) {
          // ISO-8601 UTC timestamps compare lexicographically.
          if (lastConfirmed == null || c.compareTo(lastConfirmed) > 0) {
            lastConfirmed = c;
          }
        }

        if (pid.isNotEmpty && e.planId.trim() == pid) {
          planMatch = true;
        }
        if (aid.isNotEmpty && e.accountId.trim() == aid) {
          accountMatch = true;
        }
      }

      out.add(
        LiveBlockRow(
          symbol: sym,
          side: side,
          entryCount: items.length,
          uniqueOrderCount: uniqueOrders.length,
          lastConfirmedAtUtc: lastConfirmed,
          matchesPlanId: pid.isEmpty ? true : planMatch,
          matchesActiveAccount: aid.isEmpty ? true : accountMatch,
          matchesPlannedBlock: planned.contains(k),
          isLegacyOrigin: legacy.contains(k),
        ),
      );
    }

    // Stable sort: matched planned first, then symbol, then side.
    out.sort((a, b) {
      final ap = a.matchesPlannedBlock ? 0 : 1;
      final bp = b.matchesPlannedBlock ? 0 : 1;
      if (ap != bp) return ap - bp;
      final s = a.symbol.compareTo(b.symbol);
      if (s != 0) return s;
      return a.side.compareTo(b.side);
    });

    return out;
  }
}
