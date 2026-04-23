# Transaction Search & Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add client-side search and filtering to the transaction list — search by merchant name, filter by payment method, amount range presets, and date range presets + custom.

**Architecture:** All filtering happens in `TransactionProvider` via a `filteredTransactions` getter that applies AND logic across all active filters. No Firestore query changes. New `FilterState` model holds search query, payment method set, amount range enum, and date range. Bottom sheet UI for filter selection, active filter chip bar below search.

**Tech Stack:** Flutter, Provider, Dart

---

## File Structure

| File | Purpose |
|---|---|
| Create: `lib/models/filter_state.dart` | `FilterState` class, `AmountRange` enum, `DateRange` class |
| Create: `test/models/filter_state_test.dart` | Unit tests for filter state defaults and amount range matching |
| Modify: `lib/providers/transaction_provider.dart` | Add filter state, `filteredTransactions` getter, filter methods |
| Modify: `test/providers/transaction_provider_test.dart` | Tests for filtering logic |
| Create: `lib/widgets/filter_bottom_sheet.dart` | Bottom sheet with payment method, amount range, date range sections |
| Create: `lib/widgets/active_filter_chips.dart` | Horizontal scrollable chip bar showing active filters |
| Modify: `lib/screens/transaction_list_screen.dart` | Add search bar + filter button, switch to `filteredTransactions`, show active filter chips, filtered empty state |

---

### Task 1: FilterState Model, AmountRange Enum, DateRange Class

**Files:**
- Create: `lib/models/filter_state.dart`
- Create: `test/models/filter_state_test.dart`

- [ ] **Step 1: Write failing tests for FilterState defaults and AmountRange matching**

```dart
// test/models/filter_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/models/filter_state.dart';

void main() {
  group('FilterState', () {
    test('default state has no active filters', () {
      const state = FilterState();

      expect(state.searchQuery, '');
      expect(state.paymentMethods, isEmpty);
      expect(state.amountRange, isNull);
      expect(state.dateRange, isNull);
    });

    test('hasActiveFilters is false for default state', () {
      const state = FilterState();

      expect(state.hasActiveFilters, isFalse);
    });

    test('hasActiveFilters is true when searchQuery is set', () {
      const state = FilterState(searchQuery: 'store');

      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when paymentMethods is non-empty', () {
      const state = FilterState(paymentMethods: {'Cash'});

      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when amountRange is set', () {
      const state = FilterState(amountRange: AmountRange.under500);

      expect(state.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when dateRange is set', () {
      final state = FilterState(
        dateRange: DateRange(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 4, 21),
        ),
      );

      expect(state.hasActiveFilters, isTrue);
    });

    test('activeFilterCount counts each active category', () {
      final state = FilterState(
        searchQuery: 'store',
        paymentMethods: const {'Cash', 'Card'},
        amountRange: AmountRange.under500,
        dateRange: DateRange(
          start: DateTime(2026, 4, 1),
          end: DateTime(2026, 4, 21),
        ),
      );

      expect(state.activeFilterCount, 4);
    });

    test('activeFilterCount is 0 for default state', () {
      const state = FilterState();

      expect(state.activeFilterCount, 0);
    });

    test('copyWith replaces specified fields', () {
      const state = FilterState(searchQuery: 'old');
      final updated = state.copyWith(searchQuery: 'new');

      expect(updated.searchQuery, 'new');
      expect(state.searchQuery, 'old');
    });

    test('copyWith preserves unspecified fields', () {
      const state = FilterState(
        searchQuery: 'store',
        paymentMethods: {'Cash'},
      );
      final updated = state.copyWith(amountRange: AmountRange.above5000);

      expect(updated.searchQuery, 'store');
      expect(updated.paymentMethods, {'Cash'});
      expect(updated.amountRange, AmountRange.above5000);
    });
  });

  group('AmountRange', () {
    test('under500 matches amounts 0 to 499.99', () {
      expect(AmountRange.under500.matches(0), isTrue);
      expect(AmountRange.under500.matches(499.99), isTrue);
      expect(AmountRange.under500.matches(500), isFalse);
    });

    test('range500to1000 matches amounts 500 to 1000', () {
      expect(AmountRange.range500to1000.matches(500), isTrue);
      expect(AmountRange.range500to1000.matches(750), isTrue);
      expect(AmountRange.range500to1000.matches(1000), isTrue);
      expect(AmountRange.range500to1000.matches(499.99), isFalse);
      expect(AmountRange.range500to1000.matches(1000.01), isFalse);
    });

    test('range1000to5000 matches amounts 1000 to 5000', () {
      expect(AmountRange.range1000to5000.matches(1000), isTrue);
      expect(AmountRange.range1000to5000.matches(3000), isTrue);
      expect(AmountRange.range1000to5000.matches(5000), isTrue);
      expect(AmountRange.range1000to5000.matches(999.99), isFalse);
      expect(AmountRange.range1000to5000.matches(5000.01), isFalse);
    });

    test('above5000 matches amounts above 5000', () {
      expect(AmountRange.above5000.matches(5000.01), isTrue);
      expect(AmountRange.above5000.matches(10000), isTrue);
      expect(AmountRange.above5000.matches(5000), isFalse);
    });

    test('each AmountRange has a display label', () {
      expect(AmountRange.under500.label, 'Under 500');
      expect(AmountRange.range500to1000.label, '500 - 1000');
      expect(AmountRange.range1000to5000.label, '1000 - 5000');
      expect(AmountRange.above5000.label, '5000+');
    });
  });

  group('DateRange', () {
    test('contains returns true for dates within range inclusive', () {
      final range = DateRange(
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 4, 30),
      );

      expect(range.contains(DateTime(2026, 4, 1)), isTrue);
      expect(range.contains(DateTime(2026, 4, 15)), isTrue);
      expect(range.contains(DateTime(2026, 4, 30)), isTrue);
    });

    test('contains returns false for dates outside range', () {
      final range = DateRange(
        start: DateTime(2026, 4, 1),
        end: DateTime(2026, 4, 30),
      );

      expect(range.contains(DateTime(2026, 3, 31)), isFalse);
      expect(range.contains(DateTime(2026, 5, 1)), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/filter_state_test.dart`
Expected: FAIL — `filter_state.dart` does not exist

- [ ] **Step 3: Implement FilterState, AmountRange, DateRange**

```dart
// lib/models/filter_state.dart

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  bool contains(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !dayOnly.isBefore(startDay) && !dayOnly.isAfter(endDay);
  }
}

enum AmountRange {
  under500,
  range500to1000,
  range1000to5000,
  above5000;

  String get label {
    switch (this) {
      case AmountRange.under500:
        return 'Under 500';
      case AmountRange.range500to1000:
        return '500 - 1000';
      case AmountRange.range1000to5000:
        return '1000 - 5000';
      case AmountRange.above5000:
        return '5000+';
    }
  }

  bool matches(double amount) {
    switch (this) {
      case AmountRange.under500:
        return amount < 500;
      case AmountRange.range500to1000:
        return amount >= 500 && amount <= 1000;
      case AmountRange.range1000to5000:
        return amount >= 1000 && amount <= 5000;
      case AmountRange.above5000:
        return amount > 5000;
    }
  }
}

class FilterState {
  final String searchQuery;
  final Set<String> paymentMethods;
  final AmountRange? amountRange;
  final DateRange? dateRange;

  const FilterState({
    this.searchQuery = '',
    this.paymentMethods = const {},
    this.amountRange,
    this.dateRange,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      paymentMethods.isNotEmpty ||
      amountRange != null ||
      dateRange != null;

  int get activeFilterCount {
    int count = 0;
    if (searchQuery.isNotEmpty) count++;
    if (paymentMethods.isNotEmpty) count++;
    if (amountRange != null) count++;
    if (dateRange != null) count++;
    return count;
  }

  FilterState copyWith({
    String? searchQuery,
    Set<String>? paymentMethods,
    AmountRange? Function()? amountRange,
    DateRange? Function()? dateRange,
  }) {
    return FilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      amountRange: amountRange != null ? amountRange() : this.amountRange,
      dateRange: dateRange != null ? dateRange() : this.dateRange,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/filter_state_test.dart`
Expected: All 17 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/filter_state.dart test/models/filter_state_test.dart
git commit -m "feat: add FilterState model, AmountRange enum, DateRange class"
```

---

### Task 2: TransactionProvider Filter State and Methods

**Files:**
- Modify: `lib/providers/transaction_provider.dart`
- Modify: `test/providers/transaction_provider_test.dart`

- [ ] **Step 1: Write failing tests for filter methods and filteredTransactions**

Add the following group to the end of the `main()` function in `test/providers/transaction_provider_test.dart`, inside the existing outer `group('TransactionProvider', ...)`:

```dart
    group('filtering', () {
      final transactions = [
        Transaction(
          id: '1',
          merchantName: 'Super Market',
          totalAmount: 250.0,
          date: DateTime(2026, 4, 20),
          paymentMethod: 'Cash',
        ),
        Transaction(
          id: '2',
          merchantName: 'City Hospital',
          totalAmount: 1500.0,
          date: DateTime(2026, 4, 15),
          paymentMethod: 'Card',
        ),
        Transaction(
          id: '3',
          merchantName: 'Mobile Store',
          totalAmount: 8000.0,
          date: DateTime(2026, 3, 10),
          paymentMethod: 'Mobile Banking',
        ),
        Transaction(
          id: '4',
          merchantName: 'Super Shop',
          totalAmount: 750.0,
          date: DateTime(2026, 4, 1),
          paymentMethod: 'Cash',
        ),
      ];

      setUp(() {
        provider.setUser('user-123');
        mockRepo.emitTransactions(transactions);
      });

      test('filteredTransactions returns all when no filters active', () async {
        await Future.delayed(Duration.zero);

        expect(provider.filteredTransactions.length, 4);
      });

      test('setSearchQuery filters by merchant name case-insensitive', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');

        expect(provider.filteredTransactions.length, 2);
        expect(provider.filteredTransactions[0].merchantName, 'Super Market');
        expect(provider.filteredTransactions[1].merchantName, 'Super Shop');
      });

      test('setSearchQuery with empty string shows all', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');
        provider.setSearchQuery('');

        expect(provider.filteredTransactions.length, 4);
      });

      test('togglePaymentMethod adds and removes from set', () async {
        await Future.delayed(Duration.zero);

        provider.togglePaymentMethod('Cash');
        expect(provider.filteredTransactions.length, 2);

        provider.togglePaymentMethod('Card');
        expect(provider.filteredTransactions.length, 3);

        provider.togglePaymentMethod('Cash');
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.paymentMethod, 'Card');
      });

      test('setAmountRange filters by amount range', () async {
        await Future.delayed(Duration.zero);

        provider.setAmountRange(AmountRange.under500);
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.merchantName, 'Super Market');

        provider.setAmountRange(AmountRange.above5000);
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.merchantName, 'Mobile Store');
      });

      test('setAmountRange with null clears amount filter', () async {
        await Future.delayed(Duration.zero);

        provider.setAmountRange(AmountRange.under500);
        expect(provider.filteredTransactions.length, 1);

        provider.setAmountRange(null);
        expect(provider.filteredTransactions.length, 4);
      });

      test('setDateRange filters by date range inclusive', () async {
        await Future.delayed(Duration.zero);

        provider.setDateRange(DateTime(2026, 4, 1), DateTime(2026, 4, 20));

        expect(provider.filteredTransactions.length, 3);
        expect(
          provider.filteredTransactions.every((t) =>
            !t.date.isBefore(DateTime(2026, 4, 1)) &&
            !t.date.isAfter(DateTime(2026, 4, 20))),
          isTrue,
        );
      });

      test('setDateRange with nulls clears date filter', () async {
        await Future.delayed(Duration.zero);

        provider.setDateRange(DateTime(2026, 4, 15), DateTime(2026, 4, 20));
        expect(provider.filteredTransactions.length, 2);

        provider.setDateRange(null, null);
        expect(provider.filteredTransactions.length, 4);
      });

      test('filters combine with AND logic', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');
        provider.togglePaymentMethod('Cash');

        expect(provider.filteredTransactions.length, 2);
        expect(provider.filteredTransactions[0].merchantName, 'Super Market');
        expect(provider.filteredTransactions[1].merchantName, 'Super Shop');

        provider.setAmountRange(AmountRange.under500);

        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.merchantName, 'Super Market');
      });

      test('clearFilters resets all filters', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('super');
        provider.togglePaymentMethod('Cash');
        provider.setAmountRange(AmountRange.under500);
        provider.setDateRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30));

        provider.clearFilters();

        expect(provider.filteredTransactions.length, 4);
        expect(provider.filterState.searchQuery, '');
        expect(provider.filterState.paymentMethods, isEmpty);
        expect(provider.filterState.amountRange, isNull);
        expect(provider.filterState.dateRange, isNull);
      });

      test('hasActiveFilters reflects filter state', () async {
        await Future.delayed(Duration.zero);

        expect(provider.hasActiveFilters, isFalse);

        provider.setSearchQuery('test');
        expect(provider.hasActiveFilters, isTrue);

        provider.clearFilters();
        expect(provider.hasActiveFilters, isFalse);
      });

      test('activeFilterCount counts active categories', () async {
        await Future.delayed(Duration.zero);

        expect(provider.activeFilterCount, 0);

        provider.setSearchQuery('test');
        expect(provider.activeFilterCount, 1);

        provider.togglePaymentMethod('Cash');
        expect(provider.activeFilterCount, 2);

        provider.setAmountRange(AmountRange.under500);
        expect(provider.activeFilterCount, 3);

        provider.setDateRange(DateTime(2026, 4, 1), DateTime(2026, 4, 30));
        expect(provider.activeFilterCount, 4);
      });

      test('clearUser also resets filters', () async {
        await Future.delayed(Duration.zero);

        provider.setSearchQuery('test');
        provider.togglePaymentMethod('Cash');

        provider.clearUser();

        expect(provider.hasActiveFilters, isFalse);
        expect(provider.filteredTransactions, isEmpty);
      });
    });
```

Add the import at the top of the test file:

```dart
import 'package:superapp/models/filter_state.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/transaction_provider_test.dart`
Expected: FAIL — `filteredTransactions`, `setSearchQuery`, etc. do not exist

- [ ] **Step 3: Implement filter state and methods in TransactionProvider**

Replace the full content of `lib/providers/transaction_provider.dart`:

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/filter_state.dart';
import '../models/transaction.dart';
import '../repositories/transaction_repository.dart';

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _repository;
  List<Transaction> _transactions = [];
  FilterState _filterState = const FilterState();
  String? _uid;
  StreamSubscription<List<Transaction>>? _subscription;

  TransactionProvider({required TransactionRepository repository})
      : _repository = repository;

  List<Transaction> get transactions => List.unmodifiable(_transactions);

  FilterState get filterState => _filterState;

  bool get hasActiveFilters => _filterState.hasActiveFilters;

  int get activeFilterCount => _filterState.activeFilterCount;

  List<Transaction> get filteredTransactions {
    if (!_filterState.hasActiveFilters) {
      return List.unmodifiable(_transactions);
    }

    var result = _transactions.where((t) {
      if (_filterState.searchQuery.isNotEmpty) {
        if (!t.merchantName
            .toLowerCase()
            .contains(_filterState.searchQuery.toLowerCase())) {
          return false;
        }
      }

      if (_filterState.paymentMethods.isNotEmpty) {
        if (!_filterState.paymentMethods.contains(t.paymentMethod)) {
          return false;
        }
      }

      if (_filterState.amountRange != null) {
        if (!_filterState.amountRange!.matches(t.totalAmount)) {
          return false;
        }
      }

      if (_filterState.dateRange != null) {
        if (!_filterState.dateRange!.contains(t.date)) {
          return false;
        }
      }

      return true;
    }).toList();

    return List.unmodifiable(result);
  }

  void setSearchQuery(String query) {
    _filterState = _filterState.copyWith(searchQuery: query);
    notifyListeners();
  }

  void togglePaymentMethod(String method) {
    final methods = Set<String>.from(_filterState.paymentMethods);
    if (methods.contains(method)) {
      methods.remove(method);
    } else {
      methods.add(method);
    }
    _filterState = _filterState.copyWith(paymentMethods: methods);
    notifyListeners();
  }

  void setAmountRange(AmountRange? range) {
    _filterState = _filterState.copyWith(amountRange: () => range);
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _filterState = _filterState.copyWith(
      dateRange: () => (start != null && end != null)
          ? DateRange(start: start, end: end)
          : null,
    );
    notifyListeners();
  }

  void clearFilters() {
    _filterState = const FilterState();
    notifyListeners();
  }

  void setUser(String uid) {
    if (_uid == uid) return;
    _subscription?.cancel();
    _uid = uid;
    _subscription = _repository.watchTransactions(uid).listen(
      (transactions) {
        _transactions = transactions;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('Transaction stream error: $error');
      },
    );
  }

  void clearUser() {
    if (_uid == null) return;
    _subscription?.cancel();
    _subscription = null;
    _uid = null;
    _transactions = [];
    _filterState = const FilterState();
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/providers/transaction_provider_test.dart`
Expected: All 24 tests PASS (11 existing + 13 new)

- [ ] **Step 5: Commit**

```bash
git add lib/providers/transaction_provider.dart test/providers/transaction_provider_test.dart
git commit -m "feat: add filter state and filteredTransactions to TransactionProvider"
```

---

### Task 3: Search Bar and Filter Button in Transaction List Screen

**Files:**
- Modify: `lib/screens/transaction_list_screen.dart`

- [ ] **Step 1: Add search bar with filter button to the transaction list screen**

Replace the `body: Consumer<TransactionProvider>(...)` section of `lib/screens/transaction_list_screen.dart`. The body should wrap the existing `Consumer` content with a `Column` that has the search bar on top. The full updated file:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/active_filter_chips.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/transaction_card.dart';
import '../widgets/empty_state.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final initial = (user?.fullName.isNotEmpty == true)
        ? user!.fullName[0].toUpperCase()
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super App'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF2196F3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.phone ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthProvider>().signOut();
              },
            ),
          ],
        ),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          if (provider.transactions.isEmpty) {
            return const EmptyState();
          }

          final filtered = provider.filteredTransactions;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: provider.setSearchQuery,
                        decoration: InputDecoration(
                          hintText: 'Search merchant...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16),
                                ),
                              ),
                              builder: (_) => ChangeNotifierProvider.value(
                                value: provider,
                                child: const FilterBottomSheet(),
                              ),
                            );
                          },
                        ),
                        if (provider.activeFilterCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${provider.activeFilterCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (provider.hasActiveFilters)
                ActiveFilterChips(provider: provider),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions match your filters',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: provider.clearFilters,
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final transaction = filtered[index];
                          return TransactionCard(
                            transaction: transaction,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/edit',
                                arguments: transaction,
                              );
                            },
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
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
            bottom: 16,
            left: MediaQuery.of(context).size.width / 2 - 28,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/review',
                  arguments: {'manualEntry': true},
                );
              },
              heroTag: 'manualEntry',
              backgroundColor: const Color(0xFF4CAF50),
              child: const Icon(Icons.edit, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/capture');
              },
              heroTag: 'camera',
              backgroundColor: const Color(0xFF2196F3),
              child: const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
```

Note: This references `FilterBottomSheet` and `ActiveFilterChips` which don't exist yet. The app will not compile until Tasks 4 and 5 are done. Create stub files first to avoid compile errors.

- [ ] **Step 2: Create stub files so the app compiles**

Create `lib/widgets/active_filter_chips.dart`:

```dart
import 'package:flutter/material.dart';
import '../providers/transaction_provider.dart';

class ActiveFilterChips extends StatelessWidget {
  final TransactionProvider provider;

  const ActiveFilterChips({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
```

Create `lib/widgets/filter_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';

class FilterBottomSheet extends StatelessWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
```

- [ ] **Step 3: Verify the app compiles**

Run: `flutter analyze lib/screens/transaction_list_screen.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/screens/transaction_list_screen.dart lib/widgets/active_filter_chips.dart lib/widgets/filter_bottom_sheet.dart
git commit -m "feat: add search bar and filter button to transaction list screen"
```

---

### Task 4: Active Filter Chips Widget

**Files:**
- Modify: `lib/widgets/active_filter_chips.dart`

- [ ] **Step 1: Implement the active filter chips widget**

Replace the stub content in `lib/widgets/active_filter_chips.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/filter_state.dart';
import '../providers/transaction_provider.dart';

class ActiveFilterChips extends StatelessWidget {
  final TransactionProvider provider;

  const ActiveFilterChips({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.filterState;
    final chips = <Widget>[];

    if (state.searchQuery.isNotEmpty) {
      chips.add(_buildChip(
        label: '"${state.searchQuery}"',
        onRemove: () => provider.setSearchQuery(''),
      ));
    }

    for (final method in state.paymentMethods) {
      chips.add(_buildChip(
        label: method,
        onRemove: () => provider.togglePaymentMethod(method),
      ));
    }

    if (state.amountRange != null) {
      chips.add(_buildChip(
        label: state.amountRange!.label,
        onRemove: () => provider.setAmountRange(null),
      ));
    }

    if (state.dateRange != null) {
      final fmt = DateFormat('MMM d');
      final label =
          '${fmt.format(state.dateRange!.start)} - ${fmt.format(state.dateRange!.end)}';
      chips.add(_buildChip(
        label: label,
        onRemove: () => provider.setDateRange(null, null),
      ));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: chips),
    );
  }

  Widget _buildChip({required String label, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
```

- [ ] **Step 2: Check for intl dependency**

Run: `grep 'intl:' pubspec.yaml`

If `intl` is not listed, add it:

Run: `flutter pub add intl`

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/widgets/active_filter_chips.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/active_filter_chips.dart pubspec.yaml pubspec.lock
git commit -m "feat: add active filter chips widget"
```

---

### Task 5: Filter Bottom Sheet Widget

**Files:**
- Modify: `lib/widgets/filter_bottom_sheet.dart`

- [ ] **Step 1: Implement the filter bottom sheet**

Replace the stub content in `lib/widgets/filter_bottom_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/filter_state.dart';
import '../providers/transaction_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late Set<String> _selectedPaymentMethods;
  late AmountRange? _selectedAmountRange;
  late DateRange? _selectedDateRange;
  String? _selectedDatePreset;

  static const _paymentMethods = ['Cash', 'Card', 'Mobile Banking', 'Other'];
  static const _datePresets = [
    'Today',
    'This Week',
    'This Month',
    'Last 3 Months',
    'Custom Range',
  ];

  @override
  void initState() {
    super.initState();
    final state = context.read<TransactionProvider>().filterState;
    _selectedPaymentMethods = Set<String>.from(state.paymentMethods);
    _selectedAmountRange = state.amountRange;
    _selectedDateRange = state.dateRange;
  }

  DateRange _resolvePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case 'Today':
        return DateRange(start: today, end: now);
      case 'This Week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateRange(start: monday, end: now);
      case 'This Month':
        return DateRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
      case 'Last 3 Months':
        return DateRange(
          start: DateTime(now.year, now.month - 3, now.day),
          end: now,
        );
      default:
        return DateRange(start: today, end: now);
    }
  }

  void _applyFilters() {
    final provider = context.read<TransactionProvider>();

    final currentMethods = provider.filterState.paymentMethods;
    if (!_setEquals(_selectedPaymentMethods, currentMethods)) {
      for (final m in currentMethods) {
        if (!_selectedPaymentMethods.contains(m)) {
          provider.togglePaymentMethod(m);
        }
      }
      for (final m in _selectedPaymentMethods) {
        if (!currentMethods.contains(m)) {
          provider.togglePaymentMethod(m);
        }
      }
    }

    provider.setAmountRange(_selectedAmountRange);

    if (_selectedDateRange != null) {
      provider.setDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );
    } else {
      provider.setDateRange(null, null);
    }

    Navigator.pop(context);
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    return a.length == b.length && a.containsAll(b);
  }

  void _clearAll() {
    setState(() {
      _selectedPaymentMethods = {};
      _selectedAmountRange = null;
      _selectedDateRange = null;
      _selectedDatePreset = null;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _selectedDateRange != null
          ? DateTimeRange(
              start: _selectedDateRange!.start,
              end: _selectedDateRange!.end,
            )
          : null,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = DateRange(
          start: picked.start,
          end: picked.end,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment Method',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentMethods.map((method) {
                  final selected = _selectedPaymentMethods.contains(method);
                  return FilterChip(
                    label: Text(method),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedPaymentMethods.remove(method);
                        } else {
                          _selectedPaymentMethods.add(method);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Amount Range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AmountRange.values.map((range) {
                  final selected = _selectedAmountRange == range;
                  return ChoiceChip(
                    label: Text(range.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedAmountRange = selected ? null : range;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Date Range',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _datePresets.map((preset) {
                  final selected = _selectedDatePreset == preset;
                  return ChoiceChip(
                    label: Text(preset),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        if (selected) {
                          _selectedDatePreset = null;
                          _selectedDateRange = null;
                        } else {
                          _selectedDatePreset = preset;
                          if (preset == 'Custom Range') {
                            _pickCustomRange();
                          } else {
                            _selectedDateRange = _resolvePreset(preset);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/widgets/filter_bottom_sheet.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/filter_bottom_sheet.dart
git commit -m "feat: add filter bottom sheet with payment, amount, and date filters"
```

---

### Task 6: Run All Tests and Final Verification

**Files:**
- No new files

- [ ] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit any remaining changes if needed**

If analysis revealed issues that required fixes, commit them:

```bash
git add -A
git commit -m "fix: address analysis warnings"
```

---

### Task 7: Manual Testing on Device

**Files:**
- No changes

- [ ] **Step 1: Build and run the app**

Run: `flutter run`

- [ ] **Step 2: Test search**

1. With transactions in the list, type a merchant name in the search bar
2. Verify the list filters live as you type
3. Verify clearing the search text shows all transactions
4. Verify case-insensitive matching (type lowercase for uppercase merchant)

- [ ] **Step 3: Test filter bottom sheet**

1. Tap the filter button (funnel icon)
2. Select a payment method chip → verify it highlights
3. Select multiple payment methods → verify multi-select works
4. Deselect a payment method → verify it unhighlights
5. Select an amount range chip → verify single-select (others deselect)
6. Select a date preset → verify single-select
7. Select "Custom Range" → verify date picker opens
8. Tap "Clear All" → verify all selections reset
9. Select filters and tap "Apply Filters" → verify sheet closes

- [ ] **Step 4: Test active filter chips**

1. After applying filters, verify chips appear below the search bar
2. Verify each active filter has its own chip with correct label
3. Tap the ✕ on a chip → verify that filter is removed and results update
4. Verify the badge number on the filter button matches the number of active filter categories

- [ ] **Step 5: Test combined filters**

1. Search for a merchant AND set a payment method filter → verify AND logic
2. Add amount range → verify further filtering
3. Add date range → verify further filtering
4. Clear all filters → verify full list returns

- [ ] **Step 6: Test edge cases**

1. Apply filters that match no transactions → verify "No transactions match your filters" message with "Clear Filters" button
2. Tap "Clear Filters" → verify full list returns
3. With no transactions at all → verify the original empty state shows (not the search/filter UI)
