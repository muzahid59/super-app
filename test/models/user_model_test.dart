import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/models/user_model.dart';

void main() {
  group('UserModel', () {
    final map = {
      'uid': 'uid-123',
      'fullName': 'John Doe',
      'phone': '+8801700000000',
      'email': 'john@gmail.com',
      'sessionToken': 'token-abc',
      'createdAt': '2026-04-21T10:00:00.000',
    };

    test('fromMap constructs model correctly', () {
      final user = UserModel.fromMap(map);
      expect(user.uid, 'uid-123');
      expect(user.fullName, 'John Doe');
      expect(user.phone, '+8801700000000');
      expect(user.email, 'john@gmail.com');
      expect(user.sessionToken, 'token-abc');
      expect(user.createdAt.year, 2026);
    });

    test('fromMap accepts null email', () {
      final noEmail = Map<String, dynamic>.from(map)..['email'] = null;
      final user = UserModel.fromMap(noEmail);
      expect(user.email, isNull);
    });

    test('toMap round-trips correctly', () {
      final user = UserModel.fromMap(map);
      final result = user.toMap();
      expect(result['uid'], 'uid-123');
      expect(result['fullName'], 'John Doe');
      expect(result['email'], 'john@gmail.com');
      expect(result['sessionToken'], 'token-abc');
    });

    test('toMap omits email key when null', () {
      final noEmail = Map<String, dynamic>.from(map)..['email'] = null;
      final user = UserModel.fromMap(noEmail);
      expect(user.toMap().containsKey('email'), isFalse);
    });
  });
}
