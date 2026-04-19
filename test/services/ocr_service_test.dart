import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/services/ocr_service.dart';

void main() {
  group('OCRService', () {
    test('should extract merchant name from text', () {
      const text = 'Super Market Ltd\n123 Main St\nTotal: 150.00';

      final merchantName = OCRService.extractMerchantName(text);

      expect(merchantName, 'Super Market Ltd');
    });

    test('should extract total amount with "total" keyword', () {
      const text = 'Store Name\nTotal: 250.50\nThank you';

      final amount = OCRService.extractTotalAmount(text);

      expect(amount, 250.50);
    });

    test('should extract total amount with Bangla keyword', () {
      const text = 'দোকানের নাম\nমোট: ৫০০.০০\nধন্যবাদ';

      final amount = OCRService.extractTotalAmount(text);

      expect(amount, 500.00);
    });

    test('should extract largest number as fallback', () {
      const text = 'Store\n10.00\n20.00\n500.00\n5.00';

      final amount = OCRService.extractTotalAmount(text);

      expect(amount, 500.00);
    });

    test('should extract tax amount with "vat" keyword', () {
      const text = 'Total: 100.00\nVAT: 15.00';

      final tax = OCRService.extractTaxAmount(text);

      expect(tax, 15.00);
    });

    test('should extract tax amount with Bangla keyword', () {
      const text = 'মোট: 200.00\nভ্যাট: 30.00';

      final tax = OCRService.extractTaxAmount(text);

      expect(tax, 30.00);
    });

    test('should return null if no tax found', () {
      const text = 'Store\nTotal: 100.00';

      final tax = OCRService.extractTaxAmount(text);

      expect(tax, null);
    });

    test('should extract date in DD/MM/YYYY format', () {
      const text = 'Store\nDate: 19/04/2026\nTotal: 100';

      final date = OCRService.extractDate(text);

      expect(date?.day, 19);
      expect(date?.month, 4);
      expect(date?.year, 2026);
    });

    test('should extract date in DD-MM-YYYY format', () {
      const text = 'Store\n18-04-2026\nTotal: 100';

      final date = OCRService.extractDate(text);

      expect(date?.day, 18);
      expect(date?.month, 4);
      expect(date?.year, 2026);
    });

    test('should return null if no date found', () {
      const text = 'Store\nTotal: 100.00';

      final date = OCRService.extractDate(text);

      expect(date, null);
    });

    test('should extract amounts with comma separators', () {
      const text = 'Hospital Bill\nBill Amount: 1,000.00\nTotal: 1,000.00';

      final amount = OCRService.extractTotalAmount(text);

      expect(amount, 1000.00);
    });

    test('should extract large amounts with multiple commas', () {
      const text = 'Store\nTotal: 10,000,000.50';

      final amount = OCRService.extractTotalAmount(text);

      expect(amount, 10000000.50);
    });
  });
}
