class JztShareParseException implements FormatException {
  const JztShareParseException(this.code, this.message, [this.source]);

  final String code;

  @override
  final String message;

  @override
  final Object? source;

  @override
  int? get offset => null;

  @override
  String toString() => 'JztShareParseException($code): $message';
}

class JztShareErrorCodes {
  const JztShareErrorCodes._();

  static const invalidJson = 'invalid_json';
  static const missingMagic = 'missing_magic';
  static const invalidMagic = 'invalid_magic';
  static const missingFormatVersion = 'missing_format_version';
  static const unsupportedFormatVersion = 'unsupported_format_version';
  static const missingPackageType = 'missing_package_type';
  static const unsupportedPackageType = 'unsupported_package_type';
  static const invalidProducer = 'invalid_producer';
  static const invalidIntegrity = 'invalid_integrity';
  static const missingPayloadSha256 = 'missing_payload_sha256';
  static const invalidPayloadSha256 = 'invalid_payload_sha256';
  static const unsupportedPayloadEncoding = 'unsupported_payload_encoding';
  static const payloadHashMismatch = 'payload_hash_mismatch';
  static const missingPayload = 'missing_payload';
  static const invalidPayload = 'invalid_payload';
  static const invalidExportLines = 'invalid_export_lines';
  static const exportLinesTooMany = 'export_lines_too_many';
  static const invalidLine = 'invalid_line';
}
