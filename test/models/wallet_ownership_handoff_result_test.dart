import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint/models/wallet_ownership_handoff_result.dart';

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
