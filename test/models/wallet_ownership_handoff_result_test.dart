import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint/models/wallet_ownership_handoff_result.dart';
import 'package:negosmint/services/wallet_verification_service.dart';

void main() {
  const challengeId = 'challenge-123';
  const chainId = WalletOwnershipHandoffResult.sepoliaChainId;
  const address = '0x1111111111111111111111111111111111111111';
  const signature = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Map<String, dynamic> validResult() => {
        'challengeId': challengeId,
        'walletAddress': address,
        'chainId': chainId,
        'signature': signature,
      };

  test('encodes the server challenge as a versioned wallet request link', () {
    final expiry = DateTime.utc(2026, 10, 9, 12, 2);
    const message = 'NegosMint Wallet Ownership Verification\n'
        'Purpose: Link this self-custody wallet to the signed-in NegosMint Task Platform account.\n'
        'User ID: user-123\n'
        'Challenge ID: challenge-123\n'
        'Nonce: nonce-123\n'
        'Chain ID: 11155111\n'
        'Expires At: 2026-10-09T12:02:00.000Z\n'
        'This signature proves address control only. It does not authorize a transaction.\n'
        'If you did not initiate this request, reject it.';
    final challenge = WalletVerificationChallenge(
      id: challengeId,
      message: message,
      chainId: chainId,
      expiresAt: expiry,
      userId: 'user-123',
    );

    final uri = Uri.parse(challenge.toWalletOwnershipDeepLink());
    final encoded = uri.queryParameters['request']!;
    final envelope = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
    ) as Map<String, dynamic>;

    expect(uri.scheme, 'negosmintwallet');
    expect(uri.host, 'ownership');
    expect(envelope['type'], 'negosmint.wallet_ownership_request.v1');
    expect(envelope['challengeId'], challengeId);
    expect(envelope['message'], message);
    expect(envelope['chainId'], chainId);
    expect(envelope['expiresAt'], expiry.toIso8601String());
  });

  test('parses a result matching the pending challenge', () {
    final result = WalletOwnershipHandoffResult.parse(
      validResult(),
      expectedChallengeId: challengeId,
      expectedChainId: chainId,
    );

    expect(result.challengeId, challengeId);
    expect(result.walletAddress, address);
    expect(result.chainId, chainId);
    expect(result.signature, signature);
  });

  test('rejects a result for a different challenge', () {
    expect(
      () => WalletOwnershipHandoffResult.parse(
        validResult(),
        expectedChallengeId: 'another-challenge',
        expectedChainId: chainId,
      ),
      throwsFormatException,
    );
  });

  test('rejects a wrong network', () {
    expect(
      () => WalletOwnershipHandoffResult.parse(
        validResult(),
        expectedChallengeId: challengeId,
        expectedChainId: 1,
      ),
      throwsFormatException,
    );
  });

  test('rejects a malformed wallet address', () {
    final result = validResult()..['walletAddress'] = '0x1234';
    expect(
      () => WalletOwnershipHandoffResult.parse(
        result,
        expectedChallengeId: challengeId,
        expectedChainId: chainId,
      ),
      throwsFormatException,
    );
  });

  test('rejects a malformed signature', () {
    final result = validResult()..['signature'] = '0x1234';
    expect(
      () => WalletOwnershipHandoffResult.parse(
        result,
        expectedChallengeId: challengeId,
        expectedChainId: chainId,
      ),
      throwsFormatException,
    );
  });

  test('rejects missing or non-map results', () {
    expect(
      () => WalletOwnershipHandoffResult.parse(
        null,
        expectedChallengeId: challengeId,
        expectedChainId: chainId,
      ),
      throwsFormatException,
    );
  });
}
