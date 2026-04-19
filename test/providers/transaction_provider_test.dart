import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/models/transaction.dart';
import 'package:ocr_app/providers/transaction_provider.dart';

void main() {
  group('TransactionProvider', () {
    late TransactionProvider provider;

    setUp(() {
      provider = TransactionProvider();
    });

    test('should start with empty transaction list', () {
      expect(provider.transactions, isEmpty);
    });

    test('should add transaction', () {
      final transaction = Transaction(
        id: '1',
        merchantName: 'Store A',
        totalAmount: 50.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      provider.addTransaction(transaction);

      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.id, '1');
      expect(provider.transactions.first.merchantName, 'Store A');
    });

    test('should update existing transaction', () {
      final transaction = Transaction(
        id: '2',
        merchantName: 'Store B',
        totalAmount: 100.0,
        date: DateTime(2026, 4, 18),
        paymentMethod: 'Card',
      );

      provider.addTransaction(transaction);

      final updated = transaction.copyWith(
        merchantName: 'Updated Store B',
        totalAmount: 150.0,
      );

      provider.updateTransaction(updated);

      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.merchantName, 'Updated Store B');
      expect(provider.transactions.first.totalAmount, 150.0);
    });

    test('should delete transaction by id', () {
      final transaction1 = Transaction(
        id: '3',
        merchantName: 'Store C',
        totalAmount: 75.0,
        date: DateTime(2026, 4, 17),
        paymentMethod: 'Cash',
      );

      final transaction2 = Transaction(
        id: '4',
        merchantName: 'Store D',
        totalAmount: 125.0,
        date: DateTime(2026, 4, 16),
        paymentMethod: 'Mobile Banking',
      );

      provider.addTransaction(transaction1);
      provider.addTransaction(transaction2);

      expect(provider.transactions.length, 2);

      provider.deleteTransaction('3');

      expect(provider.transactions.length, 1);
      expect(provider.transactions.first.id, '4');
    });

    test('should return transactions in reverse chronological order', () {
      final older = Transaction(
        id: '5',
        merchantName: 'Old Store',
        totalAmount: 50.0,
        date: DateTime(2026, 4, 10),
        paymentMethod: 'Cash',
      );

      final newer = Transaction(
        id: '6',
        merchantName: 'New Store',
        totalAmount: 75.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Card',
      );

      provider.addTransaction(older);
      provider.addTransaction(newer);

      expect(provider.transactions.first.id, '6');
      expect(provider.transactions.last.id, '5');
    });
  });
}
