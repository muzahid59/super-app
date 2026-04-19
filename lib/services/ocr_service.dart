import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final _textRecognizer = TextRecognizer();

  static Future<Map<String, dynamic>> extractReceiptData(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      // Debug: Print the full OCR text
      print('=== OCR EXTRACTED TEXT ===');
      print(text);
      print('=== END OCR TEXT ===');

      final merchantName = extractMerchantName(text) ?? '';
      final totalAmount = extractTotalAmount(text) ?? 0.0;
      final date = extractDate(text);
      final taxAmount = extractTaxAmount(text);

      // Debug: Print extracted values
      print('Merchant: $merchantName');
      print('Total Amount: $totalAmount');
      print('Date: $date');
      print('Tax: $taxAmount');

      return {
        'merchantName': merchantName,
        'totalAmount': totalAmount,
        'date': date,
        'taxAmount': taxAmount,
        'paymentMethod': 'Cash',
      };
    } catch (e) {
      print('OCR Error: $e');
      return {
        'merchantName': '',
        'totalAmount': 0.0,
        'date': null,
        'taxAmount': null,
        'paymentMethod': 'Cash',
        'error': e.toString(),
      };
    }
  }

  static String? extractMerchantName(String text) {
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      // Skip very short lines (likely OCR errors) and numeric lines
      // Look for lines with at least 10 characters that aren't pure numbers
      if (trimmed.length >= 10 && !_isNumeric(trimmed) && !trimmed.contains('PATIENT COPY')) {
        return trimmed;
      }
    }
    return null;
  }

  static double? extractTotalAmount(String text) {
    final keywords = ['total', 'টোটাল', 'মোট', 'bill amount', 'টাকা', 'taka'];

    final lines = text.split('\n');

    // Strategy 1: Find amounts near keywords
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      // Skip "VAT Amount" - it's not the total
      if (line.contains('vat')) continue;

      if (keywords.any((keyword) => line.contains(keyword))) {
        final numbers = _extractNumbers(lines[i]);
        if (numbers.isNotEmpty) {
          return numbers.reduce((a, b) => a > b ? a : b);
        }
        // Only check next line if it doesn't look like a date
        if (i + 1 < lines.length && !_looksLikeDate(lines[i + 1])) {
          final nextNumbers = _extractNumbers(lines[i + 1]);
          if (nextNumbers.isNotEmpty) {
            return nextNumbers.reduce((a, b) => a > b ? a : b);
          }
        }
      }
    }

    // Strategy 2: Look for "One Thousand Taka Only" pattern and find nearest amount
    if (text.toLowerCase().contains('taka only') || text.toLowerCase().contains('টাকা')) {
      final allNumbers = _extractNumbers(text);
      // Prefer amounts with decimals and > 10 (exclude small values like 0.00)
      final validAmounts = allNumbers.where((n) => n >= 10.0).toList();
      if (validAmounts.isNotEmpty) {
        // Return the most common "bill-like" amount (with 2 decimal places)
        validAmounts.sort((a, b) => b.compareTo(a));
        return validAmounts.first;
      }
    }

    // Strategy 3: Fallback - find largest meaningful number
    final allNumbers = _extractNumbers(text);
    final validAmounts = allNumbers.where((n) => n >= 1.0 && n < 1000000).toList();
    if (validAmounts.isNotEmpty) {
      validAmounts.sort((a, b) => b.compareTo(a));
      return validAmounts.first;
    }

    return null;
  }

  static bool _looksLikeDate(String line) {
    // Check if line contains date patterns
    return RegExp(r'\d{1,2}[-/]\w{3}[-/]\d{4}').hasMatch(line) || // 08-APR-2026
           RegExp(r'\d{1,2}[-/]\d{1,2}[-/]\d{2,4}').hasMatch(line); // 08/04/2026
  }

  static double? extractTaxAmount(String text) {
    final keywords = ['vat', 'ভ্যাট', 'tax', 'কর'];

    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (keywords.any((keyword) => line.contains(keyword))) {
        final numbers = _extractNumbers(lines[i]);
        if (numbers.isNotEmpty) {
          return numbers.reduce((a, b) => a > b ? a : b);
        }
        if (i + 1 < lines.length) {
          final nextNumbers = _extractNumbers(lines[i + 1]);
          if (nextNumbers.isNotEmpty) {
            return nextNumbers.reduce((a, b) => a > b ? a : b);
          }
        }
      }
    }

    return null;
  }

  static DateTime? extractDate(String text) {
    final datePatterns = [
      RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})'),
      RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2})'),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          int day = int.parse(match.group(1)!);
          int month = int.parse(match.group(2)!);
          int year = int.parse(match.group(3)!);

          if (year < 100) {
            year += 2000;
          }

          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } catch (e) {
          continue;
        }
      }
    }

    return null;
  }

  static List<double> _extractNumbers(String text) {
    final normalizedText = _normalizeBanglaNumbers(text);
    // Pattern matches numbers with commas/periods as thousand separators: 1,000.00 or 1.000,00
    // Handles both US format (1,000.00) and European format (1.000,00)
    final pattern = RegExp(r'\d{1,3}(?:[,\.]\d{3})*(?:[,\.]\d{1,2})?');
    final matches = pattern.allMatches(normalizedText);

    final numbers = <double>[];
    for (final match in matches) {
      String numStr = match.group(0)!;

      // Skip if this looks like a year (2020-2030 range)
      if (RegExp(r'^20[2-3]\d$').hasMatch(numStr)) {
        continue;
      }

      // Determine if last separator is decimal point
      // If number has two separators of different types, the last one is decimal
      final lastComma = numStr.lastIndexOf(',');
      final lastPeriod = numStr.lastIndexOf('.');

      if (lastComma > lastPeriod) {
        // European format: 1.000,50 -> remove periods, replace comma with period
        numStr = numStr.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // US format: 1,000.50 -> remove commas
        numStr = numStr.replaceAll(',', '');
      }

      final parsed = double.tryParse(numStr);
      if (parsed != null) {
        numbers.add(parsed);
      }
    }

    return numbers;
  }

  static String _normalizeBanglaNumbers(String text) {
    const banglaDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    String result = text;
    for (int i = 0; i < banglaDigits.length; i++) {
      result = result.replaceAll(banglaDigits[i], englishDigits[i]);
    }
    return result;
  }

  static bool _isNumeric(String text) {
    return double.tryParse(text) != null;
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
