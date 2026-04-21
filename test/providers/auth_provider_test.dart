import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_app/models/user_model.dart';
import 'package:ocr_app/providers/auth_provider.dart';
import 'package:ocr_app/repositories/session_repository.dart';
import 'package:ocr_app/repositories/user_repository.dart';
import 'package:ocr_app/services/auth/auth_service.dart';

// ---- Fakes ----

class FakeAuthService implements AuthService {
  String? _uid;
  String? _phone;
  String? capturedPhone;
  bool otpSucceeds = true;

  void setSignedIn(String uid, String phone) {
    _uid = uid;
    _phone = phone;
  }

  @override
  Future<void> sendOtp(
    String phoneNumber, {
    required void Function(String) onCodeSent,
    required void Function(String) onError,
  }) async {
    capturedPhone = phoneNumber;
    if (otpSucceeds) {
      onCodeSent('fake-verification-id');
    } else {
      onError('SMS failed');
    }
  }

  @override
  Future<void> verifyOtp(String verificationId, String smsCode) async {
    if (!otpSucceeds) throw Exception('Invalid OTP');
    _uid = 'verified-uid';
    _phone = '+8801700000000';
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _phone = null;
  }

  @override
  String? get currentUserId => _uid;

  @override
  String? get currentUserPhone => _phone;
}

class FakeUserRepository implements UserRepository {
  UserModel? storedUser;

  @override
  Future<void> createUser(UserModel user) async {
    storedUser = user;
  }

  @override
  Future<UserModel?> getUserById(String uid) async {
    if (storedUser?.uid == uid) return storedUser;
    return null;
  }
}

class FakeSessionRepository implements SessionRepository {
  String? _localToken;
  final Map<String, String> _firestoreTokens = {};

  @override
  Future<void> writeSessionToken(String uid, String token) async {
    _firestoreTokens[uid] = token;
    _localToken = token;
  }

  @override
  Future<String?> getSessionToken(String uid) async {
    return _firestoreTokens[uid];
  }

  @override
  Future<void> clearSession() async {
    _localToken = null;
  }

  @override
  Future<String?> getLocalSessionToken() async {
    return _localToken;
  }
}

// ---- Helper ----

AuthProvider makeProvider({
  FakeAuthService? auth,
  FakeUserRepository? user,
  FakeSessionRepository? session,
}) {
  return AuthProvider(
    authService: auth ?? FakeAuthService(),
    userRepo: user ?? FakeUserRepository(),
    sessionRepo: session ?? FakeSessionRepository(),
  );
}

// ---- Tests ----

void main() {
  group('AuthProvider.checkSession', () {
    test('sets unauthenticated when no Firebase user', () async {
      final provider = makeProvider();
      await provider.checkSession();
      expect(provider.state, AuthState.unauthenticated);
    });

    test('sets authenticated when tokens match', () async {
      final auth = FakeAuthService()..setSignedIn('uid-1', '+880');
      final user = FakeUserRepository()
        ..storedUser = UserModel(
          uid: 'uid-1',
          fullName: 'Test',
          phone: '+880',
          sessionToken: 'tok',
          createdAt: DateTime.now(),
        );
      final session = FakeSessionRepository();
      await session.writeSessionToken('uid-1', 'tok');

      final provider = makeProvider(auth: auth, user: user, session: session);
      await provider.checkSession();

      expect(provider.state, AuthState.authenticated);
      expect(provider.currentUser?.fullName, 'Test');
    });

    test('sets unauthenticated and clears session when tokens mismatch',
        () async {
      final auth = FakeAuthService()..setSignedIn('uid-1', '+880');
      final session = FakeSessionRepository();
      session._localToken = 'old-token';
      session._firestoreTokens['uid-1'] = 'new-token-from-other-device';

      final provider = makeProvider(auth: auth, session: session);
      await provider.checkSession();

      expect(provider.state, AuthState.unauthenticated);
      expect(await session.getLocalSessionToken(), isNull);
    });
  });

  group('AuthProvider.sendOtp', () {
    test('sets otpSent state on success', () async {
      final provider = makeProvider();
      await provider.sendOtp('+8801700000000');
      expect(provider.state, AuthState.otpSent);
    });

    test('sets error state on failure', () async {
      final auth = FakeAuthService()..otpSucceeds = false;
      final provider = makeProvider(auth: auth);
      await provider.sendOtp('+8801700000000');
      expect(provider.state, AuthState.error);
      expect(provider.error, 'SMS failed');
    });
  });

  group('AuthProvider.verifyOtp', () {
    test('sets authenticated when Firestore user exists', () async {
      final auth = FakeAuthService();
      final user = FakeUserRepository()
        ..storedUser = UserModel(
          uid: 'verified-uid',
          fullName: 'Existing',
          phone: '+8801700000000',
          sessionToken: 'old',
          createdAt: DateTime.now(),
        );
      final session = FakeSessionRepository();

      final provider = makeProvider(auth: auth, user: user, session: session);
      await provider.sendOtp('+8801700000000');
      await provider.verifyOtp('123456');

      expect(provider.state, AuthState.authenticated);
      expect(await session.getLocalSessionToken(), isNotNull);
    });

    test('sets newUser state when no Firestore profile', () async {
      final provider = makeProvider();
      await provider.sendOtp('+8801700000000');
      await provider.verifyOtp('123456');
      expect(provider.state, AuthState.newUser);
    });
  });

  group('AuthProvider.register', () {
    test('creates user and sets authenticated', () async {
      final auth = FakeAuthService();
      final user = FakeUserRepository();
      final session = FakeSessionRepository();

      final provider = makeProvider(auth: auth, user: user, session: session);
      await provider.sendOtp('+8801700000000');
      await provider.verifyOtp('123456');
      await provider.register('John Doe', 'john@example.com');

      expect(provider.state, AuthState.authenticated);
      expect(user.storedUser?.fullName, 'John Doe');
      expect(user.storedUser?.email, 'john@example.com');
      expect(await session.getLocalSessionToken(), isNotNull);
    });

    test('register with null email stores null', () async {
      final auth = FakeAuthService();
      final user = FakeUserRepository();
      final provider = makeProvider(auth: auth, user: user);

      await provider.sendOtp('+8801700000000');
      await provider.verifyOtp('123456');
      await provider.register('Jane Doe', null);

      expect(user.storedUser?.email, isNull);
    });
  });
}
