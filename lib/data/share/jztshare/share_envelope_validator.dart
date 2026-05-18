import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'jztshare_errors.dart';

class JztShareEnvelopeValidator {
  const JztShareEnvelopeValidator._();

  static final RegExp payloadSha256Pattern = RegExp(r'^[a-fA-F0-9]{64}$');

  static String canonicalJson(Object? value) {
    return jsonEncode(_canonicalValue(value));
  }

  static String payloadSha256(Map<String, Object?> payload) {
    final bytes = utf8.encode(canonicalJson(payload));
    return sha256.convert(bytes).toString();
  }

  static void verifyPayloadSha256({
    required Map<String, Object?> payload,
    required String expectedSha256,
  }) {
    if (!payloadSha256Pattern.hasMatch(expectedSha256)) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidPayloadSha256,
        'integrity.payload_sha256 must be a 64-character hex string',
        expectedSha256,
      );
    }
    final actual = payloadSha256(payload);
    if (actual != expectedSha256.toLowerCase()) {
      throw JztShareParseException(
        JztShareErrorCodes.payloadHashMismatch,
        'payload_sha256 does not match canonical payload JSON',
        expectedSha256,
      );
    }
  }

  static Object? _canonicalValue(Object? value) {
    if (value == null || value is String || value is bool || value is num) {
      return value;
    }
    if (value is List<Object?>) {
      return value.map(_canonicalValue).toList(growable: false);
    }
    if (value is Map<String, Object?>) {
      final sortedKeys = value.keys.toList()..sort();
      return {for (final key in sortedKeys) key: _canonicalValue(value[key])};
    }
    throw JztShareParseException(
      JztShareErrorCodes.invalidPayload,
      'payload contains an unsupported JSON value',
      value,
    );
  }
}
