import 'package:cloud_firestore/cloud_firestore.dart';
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
        .orderBy('date', descending: true)
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
    await _collection(uid).doc(transaction.id).set(data);
  }

  @override
  Future<void> updateTransaction(String uid, models.Transaction transaction) async {
    final data = transaction.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _collection(uid).doc(transaction.id).update(data);
  }

  @override
  Future<void> deleteTransaction(String uid, String transactionId) async {
    await _collection(uid).doc(transactionId).delete();
  }
}
