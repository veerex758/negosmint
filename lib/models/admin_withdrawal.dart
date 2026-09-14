class AdminWithdrawal {
  const AdminWithdrawal({
    required this.id,
    required this.userId,
    required this.username,
    required this.amount,
    required this.fee,
    required this.method,
    required this.status,
    required this.transactionRef,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String username;
  final double amount;
  final double fee;
  final String method;
  final String status; // pending, approved, rejected, completed
  final String transactionRef;
  final DateTime createdAt;

  factory AdminWithdrawal.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return AdminWithdrawal(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: profile?['username'] as String? ?? 'Unknown',
      amount: (map['amount'] as num).toDouble(),
      fee: (map['fee'] as num).toDouble(),
      method: map['method'] as String,
      status: map['status'] as String,
      transactionRef: map['transaction_ref'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
