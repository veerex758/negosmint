import 'supabase_client.dart';

class CryptoWithdrawalResult {
  const CryptoWithdrawalResult({
    required this.withdrawalId,
    required this.txHash,
    required this.network,
    required this.asset,
  });
  final String withdrawalId;
  final String txHash;
  final String network;
  final String asset;
}

class CryptoWalletService {
  CryptoWalletService._();
  static final instance = CryptoWalletService._();

  Future<CryptoWithdrawalResult> withdraw({
    required double amount,
    required String asset,
    required String network,
    required String walletAddress,
  }) async {
    final response = await supabase.functions.invoke(
      'crypto-withdrawal',
      body: {
        'amount': amount,
        'asset': asset,
        'network': network,
        'wallet_address': walletAddress.trim(),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Crypto withdrawal failed';
      throw Exception(message);
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    return CryptoWithdrawalResult(
      withdrawalId: data['withdrawal_id'].toString(),
      txHash: data['tx_hash'].toString(),
      network: data['network'].toString(),
      asset: data['asset'].toString(),
    );
  }
}
