class ConnectedWallet {
  const ConnectedWallet({
    required this.walletAddress,
    required this.chainId,
    required this.network,
    required this.sessionId,
    required this.permissions,
    required this.connectedAt,
    required this.lastUsedAt,
  });

  final String walletAddress;
  final int chainId;
  final String network;
  final String sessionId;
  final List<String> permissions;
  final DateTime connectedAt;
  final DateTime lastUsedAt;

  factory ConnectedWallet.fromMap(Map<String, dynamic> map) {
    return ConnectedWallet(
      walletAddress: map['wallet_address'] as String,
      chainId: (map['chain_id'] as num).toInt(),
      network: map['network'] as String,
      sessionId: map['session_id'] as String,
      permissions: (map['permissions'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      connectedAt: DateTime.parse(map['connected_at'] as String),
      lastUsedAt: DateTime.parse(map['last_used_at'] as String),
    );
  }
}
