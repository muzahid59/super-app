# Firestore Transaction Storage with Offline Support

## Overview

Store transaction metadata in Firebase Cloud Firestore with built-in offline persistence. The app uses Firestore's native offline caching so users can perform full CRUD operations while offline, with automatic sync when connectivity returns.

## Firestore Schema

Transactions are stored as a subcollection under each user:

```
users/{uid}/transactions/{transactionId}
```

### Document Fields

| Field | Type | Notes |
|---|---|---|
| `merchantName` | string | Required |
| `totalAmount` | double | Required |
| `date` | timestamp | Transaction date |
| `paymentMethod` | string | Cash, Card, Mobile Banking, Other |
| `taxAmount` | double or null | Optional |
| `imagePath` | string or null | Local path, not synced to cloud |
| `createdAt` | timestamp | Server timestamp, set on create |
| `updatedAt` | timestamp | Server timestamp, set on every write |

### Why a Subcollection

- Data is naturally scoped per user.
- Firestore security rules can restrict access via `request.auth.uid == uid`.
- No redundant `userId` field on every document.

### Number Handling

`totalAmount` and `taxAmount` are stored as Firestore doubles, matching the existing `Transaction` model. No cents-based integer conversion.

## Architecture

### New Files

| File | Purpose |
|---|---|
| `lib/repositories/transaction_repository.dart` | Abstract interface for transaction CRUD + streaming |
| `lib/repositories/firebase/firestore_transaction_repository.dart` | Firestore implementation with offline persistence |

### Modified Files

| File | Change |
|---|---|
| `lib/models/transaction.dart` | Add `toMap()` and `fromMap()` for Firestore serialization |
| `lib/providers/transaction_provider.dart` | Inject `TransactionRepository`, load transactions via stream on UID set, delegate CRUD to repository |
| `lib/main.dart` | Enable Firestore offline persistence at startup, wire `FirestoreTransactionRepository` into `TransactionProvider`, pass user UID to provider after authentication |

### Unchanged

Screens, widgets, services, and the auth layer remain untouched. The UI continues to read from `TransactionProvider` — the data source behind it simply changes from in-memory to Firestore.

### Abstract Interface

```dart
abstract class TransactionRepository {
  Stream<List<Transaction>> watchTransactions(String uid);
  Future<void> addTransaction(String uid, Transaction transaction);
  Future<void> updateTransaction(String uid, Transaction transaction);
  Future<void> deleteTransaction(String uid, String transactionId);
}
```

This follows the existing pattern established by `UserRepository` and `SessionRepository`.

## Data Flow

### Reading Transactions (on login)

After authentication, `_AuthGate` (in `main.dart`) calls `TransactionProvider.setUser(uid)` which stores the UID and subscribes to the Firestore stream. This is triggered from the widget layer when auth state transitions to `authenticated`.

```
AuthProvider.state -> authenticated
  -> _AuthGate detects state change
  -> Calls TransactionProvider.setUser(uid)
  -> Subscribes to Firestore snapshots() stream on users/{uid}/transactions/
  -> Stream updates in-memory list automatically
  -> UI rebuilds via notifyListeners()
```

### Creating / Editing / Deleting (online or offline)

```
User action
  -> TransactionProvider
  -> FirestoreTransactionRepository
  -> Firestore SDK writes to local cache (instant)
  -> SDK syncs to server when online (automatic)
  -> snapshots() stream picks up the confirmed write
```

### Offline Behavior

- Firestore SDK caches data locally. Reads work without connectivity.
- Writes are queued in the SDK's local cache.
- When connectivity returns, queued writes sync automatically.
- No user-facing sync button or indicator.

### On Logout

```
AuthProvider.signOut()
  -> TransactionProvider clears UID and in-memory list
  -> Stream subscription cancelled
  -> Next user gets a fresh, scoped view
```

### Logged-Out Offline

Not supported. Logout clears the Firebase Auth session and local session token. Re-login requires phone OTP which needs internet. This is correct behavior since transactions are scoped per user — without a UID, there is nothing to show.

## Conflict Resolution

Last write wins. With single-device session enforcement already in place, concurrent writes from multiple devices cannot happen under normal usage. The `updatedAt` server timestamp provides an audit trail.

## Firestore Security Rules

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

Users can only read and write their own data.

## Error Handling

| Scenario | Behavior |
|---|---|
| Firestore write fails (permission denied) | Show snackbar with error message |
| Stream disconnects | Firestore SDK reconnects automatically |
| Offline write | Firestore SDK queues silently |
| No transactions | Existing `EmptyState` widget handles this |

No custom retry logic or error screens. Firestore SDK handles reconnection and write queuing internally.

## Testing Strategy

| Layer | Approach |
|---|---|
| `Transaction.toMap()` / `fromMap()` | Unit tests verifying serialization round-trips, null handling |
| `TransactionRepository` interface | Mocked in provider tests |
| `TransactionProvider` | Unit tests with mocked repository — CRUD calls, stream updates, UID scoping, cleanup on logout |
| `FirestoreTransactionRepository` | Integration tests against Firestore emulator (can be deferred) |

No changes to existing screen or widget tests since the UI layer is unchanged.
