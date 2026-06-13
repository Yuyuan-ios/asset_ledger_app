import 'dart:convert';

import 'package:asset_ledger/infrastructure/cloud/cloud_backup_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'high-entropy-account-secret-AbC123XyZ987';
  const plaintext = '{"data":{"projects":[{"id":"p1"}]},"v":36}';

  group('CloudBackupCipher', () {
    test('encrypt then decrypt round-trips the plaintext', () async {
      final enc = await CloudBackupCipher.encrypt(
        plaintext: plaintext,
        accountSecret: secret,
      );
      expect(enc.keyId, CloudBackupCipher.keyIdFor(secret));
      expect(enc.plaintextBytes, utf8.encode(plaintext).length);

      final clear = await CloudBackupCipher.decrypt(
        cipherTextBase64: enc.cipherTextBase64,
        saltBase64: enc.saltBase64,
        nonceBase64: enc.nonceBase64,
        expectedPlaintextSha256: enc.plaintextSha256,
        accountSecret: secret,
      );
      expect(clear, plaintext);
    });

    test('ciphertext is not the plaintext and salt/nonce vary per call',
        () async {
      final a = await CloudBackupCipher.encrypt(
        plaintext: plaintext,
        accountSecret: secret,
      );
      final b = await CloudBackupCipher.encrypt(
        plaintext: plaintext,
        accountSecret: secret,
      );
      expect(a.cipherTextBase64, isNot(contains('projects')));
      // 每次随机 salt/nonce → 同明文密文不同(防止可链接性)。
      expect(a.cipherTextBase64, isNot(b.cipherTextBase64));
      expect(a.saltBase64, isNot(b.saltBase64));
      expect(a.nonceBase64, isNot(b.nonceBase64));
    });

    test('wrong account secret fails authentication', () async {
      final enc = await CloudBackupCipher.encrypt(
        plaintext: plaintext,
        accountSecret: secret,
      );
      await expectLater(
        CloudBackupCipher.decrypt(
          cipherTextBase64: enc.cipherTextBase64,
          saltBase64: enc.saltBase64,
          nonceBase64: enc.nonceBase64,
          expectedPlaintextSha256: enc.plaintextSha256,
          accountSecret: 'a-different-secret',
        ),
        throwsA(
          isA<CloudBackupCipherException>().having(
            (e) => e.code,
            'code',
            'decrypt_failed',
          ),
        ),
      );
    });

    test('tampered ciphertext is rejected by the GCM tag', () async {
      final enc = await CloudBackupCipher.encrypt(
        plaintext: plaintext,
        accountSecret: secret,
      );
      final bytes = base64Decode(enc.cipherTextBase64);
      bytes[0] = bytes[0] ^ 0xFF; // flip a byte
      await expectLater(
        CloudBackupCipher.decrypt(
          cipherTextBase64: base64Encode(bytes),
          saltBase64: enc.saltBase64,
          nonceBase64: enc.nonceBase64,
          expectedPlaintextSha256: enc.plaintextSha256,
          accountSecret: secret,
        ),
        throwsA(isA<CloudBackupCipherException>()),
      );
    });

    test('different accounts get different key ids', () {
      expect(
        CloudBackupCipher.keyIdFor('account-a'),
        isNot(CloudBackupCipher.keyIdFor('account-b')),
      );
      expect(CloudBackupCipher.keyIdFor(secret), hasLength(16));
    });

    test('empty account secret is rejected', () async {
      await expectLater(
        CloudBackupCipher.encrypt(plaintext: plaintext, accountSecret: ''),
        throwsA(
          isA<CloudBackupCipherException>().having(
            (e) => e.code,
            'code',
            'empty_account_secret',
          ),
        ),
      );
    });
  });
}
