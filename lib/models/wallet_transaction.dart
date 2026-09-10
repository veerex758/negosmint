class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String type; // task_reward, referral_reward, withdrawal, deposit, adjustment
  final String status; // pending, completed, failed, reversed
  final double amount; // negative for withdrawals
  final String? description;
  final DateTime createdAt;

  factory WalletTransaction.fromMap(Map<String, dynamic> map) {
    return WalletTransaction(
      id: map['id'] as String,
      type: map['type'] as String,
      status: map['status'] as String,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class WalletBalance {
  const WalletBalance({
    required this.available,
    required this.pending,
    required this.lifetimeEarned,
  });

  final double available;
  final double pending;
  final double lifetimeEarned;

  static const zero = WalletBalance(available: 0, pending: 0, lifetimeEarned: 0);

  factory WalletBalance.fromMap(Map<String, dynamic> map) {
    return WalletBalance(
      available: (map['available'] as num).toDouble(),
      pending: (map['pending'] as num).toDouble(),
      lifetimeEarned: (map['lifetime_earned'] as num).toDouble(),
    );
  }
}
