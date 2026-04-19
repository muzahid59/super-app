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
    final keywords = ['total', 'টোটাল', 'মোট', 'bill amount', 'payable amount', 'টাকা', 'taka', 'cash paid'];

    final lines = text.split('\n');

    // Strategy 1: Find amounts near keywords (check multiple nearby lines)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      // Skip "VAT Amount" - it's not the total
      if (line.contains('vat') && !line.contains('amount')) continue;

      if (keywords.any((keyword) => line.contains(keyword))) {
        // Try current line first
        final numbers = _extractNumbers(lines[i]);
        if (numbers.isNotEmpty) {
          return numbers.reduce((a, b) => a > b ? a : b);
        }

        // Check next 3 lines (for table-like structures where keyword is header)
        for (int j = 1; j <= 3 && i + j < lines.length; j++) {
          if (_looksLikeDate(lines[i + j])) continue;

          final nextNumbers = _extractNumbers(lines[i + j]);
          if (nextNumbers.isNotEmpty) {
            // Return largest amount found in nearby lines
            return nextNumbers.reduce((a, b) => a > b ? a : b);
          }
        }
      }
    }

    // Strategy 2: Look for "One Thousand Taka Only" pattern and find nearest amount
    if (text.toLowerCase().contains('taka only') || text.toLowerCase().contains('টাকা')) {
      final allNumbers = _extractNumbers(text);
      // Prefer amounts with decimals and > 10 (exclude small values like 0.00)
      final validAmounts = allNumbers.where((n) => n >= 10.0 && n < 100000).toList();
      if (validAmounts.isNotEmpty) {
        validAmounts.sort((a, b) => b.compareTo(a));
        return validAmounts.first;
      }
    }

    // Strategy 3: Fallback - find most common reasonable amount
    final allNumbers = _extractNumbers(text);
    final validAmounts = allNumbers.where((n) => n >= 1.0 && n < 1000000).toList();
    if (validAmounts.isNotEmpty) {
      // Count frequency of amounts (in case same amount appears multiple times)
      final frequency = <double, int>{};
      for (final amount in validAmounts) {
        frequency[amount] = (frequency[amount] ?? 0) + 1;
      }

      // If one amount appears multiple times, it's likely the total
      if (frequency.values.any((count) => count >= 2)) {
        final mostCommon = frequency.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        return mostCommon;
      }

      // Otherwise return largest
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
    // Also matches simple numbers: 123.45, 1000
    final pattern = RegExp(r'\d{1,3}(?:[,\.]\d{3})*(?:[,\.]\d{1,2})?|\d+\.?\d*');
    final matches = pattern.allMatches(normalizedText);

    final numbers = <double>[];
    for (final match in matches) {
      String numStr = match.group(0)!;
      final matchStart = match.start;

      // Skip if this looks like a year (2020-2030 range)
      if (RegExp(r'^20[2-3]\d$').hasMatch(numStr)) {
        continue;
      }

      // Skip if preceded by letters (likely an ID like B123123, A0420264337110)
      if (matchStart > 0 && RegExp(r'[A-Za-z]').hasMatch(normalizedText[matchStart - 1])) {
        continue;
      }

      // Skip invoice/reference numbers (long digit sequences without separators)
      final digitsOnly = numStr.replaceAll(RegExp(r'[^\d]'), '');
      if (digitsOnly.length > 6 && !numStr.contains(',') && !numStr.contains('.')) {
        continue;
      }

      // Determine if last separator is decimal point
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
      if (parsed != null && parsed >= 0.01 && parsed < 10000000) {
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
