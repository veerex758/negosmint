import 'dart:convert';
import 'dart:math';

import 'supabase_client.dart';
import '../models/connected_wallet.dart';

class WalletConnectionException implements Exception {
  const WalletConnectionException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WalletConnectionService {
  WalletConnectionService._();
  static final instance = WalletConnectionService._();

  static const appName = 'NegosMint Task Platform';
  static const appIdentifier = 'com.negosmint.taskplatform';
  static const callbackUri = 'negosmint://wallet/callback';
  static const sepoliaChainId = 11155111;
  static const permissions = <String>['READ_ADDRESS', 'READ_NETWORK'];

  Future<ConnectedWallet?> fetchConnectedWallet(String userId) async {
    final row = await supabase
        .from('wallet_connections')
        .select()
        .eq('user_id', userId)
        .isFilter('revoked_at', null)
        .maybeSingle();
    return row == null ? null : ConnectedWallet.fromMap(row);
  }

  Future<void> disconnect(String userId) async {
    await supabase
        .from('wallet_connections')
        .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('revoked_at', null);
  }

  String createConnectionRequest() {
    final request = <String, dynamic>{
      'requestId': _requestId(),
      'appName': appName,
      'appIdentifier': appIdentifier,
      'permissions': permissions,
      'chainId': sepoliaChainId,
      'callback': callbackUri,
      'expiresAt': DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String(),
    };
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(request))).replaceAll('=', '');
    return Uri(
      scheme: 'negosmintwallet',
      host: 'connect',
      queryParameters: {'request': encoded},
    ).toString();
  }

  Future<void> saveApprovedConnection({
    required String userId,
    required Map<String, dynamic> result,
    required String expectedRequestId,
  }) async {
    if (result['status'] != 'approved' || result['requestId'] != expectedRequestId) {
      throw const WalletConnectionException('Invalid wallet connection result.');
    }

    final address = result['walletAddress'];
    final chainId = result['chainId'];
    final sessionId = result['sessionId'];
    final network = result['network'];
    final rawPermissions = result['permissions'];

    if (address is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address) ||
        chainId is! int ||
        chainId != sepoliaChainId ||
        sessionId is! String ||
        sessionId.isEmpty ||
        network is! String ||
        rawPermissions is! List) {
      throw const WalletConnectionException('Wallet returned invalid connection data.');
    }

    final permissions = rawPermissions.whereType<String>().toList(growable: false);
    if (!permissions.contains('READ_ADDRESS') || !permissions.contains('READ_NETWORK')) {
      throw const WalletConnectionException('Wallet did not grant required permissions.');
    }

    final data = {
      'wallet_address': address,
      'chain_id': chainId,
      'network': network,
      'session_id': sessionId,
      'permissions': permissions,
      'connected_at': DateTime.now().toUtc().toIso8601String(),
      'last_used_at': DateTime.now().toUtc().toIso8601String(),
      'revoked_at': null,
    };

    final existing = await fetchConnectedWallet(userId);
    if (existing == null) {
      await supabase.from('wallet_connections').insert({'user_id': userId, ...data});
    } else {
      await supabase.from('wallet_connections').update(data).eq('user_id', userId);
    }
  }

  String _requestId() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
