class AppProfile {
  const AppProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.referralCode,
    this.phone,
    this.avatarUrl,
    this.isAdmin = false,
  });

  final String id;
  final String username;
  final String fullName;
  final String referralCode;
  final String? phone;
  final String? avatarUrl;
  final bool isAdmin;

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      referralCode: map['referral_code'] as String,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      isAdmin: map['is_admin'] as bool? ?? false,
    );
  }
}
