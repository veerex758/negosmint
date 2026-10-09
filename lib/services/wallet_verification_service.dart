import '../models/connected_wallet.dart';
import 'supabase_client.dart';

/// A short-lived server-issued challenge used to prove control of a wallet.
/// The message is signed locally by the wallet; private keys never enter this service.
class WalletVerificationChallenge {
  const WalletVerificationChallenge({
    required this.id,
    required this.message,
    required this.chainId,
    required this.expiresAt,
  });

  final String id;
  final String message;
  final int chainId;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);

  factory WalletVerificationChallenge.fromMap(Map<String, dynamic> map) {
    final id = map['challenge_id'];
    final message = map['message'];
    final chainId = map['chain_id'];
    final expiry = map['expires_at'];

    if (id is! String ||
        id.isEmpty ||
        message is! String ||
        message.isEmpty ||
        message.length > 2000 ||
        chainId is! num ||
        chainId.toInt() != WalletVerificationService.sepoliaChainId ||
        expiry is! String) {
      throw const WalletConnectionException(
        'The server returned an invalid wallet verification challenge.',
      );
    }

    final expiresAt = DateTime.tryParse(expiry)?.toUtc();
    if (expiresAt == null) {
      throw const WalletConnectionException(
        'The server returned an invalid challenge expiry.',
      );
    }

    final challenge = WalletVerificationChallenge(
      id: id,
      message: message,
      chainId: chainId.toInt(),
      expiresAt: expiresAt,
    );
    if (challenge.isExpired) {
      throw const WalletConnectionException(
        'The wallet verification challenge has expired. Please try again.',
      );
    }
    return challenge;
  }
}

class WalletVerificationResult {
  const WalletVerificationResult({
    required this.address,
    required this.chainId,
  });

  final String address;
  final int chainId;

  factory WalletVerificationResult.fromMap(Map<String, dynamic> map) {
    final verified = map['verified'];
    final address = map['wallet_address'];
    final chainId = map['chain_id'];

    if (verified != true ||
        address is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address) ||
        chainId is! num ||
        chainId.toInt() != WalletVerificationService.sepoliaChainId) {
      throw const WalletConnectionException(
        'The server did not confirm wallet ownership.',
      );
    }

    return WalletVerificationResult(
      address: address,
      chainId: chainId.toInt(),
    );
  }
}

class WalletConnectionException implements Exception {
  const WalletConnectionException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the verified wallet-link backend. This deliberately does not
/// write to wallet_connections, which is legacy connection metadata and is
/// not proof that a user controls the address.
class WalletVerificationService {
  WalletVerificationService._();

  static final instance = WalletVerificationService._();
  static const sepoliaChainId = 11155111;
  static const _functionName = 'verify-wallet-link';

  Future<WalletVerificationChallenge> createChallenge() async {
    _requireSignedInUser();

    final response = await supabase.functions.invoke(
      _functionName,
      body: const {'action': 'create_challenge'},
    );
    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map) {
      throw const WalletConnectionException(
        'Could not start wallet verification. Please try again.',
      );
    }

    return WalletVerificationChallenge.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  /// Submit a signature produced inside the wallet app after explicit user
  /// approval and local device authentication. Never pass a seed phrase or key.
  Future<WalletVerificationResult> verifySignature({
    required WalletVerificationChallenge challenge,
    required String walletAddress,
    required String signature,
  }) async {
    _requireSignedInUser();
    if (challenge.isExpired ||
        challenge.chainId != sepoliaChainId ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(walletAddress) ||
        !RegExp(r'^0x[0-9a-fA-F]{130}$').hasMatch(signature)) {
      throw const WalletConnectionException(
        'Wallet verification data is invalid or expired.',
      );
    }

    final response = await supabase.functions.invoke(
      _functionName,
      body: {
        'action': 'verify_signature',
        'challenge_id': challenge.id,
        'message': challenge.message,
        'signature': signature,
        'wallet_address': walletAddress,
        'chain_id': challenge.chainId,
      },
    );
    final data = response.data;
    if (response.status < 200 ||
        response.status >= 300 ||
        data is! Map) {
      throw const WalletConnectionException(
        'Wallet ownership could not be verified. Please try again.',
      );
    }

    return WalletVerificationResult.fromMap(
      Map<String, dynamic>.from(data),
    );
  }

  /// Reads only the server-verified address for the signed-in account.
  /// Row-level security prevents this client from reading other users' rows.
  Future<WalletVerificationResult?> fetchVerifiedWallet() async {
    final user = _requireSignedInUser();
    final row = await supabase
        .from('verified_wallet_addresses')
        .select('wallet_address,chain_id')
        .eq('user_id', user.id)
        .isFilter('revoked_at', null)
        .maybeSingle();

    if (row == null) return null;
    return WalletVerificationResult.fromMap({
      'verified': true,
      'wallet_address': row['wallet_address'],
      'chain_id': row['chain_id'],
    });
  }

  dynamic _requireSignedInUser() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw const WalletConnectionException(
        'Sign in to NegosMint before linking a wallet.',
      );
    }
    return user;
  }
}
