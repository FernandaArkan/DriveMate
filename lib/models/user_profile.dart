class UserProfile {
  UserProfile({
    this.id = 1,
    required this.name,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.isBiometricEnabled = false,
    this.token,
    this.passwordHash,
  });

  final int id;
  String name;
  String email;
  String phone;
  String? avatarUrl;
  bool isBiometricEnabled;
  String? token;
  String? passwordHash;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'isBiometricEnabled': isBiometricEnabled ? 1 : 0,
      'token': token,
      'passwordHash': passwordHash,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as int? ?? 1,
      name: map['name'] as String? ?? 'Pengguna DriveMate',
      email: map['email'] as String? ?? 'user@drivemate.id',
      phone: map['phone'] as String? ?? '081234567890',
      avatarUrl: map['avatarUrl'] as String?,
      isBiometricEnabled: (map['isBiometricEnabled'] as int? ?? 0) == 1,
      token: map['token'] as String?,
      passwordHash: map['passwordHash'] as String?,
    );
  }

  UserProfile copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? isBiometricEnabled,
    String? token,
    String? passwordHash,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      token: token ?? this.token,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }
}
