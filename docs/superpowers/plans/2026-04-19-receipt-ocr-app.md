# Receipt OCR Scanner App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android app that captures receipt photos, extracts transaction data via OCR, and displays them in an editable list.

**Architecture:** Three-screen flow (List → Capture → Review) with Provider state management. Google ML Kit for on-device OCR supporting Bangla and English. In-memory storage (no persistence in v1).

**Tech Stack:** Flutter, Provider, Google ML Kit Text Recognition, Camera package

---

## File Structure

```
lib/
├── main.dart                               # App entry, Provider setup, theme
├── models/
│   └── transaction.dart                    # Transaction data model
├── providers/
│   └── transaction_provider.dart           # State management for transactions
├── services/
│   ├── ocr_service.dart                    # ML Kit text recognition wrapper
│   └── camera_service.dart                 # Camera controller wrapper
├── screens/
│   ├── transaction_list_screen.dart        # Home screen with list view
│   ├── camera_capture_screen.dart          # Camera preview and capture
│   └── review_edit_screen.dart             # OCR review and edit form
└── widgets/
    ├── transaction_card.dart               # List item widget
    └── empty_state.dart                    # Empty list placeholder

android/app/src/main/AndroidManifest.xml    # Camera permissions
android/app/build.gradle                     # minSdkVersion config
```

---

## Task 1: Flutter Project Setup

**Files:**
- Create: `pubspec.yaml`
- Create: `android/app/build.gradle`
- Create: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Create Flutter project**

Run:
```bash
flutter create --org com.area59 --platforms android ocr_app
cd ocr_app
```

Expected: Flutter project scaffolded successfully

- [ ] **Step 2: Update pubspec.yaml with dependencies**

Replace `pubspec.yaml` dependencies section:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Camera
  camera: ^0.10.5+9
  
  # OCR
  google_mlkit_text_recognition: ^0.11.0
  
  # State Management
  provider: ^6.1.2
  
  # UUID generation
  uuid: ^4.4.0
  
  # Date formatting
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

- [ ] **Step 3: Install dependencies**

Run:
```bash
flutter pub get
```

Expected: All packages resolved and downloaded

- [ ] **Step 4: Configure Android minSdkVersion**

Modify `android/app/build.gradle`, find `defaultConfig` and update:

```gradle
defaultConfig {
    applicationId "com.area59.ocr_app"
    minSdkVersion 21
    targetSdkVersion flutter.targetSdkVersion
    versionCode flutterVersionCode.toInteger()
    versionName flutterVersionName
}
```

- [ ] **Step 5: Add camera permissions to AndroidManifest.xml**

Add inside `<manifest>` tag (before `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

- [ ] **Step 6: Verify setup**

Run:
```bash
flutter doctor
```

Expected: No critical issues, Android toolchain ready

- [ ] **Step 7: Commit initial setup**

```bash
git init
git add .
git commit -m "Initial Flutter project setup with dependencies"
```

---

## Task 2: Transaction Model

**Files:**
- Create: `lib/models/transaction.dart`
- Create: `test/models/transaction_test.dart`

- [ ] **Step 1: Write failing test for Transaction model**

Create `test/models/transaction_test.dart`:

```dart
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
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/models/transaction_test.dart
```

Expected: FAIL - "Target of URI doesn't exist: 'package:ocr_app/models/transaction.dart'"

- [ ] **Step 3: Implement Transaction model**

Create `lib/models/transaction.dart`:

```dart
class Transaction {
  final String id;
  final String merchantName;
  final double totalAmount;
  final DateTime date;
  final String paymentMethod;
  final double? taxAmount;
  final String? imagePath;

  Transaction({
    required this.id,
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.paymentMethod,
    this.taxAmount,
    this.imagePath,
  });

  Transaction copyWith({
    String? id,
    String? merchantName,
    double? totalAmount,
    DateTime? date,
    String? paymentMethod,
    double? taxAmount,
    String? imagePath,
  }) {
    return Transaction(
      id: id ?? this.id,
      merchantName: merchantName ?? this.merchantName,
      totalAmount: totalAmount ?? this.totalAmount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      taxAmount: taxAmount ?? this.taxAmount,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
flutter test test/models/transaction_test.dart
```

Expected: PASS - All 3 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/models/transaction.dart test/models/transaction_test.dart
git commit -m "Add Transaction model with tests"
```

---

## Task 3: Transaction Provider

**Files:**
- Create: `lib/providers/transaction_provider.dart`
- Create: `test/providers/transaction_provider_test.dart`

- [ ] **Step 1: Write failing tests for TransactionProvider**

Create `test/providers/transaction_provider_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/providers/transaction_provider_test.dart
```

Expected: FAIL - "Target of URI doesn't exist: 'package:ocr_app/providers/transaction_provider.dart'"

- [ ] **Step 3: Implement TransactionProvider**

Create `lib/providers/transaction_provider.dart`:

```dart
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';

class TransactionProvider extends ChangeNotifier {
  final List<Transaction> _transactions = [];

  List<Transaction> get transactions {
    final sorted = List<Transaction>.from(_transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }

  void addTransaction(Transaction transaction) {
    _transactions.add(transaction);
    notifyListeners();
  }

  void updateTransaction(Transaction transaction) {
    final index = _transactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
      notifyListeners();
    }
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
flutter test test/providers/transaction_provider_test.dart
```

Expected: PASS - All 5 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/providers/transaction_provider.dart test/providers/transaction_provider_test.dart
git commit -m "Add TransactionProvider with state management"
```

---

## Task 4: OCR Service

**Files:**
- Create: `lib/services/ocr_service.dart`
- Create: `test/services/ocr_service_test.dart`

- [ ] **Step 1: Write test for OCR service structure**

Create `test/services/ocr_service_test.dart`:

```dart
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
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
flutter test test/services/ocr_service_test.dart
```

Expected: FAIL - "Target of URI doesn't exist: 'package:ocr_app/services/ocr_service.dart'"

- [ ] **Step 3: Implement OCR extraction logic**

Create `lib/services/ocr_service.dart`:

```dart
import 'dart:io';
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
    final lowerText = text.toLowerCase();
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
    final lowerText = text.toLowerCase();
    final keywords = ['vat', 'ভ্যাট', 'tax', 'কর'];
    
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (keywords.any((keyword) => line.contains(keyword))) {
        final numbers = _extractNumbers(lines[i]);
        if (numbers.isNotEmpty) {
          return numbers.first;
        }
        if (i + 1 < lines.length) {
          final nextNumbers = _extractNumbers(lines[i + 1]);
          if (nextNumbers.isNotEmpty) {
            return nextNumbers.first;
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
    final pattern = RegExp(r'\d+\.?\d*');
    final matches = pattern.allMatches(normalizedText);
    
    return matches
        .map((m) => double.tryParse(m.group(0)!))
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
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
flutter test test/services/ocr_service_test.dart
```

Expected: PASS - All 10 tests pass

- [ ] **Step 5: Commit**

```bash
git add lib/services/ocr_service.dart test/services/ocr_service_test.dart
git commit -m "Add OCR service with text extraction logic"
```

---

## Task 5: Camera Service

**Files:**
- Create: `lib/services/camera_service.dart`

- [ ] **Step 1: Implement Camera Service wrapper**

Create `lib/services/camera_service.dart`:

```dart
import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  Future<CameraController?> initializeCamera() async {
    try {
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        return null;
      }

      final camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      
      return _controller;
    } catch (e) {
      return null;
    }
  }

  Future<XFile?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }

    try {
      final image = await _controller!.takePicture();
      return image;
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _controller?.dispose();
  }

  CameraController? get controller => _controller;
}
```

- [ ] **Step 2: Verify file compiles**

Run:
```bash
flutter analyze lib/services/camera_service.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/camera_service.dart
git commit -m "Add camera service wrapper"
```

---

## Task 6: Empty State Widget

**Files:**
- Create: `lib/widgets/empty_state.dart`

- [ ] **Step 1: Implement empty state widget**

Create `lib/widgets/empty_state.dart`:

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to scan a receipt',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify widget compiles**

Run:
```bash
flutter analyze lib/widgets/empty_state.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/empty_state.dart
git commit -m "Add empty state widget"
```

---

## Task 7: Transaction Card Widget

**Files:**
- Create: `lib/widgets/transaction_card.dart`

- [ ] **Step 1: Implement transaction card widget**

Create `lib/widgets/transaction_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Transaction'),
              content: const Text('Are you sure you want to delete this transaction?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        onDelete();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.merchantName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(transaction.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.paymentMethod,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '৳${transaction.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify widget compiles**

Run:
```bash
flutter analyze lib/widgets/transaction_card.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/transaction_card.dart
git commit -m "Add transaction card widget with swipe-to-delete"
```

---

## Task 8: Transaction List Screen

**Files:**
- Create: `lib/screens/transaction_list_screen.dart`

- [ ] **Step 1: Implement transaction list screen**

Create `lib/screens/transaction_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_card.dart';
import '../widgets/empty_state.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Scanner'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.transactions.isEmpty) {
            return const EmptyState();
          }

          return ListView.builder(
            itemCount: provider.transactions.length,
            itemBuilder: (context, index) {
              final transaction = provider.transactions[index];
              return TransactionCard(
                transaction: transaction,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/edit',
                    arguments: transaction,
                  );
                },
                onDelete: () {
                  provider.deleteTransaction(transaction.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/capture');
        },
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify screen compiles**

Run:
```bash
flutter analyze lib/screens/transaction_list_screen.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/transaction_list_screen.dart
git commit -m "Add transaction list screen with FAB"
```

---

## Task 9: Camera Capture Screen

**Files:**
- Create: `lib/screens/camera_capture_screen.dart`

- [ ] **Step 1: Implement camera capture screen**

Create `lib/screens/camera_capture_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  final CameraService _cameraService = CameraService();
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final controller = await _cameraService.initializeCamera();
    
    if (controller == null) {
      setState(() {
        _errorMessage = 'Failed to initialize camera. Please check permissions.';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _controller = controller;
      _isInitialized = true;
    });
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    final image = await _cameraService.takePicture();

    if (!mounted) return;

    setState(() {
      _isCapturing = false;
    });

    if (image != null) {
      Navigator.pushReplacementNamed(
        context,
        '/review',
        arguments: {'imagePath': image.path},
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to capture image')),
      );
    }
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Receipt'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _initializeCamera();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    SizedBox.expand(
                      child: CameraPreview(_controller!),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _captureImage,
                          child: Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFF2196F3),
                                width: 4,
                              ),
                            ),
                            child: _isCapturing
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
```

- [ ] **Step 2: Verify screen compiles**

Run:
```bash
flutter analyze lib/screens/camera_capture_screen.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/camera_capture_screen.dart
git commit -m "Add camera capture screen with preview"
```

---

## Task 10: Review Edit Screen

**Files:**
- Create: `lib/screens/review_edit_screen.dart`

- [ ] **Step 1: Implement review edit screen**

Create `lib/screens/review_edit_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../services/ocr_service.dart';

class ReviewEditScreen extends StatefulWidget {
  const ReviewEditScreen({super.key});

  @override
  State<ReviewEditScreen> createState() => _ReviewEditScreenState();
}

class _ReviewEditScreenState extends State<ReviewEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'Cash';
  String? _imagePath;
  Transaction? _existingTransaction;
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<String> _paymentMethods = [
    'Cash',
    'Card',
    'Mobile Banking',
    'Other',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map<String, dynamic> && args.containsKey('imagePath')) {
      _imagePath = args['imagePath'] as String;
      _isEditMode = false;
      _performOCR();
    } else if (args is Transaction) {
      _existingTransaction = args;
      _isEditMode = true;
      _loadExistingTransaction();
    }
  }

  void _loadExistingTransaction() {
    if (_existingTransaction != null) {
      _merchantController.text = _existingTransaction!.merchantName;
      _amountController.text = _existingTransaction!.totalAmount.toString();
      _selectedDate = _existingTransaction!.date;
      _selectedPaymentMethod = _existingTransaction!.paymentMethod;
      if (_existingTransaction!.taxAmount != null) {
        _taxController.text = _existingTransaction!.taxAmount.toString();
      }
      _imagePath = _existingTransaction!.imagePath;
    }
  }

  Future<void> _performOCR() async {
    if (_imagePath == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final extractedData = await OCRService.extractReceiptData(_imagePath!);
      
      if (!mounted) return;

      setState(() {
        _merchantController.text = extractedData['merchantName'] ?? '';
        _amountController.text = extractedData['totalAmount']?.toString() ?? '0.0';
        _selectedDate = extractedData['date'] ?? DateTime.now();
        _selectedPaymentMethod = extractedData['paymentMethod'] ?? 'Cash';
        
        if (extractedData['taxAmount'] != null) {
          _taxController.text = extractedData['taxAmount'].toString();
        }
        
        _isLoading = false;
      });

      if (extractedData.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read receipt. Please enter details manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR failed. Please enter details manually.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = Provider.of<TransactionProvider>(context, listen: false);
    
    final transaction = Transaction(
      id: _existingTransaction?.id ?? const Uuid().v4(),
      merchantName: _merchantController.text.trim(),
      totalAmount: double.parse(_amountController.text),
      date: _selectedDate,
      paymentMethod: _selectedPaymentMethod,
      taxAmount: _taxController.text.isNotEmpty 
          ? double.tryParse(_taxController.text) 
          : null,
      imagePath: _imagePath,
    );

    if (_isEditMode) {
      provider.updateTransaction(transaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated')),
      );
    } else {
      provider.addTransaction(transaction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved')),
      );
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retakePhoto() {
    Navigator.of(context).pushReplacementNamed('/capture');
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaction' : 'Review Receipt'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_imagePath != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePath!),
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    TextFormField(
                      controller: _merchantController,
                      decoration: const InputDecoration(
                        labelText: 'Merchant Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.store),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter merchant name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Total Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: '৳ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter total amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(dateFormat.format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                      items: _paymentMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedPaymentMethod = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _taxController,
                      decoration: const InputDecoration(
                        labelText: 'Tax Amount (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt),
                        prefixText: '৳ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final tax = double.tryParse(value);
                          if (tax == null || tax < 0) {
                            return 'Please enter a valid tax amount';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _isEditMode ? 'Update Transaction' : 'Save Transaction',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    if (!_isEditMode) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _retakePhoto,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Retake Photo',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
```

- [ ] **Step 2: Verify screen compiles**

Run:
```bash
flutter analyze lib/screens/review_edit_screen.dart
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/screens/review_edit_screen.dart
git commit -m "Add review edit screen with OCR integration"
```

---

## Task 11: Main App Setup

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace main.dart with app setup**

Replace entire contents of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/transaction_list_screen.dart';
import 'screens/camera_capture_screen.dart';
import 'screens/review_edit_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TransactionProvider(),
      child: MaterialApp(
        title: 'Receipt Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const TransactionListScreen(),
          '/capture': (context) => const CameraCaptureScreen(),
          '/review': (context) => const ReviewEditScreen(),
          '/edit': (context) => const ReviewEditScreen(),
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Run app to verify it compiles**

Run:
```bash
flutter run --debug
```

Expected: App builds successfully (may not run without device, but should compile)

If no device available, verify with:
```bash
flutter analyze
```

Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "Set up main app with Provider and navigation"
```

---

## Task 12: Final Testing and Verification

**Files:**
- None (testing only)

- [ ] **Step 1: Run all tests**

Run:
```bash
flutter test
```

Expected: All tests pass

- [ ] **Step 2: Analyze code for issues**

Run:
```bash
flutter analyze
```

Expected: No issues found

- [ ] **Step 3: Build APK (if Android device/emulator available)**

Run:
```bash
flutter build apk --debug
```

Expected: APK builds successfully

- [ ] **Step 4: Test on device (manual testing)**

If device available:
1. Run: `flutter run`
2. Test flow: Tap FAB → Allow camera permission → Capture receipt → Review extracted data → Save
3. Verify transaction appears in list
4. Test edit: Tap transaction → Modify data → Save
5. Test delete: Swipe transaction → Confirm delete

Expected: All flows work as designed

- [ ] **Step 5: Final commit**

```bash
git add .
git commit -m "Complete receipt OCR app implementation"
```

---

## Success Criteria Verification

After implementation, verify:

- [ ] User can capture receipt photo with device camera
- [ ] OCR extracts text from receipts (test with both Bangla and English)
- [ ] Form auto-populates with extracted data
- [ ] User can manually edit all fields
- [ ] Transactions display in scrollable list (newest first)
- [ ] User can edit existing transactions
- [ ] User can delete transactions (with confirmation)
- [ ] App works offline (no internet required)
- [ ] UI is clean and intuitive

---

## Known Limitations (Out of Scope)

- No data persistence - data clears when app closes
- No cloud sync
- No search or filtering
- No export functionality
- No analytics or charts
- OCR accuracy depends on image quality

---

**End of Implementation Plan**
