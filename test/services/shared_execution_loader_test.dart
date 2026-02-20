import 'package:flutter_test/flutter_test.dart';
import 'package:au_core/au_core.dart';

import 'package:au_insights/services/shared_execution_loader.dart';

void main() {
  group('SharedExecutionLoader.buildLiveBlocks', () {
    test('groups by symbol|side and computes matching flags + lastConfirmedAtUtc', () {
      const entries = <ExecutionJournalEntryV1>[
        ExecutionJournalEntryV1(
          version: 1,
          orderId: 'o1',
          planId: 'planA',
          accountId: 'acct1',
          symbol: 'SPY',
          side: 'BUY',
          ticketFingerprint: 'fp1',
          confirmationType: ExecutionJournalEntryV1.kConfirmationExact,
          expectedVisibilityWindow: ExecutionJournalEntryV1.kWindowNextImport,
          confirmedAtUtc: '2026-02-20T01:00:00Z',
        ),
        ExecutionJournalEntryV1(
          version: 1,
          orderId: 'o2',
          planId: 'planA',
          accountId: 'acct1',
          symbol: 'SPY',
          side: 'BUY',
          ticketFingerprint: 'fp2',
          confirmationType: ExecutionJournalEntryV1.kConfirmationExact,
          expectedVisibilityWindow: ExecutionJournalEntryV1.kWindowNextImport,
          confirmedAtUtc: '2026-02-20T02:00:00Z',
        ),
        ExecutionJournalEntryV1(
          version: 1,
          orderId: 'o3',
          planId: 'planB',
          accountId: 'acct1',
          symbol: 'QQQ',
          side: 'SELL',
          ticketFingerprint: 'fp3',
          confirmationType: ExecutionJournalEntryV1.kConfirmationEdited,
          expectedVisibilityWindow:
              ExecutionJournalEntryV1.kWindowNextTradingDay,
          confirmedAtUtc: '2026-02-20T00:30:00Z',
        ),
      ];

      final rows = SharedExecutionLoader.buildLiveBlocks(
        entries: entries,
        activeAccountId: 'acct1',
        planId: 'planA',
        plannedSymbolSides: <String>{'SPY|BUY'},
      );

      expect(rows.length, 2);

      final spy = rows.firstWhere((r) => r.symbol == 'SPY');
      expect(spy.side, 'BUY');
      expect(spy.entryCount, 2);
      expect(spy.uniqueOrderCount, 2);
      expect(spy.matchesPlannedBlock, isTrue);
      expect(spy.matchesPlanId, isTrue);
      expect(spy.matchesActiveAccount, isTrue);
      expect(spy.lastConfirmedAtUtc, '2026-02-20T02:00:00Z');

      final qqq = rows.firstWhere((r) => r.symbol == 'QQQ');
      expect(qqq.side, 'SELL');
      expect(qqq.entryCount, 1);
      expect(qqq.uniqueOrderCount, 1);
      expect(qqq.matchesPlannedBlock, isFalse);
      expect(qqq.matchesPlanId, isFalse); // planB != planA
      expect(qqq.matchesActiveAccount, isTrue);
      expect(qqq.lastConfirmedAtUtc, '2026-02-20T00:30:00Z');
    });

    test('stable sort: planned blocks first, then symbol, then side', () {
      const entries = <ExecutionJournalEntryV1>[
        ExecutionJournalEntryV1(
          version: 1,
          orderId: 'o1',
          planId: 'p',
          accountId: 'a',
          symbol: 'ZZZ',
          side: 'BUY',
          ticketFingerprint: 'fp1',
          confirmationType: ExecutionJournalEntryV1.kConfirmationExact,
          expectedVisibilityWindow: ExecutionJournalEntryV1.kWindowNextImport,
        ),
        ExecutionJournalEntryV1(
          version: 1,
          orderId: 'o2',
          planId: 'p',
          accountId: 'a',
          symbol: 'AAA',
          side: 'SELL',
          ticketFingerprint: 'fp2',
          confirmationType: ExecutionJournalEntryV1.kConfirmationExact,
          expectedVisibilityWindow: ExecutionJournalEntryV1.kWindowNextImport,
        ),
        ExecutionJournalEntryV1(
          version: 1,
          orderId: 'o3',
          planId: 'p',
          accountId: 'a',
          symbol: 'AAA',
          side: 'BUY',
          ticketFingerprint: 'fp3',
          confirmationType: ExecutionJournalEntryV1.kConfirmationExact,
          expectedVisibilityWindow: ExecutionJournalEntryV1.kWindowNextImport,
        ),
      ];

      final rows = SharedExecutionLoader.buildLiveBlocks(
        entries: entries,
        activeAccountId: 'a',
        planId: 'p',
        plannedSymbolSides: <String>{'ZZZ|BUY'},
      );

      // Planned (ZZZ|BUY) first.
      expect(rows.first.symbol, 'ZZZ');
      expect(rows.first.side, 'BUY');

      // Remaining sorted by symbol then side.
      expect(rows[1].symbol, 'AAA');
      expect(rows[2].symbol, 'AAA');
      expect(rows[1].side.compareTo(rows[2].side) <= 0, isTrue);
    });
  });
}
