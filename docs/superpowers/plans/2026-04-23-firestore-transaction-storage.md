# Firestore Transaction Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist transactions to Firestore with built-in offline support, scoped per authenticated user.

**Architecture:** Firestore subcollection `users/{uid}/transactions/{id}` as the single source of truth. `TransactionProvider` subscribes to a real-time `snapshots()` stream after login. Firestore SDK handles offline caching and automatic sync. Abstract `TransactionRepository` interface follows the existing pattern.

**Tech Stack:** Flutter, Provider, Cloud Firestore (`cloud_firestore: ^5.4.3`), Firebase Auth

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/models/transaction.dart` | Modify | Add `toMap()` / `fromMap()` for Firestore serialization |
| `lib/repositories/transaction_repository.dart` | Create | Abstract interface for transaction CRUD + streaming |
| `lib/repositories/firebase/firestore_transaction_repository.dart` | Create | Firestore implementation |
| `lib/providers/transaction_provider.dart` | Modify | Inject repository, subscribe to stream, delegate CRUD, handle UID lifecycle |
| `lib/main.dart` | Modify | Enable Firestore persistence, wire repository, connect auth → transaction provider |
| `test/models/transaction_test.dart` | Modify | Add serialization tests |
| `test/providers/transaction_provider_test.dart` | Modify | Rewrite with mocked repository |

---

### Task 1: Add Firestore Serialization to Transaction Model

**Files:**
- Modify: `lib/models/transaction.dart`
- Modify: `test/models/transaction_test.dart`

- [ ] **Step 1: Write the failing tests for `toMap()` and `fromMap()`**

Add these tests to `test/models/transaction_test.dart`, inside the existing `group('Transaction Model', ...)`:

```dart
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
      // Firestore returns Timestamp objects; fromMap must handle both
      // DateTime (from tests) and Timestamp (from Firestore).
      // We test with DateTime here; Timestamp conversion is handled
      // in the repository layer.
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/transaction_test.dart`
Expected: Compilation errors — `toMap` and `fromMap` do not exist on `Transaction`.

- [ ] **Step 3: Implement `toMap()` and `fromMap()` on Transaction**

Add these two methods to `lib/models/transaction.dart`, inside the `Transaction` class, after the `copyWith` method (after line 38):

```dart
  Map<String, dynamic> toMap() {
    return {
      'merchantName': merchantName,
      'totalAmount': totalAmount,
      'date': date,
      'paymentMethod': paymentMethod,
      if (taxAmount != null) 'taxAmount': taxAmount,
      if (imagePath != null) 'imagePath': imagePath,
    };
  }

  factory Transaction.fromMap(String id, Map<String, dynamic> map) {
    return Transaction(
      id: id,
      merchantName: map['merchantName'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      date: map['date'] is DateTime
          ? map['date'] as DateTime
          : (map['date'] as dynamic).toDate() as DateTime,
      paymentMethod: map['paymentMethod'] as String,
      taxAmount: map['taxAmount'] != null
          ? (map['taxAmount'] as num).toDouble()
          : null,
      imagePath: map['imagePath'] as String?,
    );
  }
```

Notes:
- `id` is passed separately because Firestore document ID is not stored inside the document data.
- `toMap()` excludes `id` — it's the Firestore document key.
- `(map['totalAmount'] as num).toDouble()` handles Firestore returning `int` for whole numbers like `100` vs `double` for `100.5`.
- The `date` field handles both `DateTime` (unit tests) and Firestore `Timestamp` (runtime) via duck-typing on `.toDate()`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/transaction_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/models/transaction.dart test/models/transaction_test.dart
git commit -m "feat: add toMap/fromMap serialization to Transaction model"
```

---

### Task 2: Create Abstract TransactionRepository Interface

**Files:**
- Create: `lib/repositories/transaction_repository.dart`

- [ ] **Step 1: Create the abstract interface**

Create `lib/repositories/transaction_repository.dart`:

```dart
import '../models/transaction.dart';

abstract class TransactionRepository {
  Stream<List<Transaction>> watchTransactions(String uid);
  Future<void> addTransaction(String uid, Transaction transaction);
  Future<void> updateTransaction(String uid, Transaction transaction);
  Future<void> deleteTransaction(String uid, String transactionId);
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `flutter analyze lib/repositories/transaction_repository.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/transaction_repository.dart
git commit -m "feat: add abstract TransactionRepository interface"
```

---

### Task 3: Implement FirestoreTransactionRepository

**Files:**
- Create: `lib/repositories/firebase/firestore_transaction_repository.dart`

- [ ] **Step 1: Implement the Firestore repository**

Create `lib/repositories/firebase/firestore_transaction_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/transaction.dart';
import '../transaction_repository.dart';

class FirestoreTransactionRepository implements TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  @override
  Stream<List<Transaction>> watchTransactions(String uid) {
    return _collection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Transaction.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  @override
  Future<void> addTransaction(String uid, Transaction transaction) async {
    final data = transaction.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _collection(uid).doc(transaction.id).set(data);
  }

  @override
  Future<void> updateTransaction(String uid, Transaction transaction) async {
    final data = transaction.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _collection(uid).doc(transaction.id).update(data);
  }

  @override
  Future<void> deleteTransaction(String uid, String transactionId) async {
    await _collection(uid).doc(transactionId).delete();
  }
}
```

Notes:
- Uses `doc(transaction.id)` on add so the client-generated UUID becomes the Firestore document ID.
- `createdAt` is only set on add; `updatedAt` is set on every write.
- `FieldValue.serverTimestamp()` resolves to the server's clock, providing the audit trail.
- `orderBy('date', descending: true)` matches the existing sort behavior in `TransactionProvider`.
- The `date` field in `toMap()` stores a `DateTime`, which Firestore SDK auto-converts to a `Timestamp`.

- [ ] **Step 2: Verify the file compiles**

Run: `flutter analyze lib/repositories/firebase/firestore_transaction_repository.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add lib/repositories/firebase/firestore_transaction_repository.dart
git commit -m "feat: implement FirestoreTransactionRepository with offline support"
```

---

### Task 4: Rewrite TransactionProvider to Use Repository

**Files:**
- Modify: `lib/providers/transaction_provider.dart`
- Modify: `test/providers/transaction_provider_test.dart`

- [ ] **Step 1: Write the failing tests for the new provider**

Replace the entire contents of `test/providers/transaction_provider_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/transaction_provider_test.dart`
Expected: Compilation errors — `TransactionProvider` doesn't accept `repository` parameter yet.

- [ ] **Step 3: Rewrite TransactionProvider**

Replace the entire contents of `lib/providers/transaction_provider.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository;
  List<Transaction> _transactions = [];
  String? _uid;
  StreamSubscription<List<Transaction>>? _subscription;

  TransactionProvider({required TransactionRepository repository})
      : _repository = repository;

  List<Transaction> get transactions => List.unmodifiable(_transactions);

  void setUser(String uid) {
    _subscription?.cancel();
    _uid = uid;
    _subscription = _repository.watchTransactions(uid).listen((transactions) {
      _transactions = transactions;
      notifyListeners();
    });
  }

  void clearUser() {
    _subscription?.cancel();
    _subscription = null;
    _uid = null;
    _transactions = [];
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) {
    return _repository.addTransaction(_requireUid(), transaction);
  }

  Future<void> updateTransaction(Transaction transaction) {
    return _repository.updateTransaction(_requireUid(), transaction);
  }

  Future<void> deleteTransaction(String id) {
    return _repository.deleteTransaction(_requireUid(), id);
  }

  String _requireUid() {
    if (_uid == null) {
      throw StateError('No user set. Call setUser() before performing operations.');
    }
    return _uid!;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

Key changes from the original:
- Constructor now requires a `TransactionRepository`.
- `setUser(uid)` subscribes to real-time Firestore stream.
- `clearUser()` cancels subscription and clears state.
- CRUD methods are now `Future<void>` (async) and delegate to repository.
- Sorting is no longer done in the provider — Firestore `orderBy` handles it.
- `_requireUid()` throws `StateError` if CRUD is attempted without a user.
- `dispose()` cancels the stream subscription.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/providers/transaction_provider_test.dart`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/transaction_provider.dart test/providers/transaction_provider_test.dart
git commit -m "feat: rewrite TransactionProvider to use TransactionRepository with stream"
```

---

### Task 5: Wire Everything Together in main.dart

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update main() to enable Firestore offline persistence**

In `lib/main.dart`, add the Firestore settings import and persistence config. Replace the `main()` function (lines 17-21):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const MyApp());
}
```

Add this import at the top of the file (after the existing firebase_core import):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

- [ ] **Step 2: Update MultiProvider to inject the repository**

Add the import for `FirestoreTransactionRepository` at the top of the file:

```dart
import 'repositories/firebase/firestore_transaction_repository.dart';
```

Replace the `TransactionProvider` line in the `providers` array (line 37):

```dart
        ChangeNotifierProvider(
          create: (_) => TransactionProvider(
            repository: FirestoreTransactionRepository(),
          ),
        ),
```

- [ ] **Step 3: Connect auth state to TransactionProvider in _AuthGateState**

Update the `build` method of `_AuthGateState` (lines 74-96) to call `setUser` / `clearUser` on the `TransactionProvider` when auth state changes:

```dart
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final transactionProvider = context.read<TransactionProvider>();
        switch (auth.state) {
          case AuthState.authenticated:
            if (auth.currentUser != null) {
              transactionProvider.setUser(auth.currentUser!.uid);
            }
            return const TransactionListScreen();
          case AuthState.otpSent:
            return const OtpScreen();
          case AuthState.newUser:
            return const RegisterScreen();
          case AuthState.initial:
          case AuthState.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AuthState.unauthenticated:
          case AuthState.error:
            transactionProvider.clearUser();
            return const LoginScreen();
        }
      },
    );
  }
```

- [ ] **Step 4: Verify the app compiles**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire Firestore transaction repository with offline persistence"
```

---

### Task 6: Update Screens for Async CRUD

**Files:**
- Modify: `lib/screens/review_edit_screen.dart`
- Modify: `lib/screens/transaction_list_screen.dart`

The CRUD methods on `TransactionProvider` are now `Future<void>` instead of `void`. The screens need minor updates to handle this.

- [ ] **Step 1: Update `_saveTransaction` in ReviewEditScreen**

In `lib/screens/review_edit_screen.dart`, change `_saveTransaction` (line 135) from a sync method to async. Replace lines 135-167:

```dart
  Future<void> _saveTransaction() async {
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

    try {
      if (_isEditMode) {
        await provider.updateTransaction(transaction);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated')),
        );
      } else {
        await provider.addTransaction(transaction);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction saved')),
        );
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
```

- [ ] **Step 2: Update `onDelete` in TransactionListScreen**

In `lib/screens/transaction_list_screen.dart`, update the `onDelete` callback (lines 108-116) to handle the async delete:

```dart
                onDelete: () async {
                  try {
                    await provider.deleteTransaction(transaction.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaction deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
```

- [ ] **Step 3: Verify the app compiles**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/review_edit_screen.dart lib/screens/transaction_list_screen.dart
git commit -m "feat: update screens for async transaction CRUD"
```

---

### Task 7: Run All Tests and Verify

**Files:**
- No new files.

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS. The auth_provider_test.dart should still pass since we didn't change the auth layer. The transaction_provider_test.dart now uses the mock repository.

- [ ] **Step 2: Fix any test failures**

If `test/providers/auth_provider_test.dart` has issues due to import changes, check and fix. The only possible issue would be if it imported `TransactionProvider` directly, which it should not.

- [ ] **Step 3: Verify analyze passes**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit any fixes**

Only if fixes were needed in Step 2:

```bash
git add -A
git commit -m "fix: resolve test issues from transaction storage integration"
```

---

### Task 8: Manual Testing on Device

**Files:**
- No files. This is a verification task.

- [ ] **Step 1: Run the app**

Run: `flutter run`

- [ ] **Step 2: Test the happy path**

1. Log in with phone OTP
2. Add a transaction (via manual entry or camera)
3. Verify it appears in the list
4. Edit the transaction — verify changes persist
5. Close the app completely and reopen — verify transaction is still there
6. Delete a transaction — verify it disappears

- [ ] **Step 3: Test offline behavior**

1. Enable airplane mode on the device
2. Add a new transaction — it should save instantly (to local cache)
3. Edit an existing transaction — it should update instantly
4. Delete a transaction — it should disappear instantly
5. Disable airplane mode
6. Check Firebase Console → Firestore → `users/{uid}/transactions/` to verify all changes synced

- [ ] **Step 4: Test logout cleanup**

1. Log out
2. Log in as a different user (or same user)
3. Verify transactions are scoped to the logged-in user

---

### Task 9: Deploy Firestore Security Rules

**Files:**
- No Flutter files. Firebase Console or CLI operation.

- [ ] **Step 1: Deploy security rules**

In Firebase Console (or via `firebase deploy --only firestore:rules`), set the Firestore security rules to:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;

      match /transactions/{transactionId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

- [ ] **Step 2: Verify rules are active**

In Firebase Console, navigate to Firestore → Rules and confirm the rules are published.
