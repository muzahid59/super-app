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
