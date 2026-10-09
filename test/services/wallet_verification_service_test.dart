import 'package:flutter_test/flutter_test.dart';
import 'package:negosmint/services/wallet_verification_service.dart';

void main() {
  test('challenge is bound to the requesting account', () {
    final challenge = WalletVerificationChallenge.fromMap({
      'challenge_id': 'challenge-123',
      'message': 'NegosMint Wallet Ownership Verification',
      'chain_id': WalletVerificationService.sepoliaChainId,
      'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
    }, userId: 'task-user-a');

    expect(challenge.userId, 'task-user-a');
    expect(challenge.isExpired, isFalse);
  });

  test('rejects an empty account binding', () {
    expect(() => WalletVerificationChallenge.fromMap({
      'challenge_id': 'challenge-123',
      'message': 'NegosMint Wallet Ownership Verification',
      'chain_id': WalletVerificationService.sepoliaChainId,
      'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
    }, userId: ''), throwsA(isA<WalletConnectionException>()));
  });

  test('rejects a challenge on the wrong chain', () {
    expect(() => WalletVerificationChallenge.fromMap({
      'challenge_id': 'challenge-123',
      'message': 'NegosMint Wallet Ownership Verification',
      'chain_id': 1,
      'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 4)).toIso8601String(),
    }, userId: 'task-user-a'), throwsA(isA<WalletConnectionException>()));
  });
}
