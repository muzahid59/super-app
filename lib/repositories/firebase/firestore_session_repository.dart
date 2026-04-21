import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../session_repository.dart';

class FirestoreSessionRepository implements SessionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _tokenKey = 'session_token';

  @override
  Future<void> writeSessionToken(String uid, String token) async {
    await Future.wait([
      _firestore
          .collection('users')
          .doc(uid)
          .set({'sessionToken': token}, SetOptions(merge: true)),
      SharedPreferences.getInstance()
          .then((prefs) => prefs.setString(_tokenKey, token)),
    ]);
  }

  @override
  Future<String?> getSessionToken(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['sessionToken'] as String?;
  }

  @override
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  @override
  Future<String?> getLocalSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
