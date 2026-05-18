import 'dart:convert';

import '../../models/external_work_parse.dart';
import 'jztshare_errors.dart';
import 'project_external_work_share_payload.dart';
import 'share_envelope.dart';
import 'share_envelope_validator.dart';

class ParsedProjectExternalWorkShare {
  const ParsedProjectExternalWorkShare({
    required this.envelope,
    required this.payload,
  });

  final JztShareEnvelope envelope;
  final ProjectExternalWorkSharePayload payload;
}

class JztShareEnvelopeParser {
  const JztShareEnvelopeParser();

  ParsedProjectExternalWorkShare parseProjectExternalWorkShare(String input) {
    final root = _decodeRoot(input);
    final envelope = _parseEnvelope(root);
    final payload = ProjectExternalWorkSharePayload.fromMap(envelope.payload);
    return ParsedProjectExternalWorkShare(envelope: envelope, payload: payload);
  }

  Map<String, Object?> _decodeRoot(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is Map<String, Object?>) return decoded;
      throw const JztShareParseException(
        JztShareErrorCodes.invalidJson,
        'jztshare content must be a JSON object',
      );
    } on JztShareParseException {
      rethrow;
    } on FormatException catch (error) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidJson,
        'jztshare content is not valid JSON',
        error.source,
      );
    }
  }

  JztShareEnvelope _parseEnvelope(Map<String, Object?> root) {
    final magic = _requiredString(
      root,
      'magic',
      missingCode: JztShareErrorCodes.missingMagic,
    );
    if (magic != JztShareEnvelope.magicValue) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidMagic,
        'magic does not match ${JztShareEnvelope.magicValue}',
        magic,
      );
    }

    final formatVersion = _requiredInt(
      root,
      'format_version',
      missingCode: JztShareErrorCodes.missingFormatVersion,
    );
    if (formatVersion != JztShareEnvelope.supportedFormatVersion) {
      throw JztShareParseException(
        JztShareErrorCodes.unsupportedFormatVersion,
        'format_version $formatVersion is not supported',
        formatVersion,
      );
    }

    final packageType = _requiredString(
      root,
      'package_type',
      missingCode: JztShareErrorCodes.missingPackageType,
    );
    if (packageType != JztShareEnvelope.projectExternalWorkShareType) {
      throw JztShareParseException(
        JztShareErrorCodes.unsupportedPackageType,
        'package_type $packageType is not supported',
        packageType,
      );
    }

    final producer = _parseProducer(root['producer']);
    final integrity = _parseIntegrity(root['integrity']);
    final payload = _parsePayload(root['payload']);

    JztShareEnvelopeValidator.verifyPayloadSha256(
      payload: payload,
      expectedSha256: integrity.payloadSha256,
    );

    return JztShareEnvelope(
      magic: magic,
      formatVersion: formatVersion,
      packageType: packageType,
      producer: producer,
      createdAt: _requiredString(root, 'created_at'),
      shareId: _requiredString(root, 'share_id'),
      integrity: integrity,
      payload: payload,
    );
  }

  JztShareProducer _parseProducer(Object? rawProducer) {
    if (rawProducer is! Map<String, Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidProducer,
        'producer must be an object',
        rawProducer,
      );
    }
    return JztShareProducer(
      appName: _requiredString(rawProducer, 'app_name'),
      appVersion: _requiredString(rawProducer, 'app_version'),
      platform: _requiredString(rawProducer, 'platform'),
    );
  }

  JztShareIntegrity _parseIntegrity(Object? rawIntegrity) {
    if (rawIntegrity is! Map<String, Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.invalidIntegrity,
        'integrity must be an object',
        rawIntegrity,
      );
    }
    final payloadEncoding = _requiredString(rawIntegrity, 'payload_encoding');
    if (payloadEncoding != JztShareEnvelope.jsonPayloadEncoding) {
      throw JztShareParseException(
        JztShareErrorCodes.unsupportedPayloadEncoding,
        'integrity.payload_encoding must be json',
        payloadEncoding,
      );
    }
    return JztShareIntegrity(
      payloadEncoding: payloadEncoding,
      payloadSha256: _requiredString(
        rawIntegrity,
        'payload_sha256',
        missingCode: JztShareErrorCodes.missingPayloadSha256,
      ),
    );
  }

  Map<String, Object?> _parsePayload(Object? rawPayload) {
    if (rawPayload is! Map<String, Object?>) {
      throw JztShareParseException(
        JztShareErrorCodes.missingPayload,
        'payload must be an object',
        rawPayload,
      );
    }
    return rawPayload;
  }

  String _requiredString(
    Map<String, Object?> map,
    String key, {
    String? missingCode,
  }) {
    try {
      return ExternalFieldReader(map).requiredString(key);
    } on ExternalDataParseException catch (error) {
      throw JztShareParseException(
        missingCode ?? JztShareErrorCodes.invalidPayload,
        error.message,
        map,
      );
    }
  }

  int _requiredInt(
    Map<String, Object?> map,
    String key, {
    String? missingCode,
  }) {
    try {
      return ExternalFieldReader(map).requiredNonNegativeInt(key);
    } on ExternalDataParseException catch (error) {
      throw JztShareParseException(
        missingCode ?? JztShareErrorCodes.invalidPayload,
        error.message,
        map,
      );
    }
  }
}
