import 'package:flutter/foundation.dart';

/// Validates the untrusted result returned by the separate NegosMint Wallet.
///
/// Parsing this result does not establish ownership. The Task App must still
/// submit the signature to its authenticated verification endpoint.
@immutable
class WalletOwnershipHandoffResult {
  const WalletOwnershipHandoffResult({
    required this.challengeId,
    required this.walletAddress,
    required this.chainId,
    required this.signature,
  });

  static const sepoliaChainId = 11155111;

  final String challengeId;
  final String walletAddress;
  final int chainId;
  final String signature;

  factory WalletOwnershipHandoffResult.parse(
    Object? input, {
    required String expectedChallengeId,
    required int expectedChainId,
  }) {
    if (input is! Map ||
        expectedChallengeId.trim().isEmpty ||
        expectedChainId != sepoliaChainId) {
      throw const FormatException('Invalid wallet verification result.');
    }

    final map = Map<String, dynamic>.from(input);
    final challengeId = map['challengeId'];
    final walletAddress = map['walletAddress'];
    final chainId = map['chainId'];
    final signature = map['signature'];

    if (challengeId is! String ||
        challengeId != expectedChallengeId ||
        walletAddress is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(walletAddress) ||
        chainId is! int ||
        chainId != expectedChainId ||
        signature is! String ||
        !RegExp(r'^0x[0-9a-fA-F]{130}$').hasMatch(signature)) {
      throw const FormatException('Invalid wallet verification result.');
    }

    return WalletOwnershipHandoffResult(
      challengeId: challengeId,
      walletAddress: walletAddress,
      chainId: chainId,
      signature: signature,
    );
  }
}
