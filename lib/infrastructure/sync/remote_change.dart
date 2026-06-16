import 'dart:convert';

class RemoteChangesResponse {
  const RemoteChangesResponse({
    required this.changes,
    required this.nextCursor,
  });

  final List<RemoteChange> changes;
  final int nextCursor;

  static RemoteChangesResponse parse(String? bodyJson) {
    if (bodyJson == null || bodyJson.isEmpty) {
      throw const FormatException('pull response body is empty');
    }
    final decoded = jsonDecode(bodyJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('pull response must be a JSON object');
    }
    final rawChanges = decoded['changes'];
    if (rawChanges is! List) {
      throw const FormatException('pull response changes must be an array');
    }
    final changes =
        rawChanges.map((raw) => RemoteChange.parse(raw)).toList(growable: false)
          ..sort((a, b) => a.serverSeq.compareTo(b.serverSeq));
    return RemoteChangesResponse(
      changes: changes,
      nextCursor: _requiredInt(decoded['next_cursor'], 'next_cursor'),
    );
  }
}

class RemoteChange {
  const RemoteChange({
    required this.serverSeq,
    required this.entityType,
    required this.entityId,
    required this.baseVersion,
    required this.newVersion,
    required this.payloadJson,
    required this.payloadHash,
    required this.deleted,
    this.originDeviceId,
  });

  final int serverSeq;
  final String entityType;
  final String entityId;
  final int baseVersion;
  final int newVersion;
  final String payloadJson;
  final String payloadHash;
  final bool deleted;
  final String? originDeviceId;

  static RemoteChange parse(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const FormatException('remote change must be a JSON object');
    }
    return RemoteChange(
      serverSeq: _requiredInt(raw['server_seq'], 'server_seq'),
      entityType: _requiredString(raw['entity_type'], 'entity_type'),
      entityId: _requiredString(raw['entity_id'], 'entity_id'),
      baseVersion: _requiredInt(raw['base_version'], 'base_version'),
      newVersion: _requiredInt(raw['new_version'], 'new_version'),
      payloadJson: _payloadJson(raw['payload_json']),
      payloadHash: _requiredString(raw['payload_hash'], 'payload_hash'),
      deleted: _boolValue(raw['deleted'], 'deleted'),
      originDeviceId: _optionalString(raw['origin_device_id']),
    );
  }
}

int _requiredInt(Object? value, String name) {
  if (value is int) return value;
  if (value is num && value % 1 == 0) return value.toInt();
  throw FormatException('$name must be an integer');
}

String _requiredString(Object? value, String name) {
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('$name must be a non-empty string');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  return null;
}

String _payloadJson(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  if (value is Map || value is List) return jsonEncode(value);
  throw const FormatException('payload_json must be JSON text');
}

bool _boolValue(Object? value, String name) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  throw FormatException('$name must be a boolean');
}
