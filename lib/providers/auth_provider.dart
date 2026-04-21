import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../repositories/session_repository.dart';
import '../repositories/user_repository.dart';
import '../services/auth/auth_service.dart';

enum AuthState {
  initial,
  loading,
  unauthenticated,
  otpSent,
  newUser,
  authenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserRepository _userRepo;
  final SessionRepository _sessionRepo;

  AuthProvider({
    required AuthService authService,
    required UserRepository userRepo,
    required SessionRepository sessionRepo,
  })  : _authService = authService,
        _userRepo = userRepo,
        _sessionRepo = sessionRepo;

  AuthState _state = AuthState.initial;
  AuthState get state => _state;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  String? _verificationId;
  String? _error;
  String? get error => _error;

  Future<void> checkSession() async {
    _setState(AuthState.loading);
    final uid = _authService.currentUserId;
    if (uid == null) {
      _setState(AuthState.unauthenticated);
      return;
    }
    final localToken = await _sessionRepo.getLocalSessionToken();
    final firestoreToken = await _sessionRepo.getSessionToken(uid);
    if (localToken != null && localToken == firestoreToken) {
      _currentUser = await _userRepo.getUserById(uid);
      _setState(AuthState.authenticated);
    } else {
      await _authService.signOut();
      await _sessionRepo.clearSession();
      _setState(AuthState.unauthenticated);
    }
  }

  Future<void> sendOtp(String phoneNumber) async {
    _setState(AuthState.loading);
    await _authService.sendOtp(
      phoneNumber,
      onCodeSent: (verificationId) {
        _verificationId = verificationId;
        _setState(AuthState.otpSent);
      },
      onError: (error) {
        _error = error;
        _setState(AuthState.error);
      },
    );
  }

  Future<void> verifyOtp(String code) async {
    _setState(AuthState.loading);
    try {
      await _authService.verifyOtp(_verificationId!, code);
      final uid = _authService.currentUserId!;
      final user = await _userRepo.getUserById(uid);
      if (user != null) {
        final token = const Uuid().v4();
        await _sessionRepo.writeSessionToken(uid, token);
        _currentUser = user;
        _setState(AuthState.authenticated);
      } else {
        _setState(AuthState.newUser);
      }
    } catch (e) {
      _error = e.toString();
      _setState(AuthState.error);
    }
  }

  Future<void> register(String fullName, String? email) async {
    _setState(AuthState.loading);
    try {
      final uid = _authService.currentUserId!;
      final phone = _authService.currentUserPhone!;
      final token = const Uuid().v4();
      final user = UserModel(
        uid: uid,
        fullName: fullName,
        phone: phone,
        email: email,
        sessionToken: token,
        createdAt: DateTime.now(),
      );
      await _userRepo.createUser(user);
      await _sessionRepo.writeSessionToken(uid, token);
      _currentUser = user;
      _setState(AuthState.authenticated);
    } catch (e) {
      _error = e.toString();
      _setState(AuthState.error);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await _sessionRepo.clearSession();
    _currentUser = null;
    _setState(AuthState.unauthenticated);
  }

  void resetToLogin() {
    _verificationId = null;
    _error = null;
    _setState(AuthState.unauthenticated);
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }
}
