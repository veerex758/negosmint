class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.username,
    required this.fullName,
    required this.isAdmin,
    required this.isSuspended,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String fullName;
  final bool isAdmin;
  final bool isSuspended;
  final DateTime createdAt;

  factory AdminUserRow.fromMap(Map<String, dynamic> map) {
    return AdminUserRow(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String,
      isAdmin: map['is_admin'] as bool? ?? false,
      isSuspended: map['is_suspended'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
