import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final _textRecognizer = TextRecognizer();

  static Future<Map<String, dynamic>> extractReceiptData(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text;

      return {
        'merchantName': extractMerchantName(text) ?? '',
        'totalAmount': extractTotalAmount(text) ?? 0.0,
        'date': extractDate(text),
        'taxAmount': extractTaxAmount(text),
        'paymentMethod': 'Cash',
      };
    } catch (e) {
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
      if (trimmed.isNotEmpty && !_isNumeric(trimmed)) {
        return trimmed;
      }
    }
    return null;
  }

  static double? extractTotalAmount(String text) {
    final keywords = ['total', 'টোটাল', 'মোট', 'amount', 'টাকা'];

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

    final allNumbers = _extractNumbers(text);
    if (allNumbers.isNotEmpty) {
      return allNumbers.reduce((a, b) => a > b ? a : b);
    }

    return null;
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
    // Pattern matches numbers with optional commas and decimals: 1,000.00
    final pattern = RegExp(r'\d+(?:,\d+)*(?:\.\d+)?');
    final matches = pattern.allMatches(normalizedText);

    return matches
        .map((m) {
          // Remove commas before parsing to double
          final cleanNumber = m.group(0)!.replaceAll(',', '');
          return double.tryParse(cleanNumber);
        })
        .where((n) => n != null)
        .cast<double>()
        .toList();
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
