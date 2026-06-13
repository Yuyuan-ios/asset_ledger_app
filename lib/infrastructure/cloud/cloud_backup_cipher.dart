import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as legacy_hash;

/// 账号绑定的备份密钥材料提供者。
///
/// 返回**高熵且稳定**的密钥材料（随账号、不随 access token 轮换）：换机重新
/// 登录拿到同一份材料即可解密旧备份。null = 当前不可用（未登录/后端未下发）
/// → 加密不可用。
///
/// 安全要求:accountSecret 必须由账号服务在登录时下发的高熵秘密(不是手机号、
/// 不是会轮换的 authToken)。低熵材料会让 [CloudBackupCipher.keyIdFor] 暴露的
/// 指纹可被暴力猜解。
abstract class CloudBackupKeyProvider {
  Future<String?> accountSecret();
}

/// 把一个 `Future<String?>` 回调包成 [CloudBackupKeyProvider]，供 composition
/// root 从账号会话注入账号密钥来源。
class CallbackCloudBackupKeyProvider implements CloudBackupKeyProvider {
  const CallbackCloudBackupKeyProvider(this._source);

  final Future<String?> Function() _source;

  @override
  Future<String?> accountSecret() => _source();
}

class CloudBackupCipherException implements Exception {
  const CloudBackupCipherException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CloudBackupCipherException($code): $message';
}

/// 加密结果（密文 + 解密所需的非秘密元数据）。
class CloudBackupEncryptedPayload {
  const CloudBackupEncryptedPayload({
    required this.cipherTextBase64,
    required this.saltBase64,
    required this.nonceBase64,
    required this.keyId,
    required this.plaintextSha256,
    required this.plaintextBytes,
  });

  /// base64(密文 ++ GCM tag)。作为信封的 payload_json 上传。
  final String cipherTextBase64;
  final String saltBase64;
  final String nonceBase64;

  /// 账号密钥指纹（单向）,恢复时用于「此备份是否属于当前账号」的快速判定。
  final String keyId;

  /// 原始明文的 sha256（端到端完整性,解密后二次校验）。
  final String plaintextSha256;
  final int plaintextBytes;
}

/// 云备份 payload 的客户端加密（AES-256-GCM + HKDF-SHA256，零知识：后端 OSS
/// 只存密文）。
///
/// 设计:
/// - 密钥 = HKDF-SHA256(ikm=accountSecret, salt=每次随机 16B, info=固定标签)
///   → 32B AES 密钥;salt 随信封走,accountSecret 永不离开本机。
/// - AES-256-GCM 提供机密性 + 完整性(tag);解密后再比对明文 sha256 双保险。
/// - keyId = sha256('keyid:'+accountSecret) 前 16 位,单向指纹,用于换账号恢复
///   时给出「此备份属于其他账号」的明确错误,而非笼统解密失败。
class CloudBackupCipher {
  const CloudBackupCipher._();

  static const String algoName = 'AES-256-GCM';
  static const String kdfName = 'HKDF-SHA256';
  static const String _hkdfInfo = 'fleet-ledger-cloud-backup-v1';

  static final AesGcm _aes = AesGcm.with256bits();

  static String keyIdFor(String accountSecret) {
    return legacy_hash.sha256
        .convert(utf8.encode('keyid:$accountSecret'))
        .toString()
        .substring(0, 16);
  }

  static Future<CloudBackupEncryptedPayload> encrypt({
    required String plaintext,
    required String accountSecret,
  }) async {
    if (accountSecret.isEmpty) {
      throw const CloudBackupCipherException(
        'empty_account_secret',
        '账号密钥材料为空，无法加密',
      );
    }
    final plaintextBytes = utf8.encode(plaintext);
    final salt = _randomBytes(16);
    final key = await _deriveKey(accountSecret, salt);
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(
      plaintextBytes,
      secretKey: key,
      nonce: nonce,
    );
    final combined = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    return CloudBackupEncryptedPayload(
      cipherTextBase64: base64Encode(combined),
      saltBase64: base64Encode(salt),
      nonceBase64: base64Encode(nonce),
      keyId: keyIdFor(accountSecret),
      plaintextSha256: legacy_hash.sha256.convert(plaintextBytes).toString(),
      plaintextBytes: plaintextBytes.length,
    );
  }

  static Future<String> decrypt({
    required String cipherTextBase64,
    required String saltBase64,
    required String nonceBase64,
    required String expectedPlaintextSha256,
    required String accountSecret,
  }) async {
    if (accountSecret.isEmpty) {
      throw const CloudBackupCipherException(
        'empty_account_secret',
        '账号密钥材料为空，无法解密',
      );
    }
    final Uint8List combined;
    final Uint8List salt;
    final Uint8List nonce;
    try {
      combined = base64Decode(cipherTextBase64);
      salt = base64Decode(saltBase64);
      nonce = base64Decode(nonceBase64);
    } on FormatException {
      throw const CloudBackupCipherException(
        'invalid_ciphertext',
        '密文编码无效',
      );
    }
    if (combined.length < 16) {
      throw const CloudBackupCipherException(
        'invalid_ciphertext',
        '密文长度不足，缺少认证标签',
      );
    }
    final macBytes = combined.sublist(combined.length - 16);
    final cipherText = combined.sublist(0, combined.length - 16);
    final key = await _deriveKey(accountSecret, salt);
    final List<int> clear;
    try {
      clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const CloudBackupCipherException(
        'decrypt_failed',
        '解密失败：密钥不匹配或数据被篡改',
      );
    }
    if (legacy_hash.sha256.convert(clear).toString() !=
        expectedPlaintextSha256.toLowerCase()) {
      throw const CloudBackupCipherException(
        'plaintext_hash_mismatch',
        '解密后明文完整性校验失败',
      );
    }
    return utf8.decode(clear);
  }

  static Future<SecretKey> _deriveKey(String accountSecret, List<int> salt) {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(accountSecret)),
      nonce: salt,
      info: utf8.encode(_hkdfInfo),
    );
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = random.nextInt(256);
    }
    return out;
  }
}
