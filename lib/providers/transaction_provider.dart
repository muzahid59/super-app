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
