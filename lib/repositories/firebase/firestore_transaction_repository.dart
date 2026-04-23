import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/transaction.dart' as models;
import '../transaction_repository.dart';

class FirestoreTransactionRepository implements TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  @override
  Stream<List<models.Transaction>> watchTransactions(String uid) {
    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return models.Transaction.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  @override
  Future<void> addTransaction(String uid, models.Transaction transaction) async {
    final data = transaction.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    // Don't await — Firestore writes to local cache immediately with
    // persistence enabled. Awaiting throws gRPC UNAVAILABLE when offline.
    _collection(uid).doc(transaction.id).set(data).catchError((e) {
      debugPrint('Firestore addTransaction sync error: $e');
    });
  }

  @override
  Future<void> updateTransaction(String uid, models.Transaction transaction) async {
    final data = transaction.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    _collection(uid).doc(transaction.id).update(data).catchError((e) {
      debugPrint('Firestore updateTransaction sync error: $e');
    });
  }

  @override
  Future<void> deleteTransaction(String uid, String transactionId) async {
    _collection(uid).doc(transactionId).delete().catchError((e) {
      debugPrint('Firestore deleteTransaction sync error: $e');
    });
  }
}
