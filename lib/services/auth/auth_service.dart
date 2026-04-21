abstract class AuthService {
  Future<void> sendOtp(
    String phoneNumber, {
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  });

  Future<void> verifyOtp(String verificationId, String smsCode);

  Future<void> signOut();

  String? get currentUserId;

  String? get currentUserPhone;
}
