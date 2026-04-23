import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/models/transaction.dart';
import 'package:ocr_app/providers/transaction_provider.dart';
import 'package:ocr_app/repositories/transaction_repository.dart';

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
  });
}
