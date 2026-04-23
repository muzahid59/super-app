import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/models/filter_state.dart';
import 'package:superapp/models/transaction.dart';
import 'package:superapp/providers/transaction_provider.dart';
import 'package:superapp/repositories/transaction_repository.dart';

class MockTransactionRepository implements TransactionRepository {
  final _controller = StreamController<List<Transaction>>.broadcast();
  final List<Map<String, dynamic>> calls = [];

  void emitTransactions(List<Transaction> transactions) {
    _controller.add(transactions);
  }

  @override
  Stream<List<Transaction>> watchTransactions(String uid) {
    calls.add({'method': 'watchTransactions', 'uid': uid});
    return _controller.stream;
  }

  @override
  Future<void> addTransaction(String uid, Transaction transaction) async {
    calls.add({'method': 'addTransaction', 'uid': uid, 'transaction': transaction});
  }

  @override
  Future<void> updateTransaction(String uid, Transaction transaction) async {
    calls.add({'method': 'updateTransaction', 'uid': uid, 'transaction': transaction});
  }

  @override
  Future<void> deleteTransaction(String uid, String transactionId) async {
    calls.add({'method': 'deleteTransaction', 'uid': uid, 'transactionId': transactionId});
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('TransactionProvider', () {
    late TransactionProvider provider;
    late MockTransactionRepository mockRepo;

    setUp(() {
      mockRepo = MockTransactionRepository();
      provider = TransactionProvider(repository: mockRepo);
    });

    tearDown(() {
      mockRepo.dispose();
    });

    test('should start with empty transaction list', () {
      expect(provider.transactions, isEmpty);
    });

    test('setUser should subscribe to watchTransactions stream', () {
      provider.setUser('user-123');

      expect(mockRepo.calls.length, 1);
      expect(mockRepo.calls.first['method'], 'watchTransactions');
      expect(mockRepo.calls.first['uid'], 'user-123');
    });

    test('should update transactions when stream emits', () async {
      provider.setUser('user-123');

      final transactions = [
        Transaction(
          id: '1',
          merchantName: 'Store A',
          totalAmount: 50.0,
          date: DateTime(2026, 4, 19),
          paymentMethod: 'Cash',
        ),
      ];

      mockRepo.emitTransactions(transactions);
      await Future.delayed(Duration.zero);

      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.merchantName, 'Store A');
    });

    test('addTransaction should delegate to repository with uid', () async {
      provider.setUser('user-123');

      final transaction = Transaction(
        id: '1',
        merchantName: 'Store A',
        totalAmount: 50.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      await provider.addTransaction(transaction);

      final addCall = mockRepo.calls.firstWhere((c) => c['method'] == 'addTransaction');
      expect(addCall['uid'], 'user-123');
      expect((addCall['transaction'] as Transaction).id, '1');
    });

    test('updateTransaction should delegate to repository with uid', () async {
      provider.setUser('user-123');

      final transaction = Transaction(
        id: '1',
        merchantName: 'Updated Store',
        totalAmount: 75.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Card',
      );

      await provider.updateTransaction(transaction);

      final updateCall = mockRepo.calls.firstWhere((c) => c['method'] == 'updateTransaction');
      expect(updateCall['uid'], 'user-123');
      expect((updateCall['transaction'] as Transaction).merchantName, 'Updated Store');
    });

    test('deleteTransaction should delegate to repository with uid', () async {
      provider.setUser('user-123');

      await provider.deleteTransaction('tx-1');

      final deleteCall = mockRepo.calls.firstWhere((c) => c['method'] == 'deleteTransaction');
      expect(deleteCall['uid'], 'user-123');
      expect(deleteCall['transactionId'], 'tx-1');
    });

    test('clearUser should clear transactions and cancel stream', () async {
      provider.setUser('user-123');

      mockRepo.emitTransactions([
        Transaction(
          id: '1',
          merchantName: 'Store',
          totalAmount: 50.0,
          date: DateTime(2026, 4, 19),
          paymentMethod: 'Cash',
        ),
      ]);
      await Future.delayed(Duration.zero);

      expect(provider.transactions.length, 1);

      provider.clearUser();

      expect(provider.transactions, isEmpty);
    });

    test('setUser twice should cancel previous stream subscription', () {
      provider.setUser('user-111');
      provider.setUser('user-222');

      final watchCalls = mockRepo.calls.where((c) => c['method'] == 'watchTransactions').toList();
      expect(watchCalls.length, 2);
      expect(watchCalls[0]['uid'], 'user-111');
      expect(watchCalls[1]['uid'], 'user-222');
    });

    test('setUser with same uid should not resubscribe', () {
      provider.setUser('user-123');
      provider.setUser('user-123');

      final watchCalls = mockRepo.calls.where((c) => c['method'] == 'watchTransactions').toList();
      expect(watchCalls.length, 1);
    });

    test('clearUser when already cleared should be no-op', () async {
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearUser();

      expect(notifyCount, 0);
    });

    test('addTransaction should throw if no user set', () {
      final transaction = Transaction(
        id: '1',
        merchantName: 'Store',
        totalAmount: 50.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      expect(
        () => provider.addTransaction(transaction),
        throwsStateError,
      );
    });

    group('filtering', () {
      final transactions = [
        Transaction(
          id: '1',
          merchantName: 'Super Market',
          totalAmount: 250.0,
          date: DateTime(2026, 4, 20),
          paymentMethod: 'Cash',
        ),
        Transaction(
          id: '2',
          merchantName: 'City Hospital',
          totalAmount: 1500.0,
          date: DateTime(2026, 4, 15),
          paymentMethod: 'Card',
        ),
        Transaction(
          id: '3',
          merchantName: 'Mobile Store',
          totalAmount: 8000.0,
          date: DateTime(2026, 3, 10),
          paymentMethod: 'Mobile Banking',
        ),
        Transaction(
          id: '4',
          merchantName: 'Super Shop',
          totalAmount: 750.0,
          date: DateTime(2026, 4, 1),
          paymentMethod: 'Cash',
        ),
      ];

      setUp(() {
        provider.setUser('user-123');
        mockRepo.emitTransactions(transactions);
      });

      test('filteredTransactions returns all when no filters active', () async {
        await Future.delayed(Duration.zero);

        expect(provider.filteredTransactions.length, 4);
      });

      test('setSearchQuery filters by merchant name case-insensitive', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');

        expect(provider.filteredTransactions.length, 2);
        expect(provider.filteredTransactions[0].merchantName, 'Super Market');
        expect(provider.filteredTransactions[1].merchantName, 'Super Shop');
      });

      test('setSearchQuery with empty string shows all', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');
        provider.setSearchQuery('');

        expect(provider.filteredTransactions.length, 4);
      });

      test('togglePaymentMethod adds and removes from set', () async {
        await Future.delayed(Duration.zero);

        provider.togglePaymentMethod('Cash');
        expect(provider.filteredTransactions.length, 2);

        provider.togglePaymentMethod('Card');
        expect(provider.filteredTransactions.length, 3);

        provider.togglePaymentMethod('Cash');
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.paymentMethod, 'Card');
      });

      test('setAmountRange filters by amount range', () async {
        await Future.delayed(Duration.zero);

        provider.setAmountRange(AmountRange.under500);
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.merchantName, 'Super Market');

        provider.setAmountRange(AmountRange.above5000);
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.merchantName, 'Mobile Store');
      });

      test('setAmountRange with null clears amount filter', () async {
        await Future.delayed(Duration.zero);

        provider.setAmountRange(AmountRange.under500);
        expect(provider.filteredTransactions.length, 1);

        provider.setAmountRange(null);
        expect(provider.filteredTransactions.length, 4);
      });

      test('setDateRange filters by date range inclusive', () async {
        await Future.delayed(Duration.zero);

        provider.setDateRange(DateTime(2026, 4, 1), DateTime(2026, 4, 20));

        expect(provider.filteredTransactions.length, 3);
        expect(
          provider.filteredTransactions.every((t) =>
            !t.date.isBefore(DateTime(2026, 4, 1)) &&
            !t.date.isAfter(DateTime(2026, 4, 20))),
          isTrue,
        );
      });

      test('setDateRange with nulls clears date filter', () async {
        await Future.delayed(Duration.zero);

        provider.setDateRange(DateTime(2026, 4, 15), DateTime(2026, 4, 20));
        expect(provider.filteredTransactions.length, 2);

        provider.setDateRange(null, null);
        expect(provider.filteredTransactions.length, 4);
      });

      test('filters combine with AND logic', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');
        provider.togglePaymentMethod('Cash');

        expect(provider.filteredTransactions.length, 2);
        expect(provider.filteredTransactions[0].merchantName, 'Super Market');
        expect(provider.filteredTransactions[1].merchantName, 'Super Shop');

        provider.setAmountRange(AmountRange.under500);

        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.merchantName, 'Super Market');
      });

      test('clearFilters resets all filters', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');
        provider.togglePaymentMethod('Cash');
        provider.setAmountRange(AmountRange.under500);
        provider.setDateRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30));

        provider.clearFilters();

        expect(provider.filteredTransactions.length, 4);
        expect(provider.filterState.searchQuery, '');
        expect(provider.filterState.paymentMethods, isEmpty);
        expect(provider.filterState.amountRange, isNull);
        expect(provider.filterState.dateRange, isNull);
      });

      test('hasActiveFilters reflects filter state', () async {
        await Future.delayed(Duration.zero);

        expect(provider.hasActiveFilters, isFalse);

        provider.setSearchQuery('test');
        expect(provider.hasActiveFilters, isTrue);

        provider.clearFilters();
        expect(provider.hasActiveFilters, isFalse);
      });

      test('activeFilterCount counts active categories', () async {
        await Future.delayed(Duration.zero);

        expect(provider.activeFilterCount, 0);

        provider.setSearchQuery('test');
        expect(provider.activeFilterCount, 1);

        provider.togglePaymentMethod('Cash');
        expect(provider.activeFilterCount, 2);

        provider.setAmountRange(AmountRange.under500);
        expect(provider.activeFilterCount, 3);

        provider.setDateRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30));
        expect(provider.activeFilterCount, 4);
      });

      test('clearUser also resets filters', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('test');
        provider.togglePaymentMethod('Cash');

        provider.clearUser();

        expect(provider.hasActiveFilters, isFalse);
        expect(provider.filteredTransactions, isEmpty);
      });
    });
  });
}
