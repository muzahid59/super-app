import '../models/transaction.dart';

abstract class TransactionRepository {
  Stream<List<Transaction>> watchTransactions(String uid);
  Future<void> addTransaction(String uid, Transaction transaction);
  Future<void> updateTransaction(String uid, Transaction transaction);
  Future<void> deleteTransaction(String uid, String transactionId);
}
