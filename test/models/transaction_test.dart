import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/models/transaction.dart';

void main() {
  group('Transaction Model', () {
    test('should create transaction with required fields', () {
      final transaction = Transaction(
        id: '123',
        merchantName: 'Test Store',
        totalAmount: 100.50,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      expect(transaction.id, '123');
      expect(transaction.merchantName, 'Test Store');
      expect(transaction.totalAmount, 100.50);
      expect(transaction.date, DateTime(2026, 4, 19));
      expect(transaction.paymentMethod, 'Cash');
      expect(transaction.taxAmount, null);
      expect(transaction.imagePath, null);
    });

    test('should create transaction with optional fields', () {
      final transaction = Transaction(
        id: '456',
        merchantName: 'Store 2',
        totalAmount: 200.0,
        date: DateTime(2026, 4, 18),
        paymentMethod: 'Card',
        taxAmount: 20.0,
        imagePath: '/path/to/image.jpg',
      );

      expect(transaction.taxAmount, 20.0);
      expect(transaction.imagePath, '/path/to/image.jpg');
    });

    test('should create copy with updated values', () {
      final original = Transaction(
        id: '789',
        merchantName: 'Original',
        totalAmount: 50.0,
        date: DateTime(2026, 4, 17),
        paymentMethod: 'Cash',
      );

      final updated = original.copyWith(
        merchantName: 'Updated Store',
        totalAmount: 75.0,
      );

      expect(updated.id, '789');
      expect(updated.merchantName, 'Updated Store');
      expect(updated.totalAmount, 75.0);
      expect(updated.date, DateTime(2026, 4, 17));
      expect(updated.paymentMethod, 'Cash');
    });

    test('should be equal when ids match', () {
      final transaction1 = Transaction(
        id: '123',
        merchantName: 'Store A',
        totalAmount: 100.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      final transaction2 = Transaction(
        id: '123',
        merchantName: 'Store B', // Different data
        totalAmount: 200.0,
        date: DateTime(2026, 4, 18),
        paymentMethod: 'Card',
      );

      expect(transaction1, equals(transaction2));
      expect(transaction1.hashCode, equals(transaction2.hashCode));
    });

    test('should not be equal when ids differ', () {
      final transaction1 = Transaction(
        id: '123',
        merchantName: 'Same Store',
        totalAmount: 100.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      final transaction2 = Transaction(
        id: '456',
        merchantName: 'Same Store',
        totalAmount: 100.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      expect(transaction1, isNot(equals(transaction2)));
    });

    test('should have consistent toString output', () {
      final transaction = Transaction(
        id: '123',
        merchantName: 'Test Store',
        totalAmount: 100.50,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      expect(
        transaction.toString(),
        contains('Transaction(id: 123'),
      );
      expect(
        transaction.toString(),
        contains('merchantName: Test Store'),
      );
    });
  });
}
