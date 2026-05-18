class ExternalDataParseException implements FormatException {
  const ExternalDataParseException(this.message, [this.source, this.offset]);

  @override
  final String message;

  @override
  final Object? source;

  @override
  final int? offset;

  @override
  String toString() => 'ExternalDataParseException: $message';
}

class ExternalFieldReader {
  const ExternalFieldReader(this.map);

  static const int maxInteger = 1000000000000;

  final Map<String, Object?> map;

  String requiredString(String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw ExternalDataParseException('Missing required string: $key', map);
    }
    return value.trim();
  }

  String? optionalString(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String) {
      throw ExternalDataParseException('Invalid string: $key', map);
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  int requiredNonNegativeInt(String key) {
    final value = map[key];
    if (value is! int) {
      throw ExternalDataParseException('Missing required integer: $key', map);
    }
    if (value < 0 || value > maxInteger) {
      throw ExternalDataParseException('Integer out of range: $key', map);
    }
    return value;
  }

  int? optionalNonNegativeInt(String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! int) {
      throw ExternalDataParseException('Invalid integer: $key', map);
    }
    if (value < 0 || value > maxInteger) {
      throw ExternalDataParseException('Integer out of range: $key', map);
    }
    return value;
  }
}

T parseExternalStatus<T>({
  required Object? raw,
  required List<T> values,
  required String Function(T value) nameOf,
  required T fallback,
}) {
  if (raw == null) return fallback;
  if (raw is String) {
    for (final value in values) {
      if (nameOf(value) == raw) return value;
    }
  }
  throw ExternalDataParseException('Invalid external status: $raw', raw);
}
