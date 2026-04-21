import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createUser(UserModel user) async {
    final map = user.toMap();
    map['createdAt'] = Timestamp.fromDate(user.createdAt);
    await _firestore.collection('users').doc(user.uid).set(map);
  }

  @override
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['createdAt'] =
        (data['createdAt'] as Timestamp).toDate().toIso8601String();
    return UserModel.fromMap(data);
  }
}
