class UserModel {
  final String uid;
  final String fullName;
  final String phone;
  final String? email;
  final String sessionToken;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.fullName,
    required this.phone,
    this.email,
    required this.sessionToken,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      fullName: map['fullName'] as String,
      phone: map['phone'] as String,
      email: map['email'] as String?,
      sessionToken: map['sessionToken'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'phone': phone,
      if (email != null) 'email': email,
      'sessionToken': sessionToken,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
