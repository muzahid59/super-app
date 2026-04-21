import '../models/user_model.dart';

abstract class UserRepository {
  Future<void> createUser(UserModel user);
  Future<UserModel?> getUserById(String uid);
}
