# Receipt OCR Scanner App - Design Specification

**Date:** 2026-04-19  
**Project:** Flutter Android Receipt Scanner  
**Purpose:** Bare minimum app for small business owners to scan and track transaction receipts in Bangla and English

---

## Overview

A simple Flutter Android app that uses device camera to capture receipt images, extracts transaction details via OCR (Google ML Kit), and displays them in an editable list. Data is stored in-memory only (no persistence in v1).

---

## Architecture & Screens

### 1. TransactionListScreen (Home Screen)
**Purpose:** Main hub - displays all captured transactions

**UI Elements:**
- AppBar with app title
- ListView displaying transaction cards
- Each card shows: merchant name (bold), total amount (large), date (small gray text)
- Floating Action Button (FAB) with camera icon in bottom-right
- Empty state: "No transactions yet. Tap + to scan a receipt" with an icon

**Interactions:**
- Tap FAB → navigate to CameraCaptureScreen
- Tap transaction card → navigate to ReviewEditScreen (edit mode) with selected transaction
- Swipe transaction card → show delete confirmation dialog → remove from list

### 2. CameraCaptureScreen
**Purpose:** Capture receipt image using device camera

**UI Elements:**
- Full-screen camera preview
- Circular capture button (centered bottom)
- Back button (top-left)
- Optional: flash toggle, camera flip (if needed later)

**Interactions:**
- Tap capture button → take photo → navigate to ReviewEditScreen with captured image
- Back button → return to TransactionListScreen

**Technical:**
- Uses `camera` Flutter package
- Targets rear camera by default
- Captures at medium resolution (balance quality vs performance)

### 3. ReviewEditScreen
**Purpose:** Review OCR-extracted data and edit before saving

**UI Elements:**
- Small image thumbnail at top (captured receipt)
- Editable form fields:
  - Merchant Name (text input)
  - Total Amount (numeric input with decimal)
  - Date (date picker, defaults to today)
  - Payment Method (dropdown: Cash, Card, Mobile Banking, Other)
  - Tax Amount (optional numeric input)
- Two action buttons at bottom:
  - "Save Transaction" (primary button)
  - "Retake Photo" (secondary/outlined button)

**Interactions:**
- On screen load: Run OCR on image → auto-populate form fields
- Edit any field manually
- Tap "Save" → add/update transaction in list → navigate back to home
- Tap "Retake" → navigate back to CameraCaptureScreen

**Modes:**
- **Create mode:** Accessed from CameraCaptureScreen (new transaction)
- **Edit mode:** Accessed from TransactionListScreen (edit existing transaction, shows pre-filled data)

---

## Data Model

### Transaction
```dart
class Transaction {
  final String id;              // UUID
  final String merchantName;
  final double totalAmount;
  final DateTime date;
  final String paymentMethod;   // 'Cash', 'Card', 'Mobile Banking', 'Other'
  final double? taxAmount;      // Optional
  final String? imagePath;      // Optional: path to cached image (for future use)
  
  Transaction({
    required this.id,
    required this.merchantName,
    required this.totalAmount,
    required this.date,
    required this.paymentMethod,
    this.taxAmount,
    this.imagePath,
  });
}
```

**Storage:** In-memory list maintained by state management provider. Data is lost when app closes (persistence is a future enhancement).

---

## OCR Implementation

### Technology: Google ML Kit Text Recognition
- **Package:** `google_mlkit_text_recognition`
- **Language Support:** Automatic detection of Latin (English) and Bengali scripts
- **Processing:** On-device, free, works offline

### Extraction Logic

**Step 1:** Run ML Kit text recognition on captured image → get all detected text blocks

**Step 2:** Smart extraction (heuristic-based):
- **Merchant Name:** First non-numeric text line (usually at top)
- **Total Amount:** 
  - Look for keywords: "total", "টোটাল", "মোট", "amount", "টাকা"
  - Extract largest numeric value near these keywords
  - Fallback: largest number on receipt
- **Date:** 
  - Look for date patterns (DD/MM/YYYY, DD-MM-YYYY, etc.)
  - Fallback: today's date
- **Tax Amount:**
  - Look for keywords: "vat", "ভ্যাট", "tax", "কর"
  - Extract associated number
- **Payment Method:** Default to "Cash" (user can change)

**Step 3:** Pre-populate form fields with extracted values

**Error Handling:**
- If OCR fails or no text detected → show empty form with error message: "Could not read receipt. Please enter details manually."
- Invalid numbers → default to 0.0
- User can always manually correct any field

---

## State Management

**Solution:** Provider (simple, lightweight, official recommendation)

### TransactionProvider
```dart
class TransactionProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  
  List<Transaction> get transactions => _transactions;
  
  void addTransaction(Transaction transaction) { ... }
  void updateTransaction(Transaction transaction) { ... }
  void deleteTransaction(String id) { ... }
}
```

**Why Provider?**
- Minimal boilerplate for a simple app
- Built-in Flutter support
- Easy to migrate to Riverpod later if needed

---

## Dependencies

### Core Flutter Packages
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Camera
  camera: ^0.10.5
  
  # OCR
  google_mlkit_text_recognition: ^0.11.0
  
  # State Management
  provider: ^6.1.0
  
  # UUID generation
  uuid: ^4.0.0
  
  # Date formatting
  intl: ^0.18.0
```

### Android Permissions (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

### Minimum SDK
- **minSdkVersion:** 21 (Android 5.0) - required by ML Kit

---

## Navigation Flow

```
TransactionListScreen (/)
    ├─→ CameraCaptureScreen (/capture)
    │       └─→ ReviewEditScreen (/review, create mode)
    │               ├─→ Save → TransactionListScreen
    │               └─→ Retake → CameraCaptureScreen
    └─→ ReviewEditScreen (/edit/:id, edit mode)
            └─→ Save → TransactionListScreen
```

**Implementation:** Named routes with arguments passing

---

## Error Handling

### Camera Errors
- Permission denied → show dialog explaining camera access is required
- Camera initialization fails → show error message with retry button

### OCR Errors
- ML Kit initialization fails → graceful fallback to manual entry with warning
- No text detected → show message "No text found" and allow manual entry

### Form Validation
- Merchant name: required, min 1 character
- Total amount: required, must be > 0
- Date: required, cannot be future date
- Show validation errors inline below fields

---

## UI/UX Guidelines

### Design System
- **Theme:** Material Design 3
- **Primary Color:** Blue (#2196F3) - professional, trustworthy
- **Accent Color:** Green (#4CAF50) - for success states, amounts
- **Typography:** 
  - Merchant names: 16sp, bold
  - Amounts: 18sp, medium
  - Dates: 12sp, regular
- **Locale Support:** Bengali (bn_BD) and English (en_US) number formatting

### Accessibility
- Minimum touch target: 48x48 dp
- Semantic labels for screen readers
- High contrast between text and backgrounds

---

## Future Enhancements (Out of Scope for v1)

1. **Persistence:** SQLite local database
2. **Cloud Sync:** Firebase/Supabase integration
3. **Search & Filters:** Date range, merchant search
4. **Export:** CSV/Excel export
5. **Analytics:** Monthly spending charts
6. **Categories:** Tag transactions by category
7. **Multi-currency:** Support for different currencies
8. **Batch Scanning:** Multiple receipts in one session
9. **Receipt Gallery:** View all captured images

---

## Success Criteria

A successful v1 delivers:
- ✅ User can capture receipt photo with device camera
- ✅ OCR extracts text from Bangla and English receipts
- ✅ Form auto-populates with extracted data
- ✅ User can manually edit all fields
- ✅ Transactions display in a scrollable list
- ✅ User can edit and delete transactions
- ✅ App works offline (no internet required)
- ✅ Clean, intuitive UI suitable for small business owners

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   └── transaction.dart
├── providers/
│   └── transaction_provider.dart
├── screens/
│   ├── transaction_list_screen.dart
│   ├── camera_capture_screen.dart
│   └── review_edit_screen.dart
├── services/
│   ├── camera_service.dart
│   └── ocr_service.dart
└── widgets/
    ├── transaction_card.dart
    └── empty_state.dart
```

---

## Implementation Notes

### OCR Service Architecture
- Singleton service `OCRService` wraps ML Kit initialization
- `Future<Map<String, dynamic>> extractReceiptData(XFile image)` returns map of extracted fields
- Disposal handled properly to release ML Kit resources

### Camera Service Architecture
- Manages camera controller lifecycle
- Provides clean API for initialization, capture, disposal
- Handles permission requests

### Testing Strategy
- Manual testing with real receipts (both Bangla and English)
- Test edge cases: blurry images, handwritten receipts, poor lighting
- No automated tests for v1 (future enhancement)

---

**End of Design Document**
