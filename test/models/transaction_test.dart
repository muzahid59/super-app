import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/models/transaction.dart';

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

    test('toMap should serialize all fields', () {
      final date = DateTime(2026, 4, 19, 10, 30);
      final transaction = Transaction(
        id: 'abc-123',
        merchantName: 'Star Kabab',
        totalAmount: 450.75,
        date: date,
        paymentMethod: 'Card',
        taxAmount: 22.5,
        imagePath: '/local/receipt.jpg',
      );

      final map = transaction.toMap();

      expect(map['merchantName'], 'Star Kabab');
      expect(map['totalAmount'], 450.75);
      expect(map['date'], date);
      expect(map['paymentMethod'], 'Card');
      expect(map['taxAmount'], 22.5);
      expect(map['imagePath'], '/local/receipt.jpg');
      expect(map.containsKey('id'), false);
    });

    test('toMap should exclude null optional fields', () {
      final transaction = Transaction(
        id: 'abc-123',
        merchantName: 'Store',
        totalAmount: 100.0,
        date: DateTime(2026, 4, 19),
        paymentMethod: 'Cash',
      );

      final map = transaction.toMap();

      expect(map.containsKey('taxAmount'), false);
      expect(map.containsKey('imagePath'), false);
    });

    test('fromMap should deserialize all fields', () {
      final date = DateTime(2026, 4, 19, 10, 30);
      final map = {
        'merchantName': 'Star Kabab',
        'totalAmount': 450.75,
        'date': date,
        'paymentMethod': 'Card',
        'taxAmount': 22.5,
        'imagePath': '/local/receipt.jpg',
      };

      final transaction = Transaction.fromMap('abc-123', map);

      expect(transaction.id, 'abc-123');
      expect(transaction.merchantName, 'Star Kabab');
      expect(transaction.totalAmount, 450.75);
      expect(transaction.date, date);
      expect(transaction.paymentMethod, 'Card');
      expect(transaction.taxAmount, 22.5);
      expect(transaction.imagePath, '/local/receipt.jpg');
    });

    test('fromMap should handle null optional fields', () {
      final map = {
        'merchantName': 'Store',
        'totalAmount': 100.0,
        'date': DateTime(2026, 4, 19),
        'paymentMethod': 'Cash',
      };

      final transaction = Transaction.fromMap('xyz-789', map);

      expect(transaction.taxAmount, null);
      expect(transaction.imagePath, null);
    });

    test('fromMap should handle Timestamp date field', () {
      final date = DateTime(2026, 4, 19);
      final map = {
        'merchantName': 'Store',
        'totalAmount': 100.0,
        'date': date,
        'paymentMethod': 'Cash',
      };

      final transaction = Transaction.fromMap('id-1', map);

      expect(transaction.date, date);
    });
  });
}
