import '../../../../core/operations/operation_access_control.dart';
import '../../../../core/operations/operation_actor_scope.dart';
import '../../../../core/operations/operation_actor_type.dart';
import '../../../../data/models/device.dart';
import '../../../../data/models/timing_record.dart';
import '../../../../data/repositories/device_repository.dart';
import '../../../../data/repositories/timing_repository.dart';

class TimingOperationReadQueryContext {
  const TimingOperationReadQueryContext({
    required this.actor,
    required this.scope,
    required this.now,
  });

  final ActorContext actor;
  final ActorScope scope;
  final DateTime now;
}

class TimingOperationQueryResult<T> {
  TimingOperationQueryResult({
    required Iterable<T> items,
    required this.redacted,
    required this.scopeLimited,
    this.warnings = const [],
    required this.hasMore,
  }) : items = List.unmodifiable(items);

  final List<T> items;
  final bool redacted;
  final bool scopeLimited;
  final List<String> warnings;
  final bool hasMore;
}

class DeviceQueryInput {
  const DeviceQueryInput({
    this.keyword,
    this.deviceId,
    this.activeOnly = false,
    this.limit = 20,
  }) : assert(limit > 0);

  final String? keyword;
  final String? deviceId;
  final bool activeOnly;
  final int limit;
}

class DeviceQueryItem {
  const DeviceQueryItem({
    required this.id,
    required this.displayName,
    required this.brandOrModel,
    required this.active,
    required this.redacted,
  });

  final String id;
  final String displayName;
  final String? brandOrModel;
  final bool active;
  final bool redacted;

  bool get enabled => active;
}

class TimingRecordQueryInput {
  const TimingRecordQueryInput({
    this.recordId,
    this.deviceId,
    this.projectId,
    this.from,
    this.to,
    this.recentOnly = false,
    this.limit = 20,
  }) : assert(limit > 0);

  final String? recordId;
  final String? deviceId;
  final String? projectId;
  final DateTime? from;
  final DateTime? to;
  final bool recentOnly;
  final int limit;
}

class TimingRecordQueryItem {
  const TimingRecordQueryItem({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.workDate,
    required this.hours,
    required this.startMeter,
    required this.endMeter,
    required this.type,
    required this.projectId,
    required this.projectLabel,
    required this.contact,
    required this.site,
    required this.redacted,
  });

  final String id;
  final String deviceId;
  final String? deviceName;
  final String workDate;
  final double hours;
  final double startMeter;
  final double endMeter;
  final String type;
  final String? projectId;
  final String? projectLabel;
  final String? contact;
  final String? site;
  final bool redacted;
}

class TimingOperationReadQueryService {
  const TimingOperationReadQueryService({
    required DeviceRepository deviceRepository,
    required TimingRepository timingRepository,
    OperationScopePolicy scopePolicy = const OperationScopePolicy(),
    OperationVisibilityPolicy visibilityPolicy =
        const OperationVisibilityPolicy(),
  }) : _deviceRepository = deviceRepository,
       _timingRepository = timingRepository,
       _scopePolicy = scopePolicy,
       _visibilityPolicy = visibilityPolicy;

  final DeviceRepository _deviceRepository;
  final TimingRepository _timingRepository;
  final OperationScopePolicy _scopePolicy;
  final OperationVisibilityPolicy _visibilityPolicy;

  Future<TimingOperationQueryResult<DeviceQueryItem>> queryDevices({
    required TimingOperationReadQueryContext context,
    DeviceQueryInput input = const DeviceQueryInput(),
  }) async {
    final warnings = _warningsForScope(context);
    if (warnings.isNotEmpty || !_canSeeDeviceName(context.actor)) {
      return TimingOperationQueryResult<DeviceQueryItem>(
        items: const [],
        redacted: _isRedacted(context.actor),
        scopeLimited: true,
        warnings: warnings,
        hasMore: false,
      );
    }

    final keyword = _normalize(input.keyword);
    final requestedDeviceId = _normalizeId(input.deviceId);
    final devices = await _deviceRepository.listAll();
    final accessible = <DeviceQueryItem>[];

    for (final device in devices) {
      final id = device.id?.toString();
      if (id == null) continue;
      if (requestedDeviceId != null && id != requestedDeviceId) continue;
      if (input.activeOnly && !device.isActive) continue;
      if (!_canAccessDevice(context, id)) continue;

      final item = _toDeviceItem(device, context);
      if (keyword.isNotEmpty && !_deviceMatchesKeyword(device, item, keyword)) {
        continue;
      }
      accessible.add(item);
    }

    final limited = accessible.take(input.limit).toList();
    return TimingOperationQueryResult<DeviceQueryItem>(
      items: limited,
      redacted: limited.any((item) => item.redacted),
      scopeLimited: _isScopeLimited(context),
      warnings: warnings,
      hasMore: accessible.length > input.limit,
    );
  }

  Future<TimingOperationQueryResult<TimingRecordQueryItem>> queryTimingRecords({
    required TimingOperationReadQueryContext context,
    TimingRecordQueryInput input = const TimingRecordQueryInput(),
  }) async {
    final warnings = _warningsForScope(context);
    if (warnings.isNotEmpty || !_canSeeTimingBasic(context.actor)) {
      return TimingOperationQueryResult<TimingRecordQueryItem>(
        items: const [],
        redacted: _isRedacted(context.actor),
        scopeLimited: true,
        warnings: warnings,
        hasMore: false,
      );
    }

    final records = await _timingRepository.listAll();
    final devices = await _deviceRepository.listAll();
    final deviceById = <int, Device>{
      for (final device in devices)
        if (device.id != null) device.id!: device,
    };

    final recordId = _normalizeId(input.recordId);
    final deviceId = _normalizeId(input.deviceId);
    final projectId = _normalizeId(input.projectId);
    final from = input.from == null ? null : _ymd(input.from!);
    final to = input.to == null ? null : _ymd(input.to!);
    final canSeeProjectFields = _canSeeProjectFields(context.actor);
    final visible = <TimingRecordQueryItem>[];

    final sorted = records.toList()
      ..sort((a, b) {
        final byDate = b.startDate.compareTo(a.startDate);
        if (byDate != 0) return byDate;
        return (b.id ?? -1).compareTo(a.id ?? -1);
      });

    for (final record in sorted) {
      final id = record.id?.toString();
      if (id == null) continue;
      if (recordId != null && id != recordId) continue;
      if (deviceId != null && record.deviceId.toString() != deviceId) {
        continue;
      }
      if (projectId != null) {
        if (!canSeeProjectFields || record.effectiveProjectId != projectId) {
          continue;
        }
      }
      if (from != null && record.startDate < from) continue;
      if (to != null && record.startDate > to) continue;
      if (!_canAccessTimingRecord(context, record)) continue;

      visible.add(
        _toTimingRecordItem(
          record,
          deviceById[record.deviceId],
          context,
          canSeeProjectFields: canSeeProjectFields,
        ),
      );
    }

    final limited = visible.take(input.limit).toList();
    return TimingOperationQueryResult<TimingRecordQueryItem>(
      items: limited,
      redacted: limited.any((item) => item.redacted),
      scopeLimited: _isScopeLimited(context),
      warnings: warnings,
      hasMore: visible.length > input.limit,
    );
  }

  DeviceQueryItem _toDeviceItem(
    Device device,
    TimingOperationReadQueryContext context,
  ) {
    final label = _deviceDisplayName(device);
    return DeviceQueryItem(
      id: device.id!.toString(),
      displayName: label,
      brandOrModel: _brandOrModel(device),
      active: device.isActive,
      redacted: _isRedacted(context.actor),
    );
  }

  TimingRecordQueryItem _toTimingRecordItem(
    TimingRecord record,
    Device? device,
    TimingOperationReadQueryContext context, {
    required bool canSeeProjectFields,
  }) {
    final redacted = _isRedacted(context.actor) || !canSeeProjectFields;
    final contact = canSeeProjectFields ? _blankToNull(record.contact) : null;
    final site = canSeeProjectFields ? _blankToNull(record.site) : null;
    return TimingRecordQueryItem(
      id: record.id!.toString(),
      deviceId: record.deviceId.toString(),
      deviceName: _canSeeDeviceName(context.actor) && device != null
          ? _deviceDisplayName(device)
          : null,
      workDate: _formatYmd(record.startDate),
      hours: record.hours,
      startMeter: record.startMeter,
      endMeter: record.endMeter,
      type: record.type.name,
      projectId: canSeeProjectFields ? record.effectiveProjectId : null,
      projectLabel: canSeeProjectFields
          ? _projectLabel(contact: contact, site: site)
          : null,
      contact: contact,
      site: site,
      redacted: redacted,
    );
  }

  bool _canAccessDevice(
    TimingOperationReadQueryContext context,
    String deviceId,
  ) {
    return _scopePolicy
        .canAccessResource(
          actor: context.actor,
          scope: context.scope,
          resourceType: OperationResourceType.device,
          resourceId: deviceId,
          now: context.now,
        )
        .allowed;
  }

  bool _canAccessTimingRecord(
    TimingOperationReadQueryContext context,
    TimingRecord record,
  ) {
    final id = record.id?.toString();
    if (id == null) return false;
    if (context.scope.isExpired(context.now) || context.scope.isEmpty) {
      return false;
    }
    if (context.actor.isUnknown || context.actor.isSystem) return false;
    if (context.actor.isAgent && !context.actor.hasDelegatedScope) return false;

    final effective = context.actor.effectiveActorType;
    switch (effective) {
      case OperationActorType.owner:
        if (context.scope.isFullOwner) return true;
        return context.scope.allowedTimingRecordIds.contains(id) ||
            context.scope.allowedDeviceIds.contains(
              record.deviceId.toString(),
            ) ||
            context.scope.allowedProjectIds.contains(record.effectiveProjectId);
      case OperationActorType.driver:
        return context.scope.allowedTimingRecordIds.contains(id) ||
            context.scope.allowedDeviceIds.contains(record.deviceId.toString());
      case OperationActorType.partner:
        return context.scope.allowedDeviceIds.contains(
          record.deviceId.toString(),
        );
      case OperationActorType.agent:
      case OperationActorType.system:
      case OperationActorType.unknown:
        return false;
    }
  }

  bool _canSeeDeviceName(ActorContext actor) {
    return _visibilityPolicy
        .canSee(
          actor: actor,
          capability: OperationVisibilityCapability.deviceName,
        )
        .visible;
  }

  bool _canSeeTimingBasic(ActorContext actor) {
    return _visibilityPolicy
        .canSee(
          actor: actor,
          capability: OperationVisibilityCapability.timingBasic,
        )
        .visible;
  }

  bool _canSeeProjectFields(ActorContext actor) {
    return _visibilityPolicy
            .canSee(
              actor: actor,
              capability: OperationVisibilityCapability.projectLabel,
            )
            .visible &&
        _visibilityPolicy
            .canSee(
              actor: actor,
              capability: OperationVisibilityCapability.contactSite,
            )
            .visible;
  }

  bool _isScopeLimited(TimingOperationReadQueryContext context) {
    return context.scope.isExpired(context.now) ||
        !context.scope.isFullOwner ||
        context.actor.effectiveActorType != OperationActorType.owner;
  }

  bool _isRedacted(ActorContext actor) {
    return actor.effectiveActorType != OperationActorType.owner;
  }

  List<String> _warningsForScope(TimingOperationReadQueryContext context) {
    if (context.scope.isExpired(context.now)) {
      return const ['scope expired'];
    }
    return const [];
  }
}

bool _deviceMatchesKeyword(
  Device device,
  DeviceQueryItem item,
  String keyword,
) {
  return item.id.contains(keyword) ||
      item.displayName.toLowerCase().contains(keyword) ||
      (item.brandOrModel?.toLowerCase().contains(keyword) ?? false) ||
      device.brand.toLowerCase().contains(keyword) ||
      (device.model?.toLowerCase().contains(keyword) ?? false);
}

String _deviceDisplayName(Device device) {
  final name = device.name.trim();
  if (name.isNotEmpty) return name;
  final brandOrModel = _brandOrModel(device);
  if (brandOrModel != null) return brandOrModel;
  final id = device.id;
  return id == null ? '设备' : '设备 $id';
}

String? _brandOrModel(Device device) {
  final parts = [
    device.brand.trim(),
    if (device.model != null) device.model!.trim(),
  ].where((value) => value.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  return parts.join(' ');
}

String _formatYmd(int ymd) {
  final raw = ymd.toString().padLeft(8, '0');
  if (raw.length != 8) return raw;
  return '${raw.substring(0, 4)}-${raw.substring(4, 6)}-${raw.substring(6, 8)}';
}

int _ymd(DateTime value) {
  return value.year * 10000 + value.month * 100 + value.day;
}

String _normalize(String? value) {
  return value?.trim().toLowerCase() ?? '';
}

String? _normalizeId(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _projectLabel({required String? contact, required String? site}) {
  final parts = [contact, site]
      .where((value) => value != null && value.trim().isNotEmpty)
      .cast<String>()
      .toList();
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}
