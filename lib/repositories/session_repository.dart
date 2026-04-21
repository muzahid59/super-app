abstract class SessionRepository {
  Future<void> writeSessionToken(String uid, String token);
  Future<String?> getSessionToken(String uid);
  Future<void> clearSession();
  Future<String?> getLocalSessionToken();
}
