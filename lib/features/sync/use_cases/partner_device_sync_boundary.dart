import '../../../core/measure/measure_unit.dart';
import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_actor_type.dart';

class PartnerDeviceSyncContext {
  const PartnerDeviceSyncContext({
    required this.actor,
    required this.scope,
    required this.now,
  });

  final ActorContext actor;
  final ActorScope scope;
  final DateTime now;
}

class PartnerDeviceSyncDevice {
  PartnerDeviceSyncDevice({
    required this.id,
    required this.displayName,
    this.brandOrModel,
    this.active = true,
  }) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(displayName, 'displayName');
  }

  final String id;
  final String displayName;
  final String? brandOrModel;
  final bool active;
}

class PartnerDeviceSyncTimingRecord {
  PartnerDeviceSyncTimingRecord({
    required this.id,
    required this.deviceId,
    required this.workDate,
    required this.unit,
    required this.quantityScaled,
    this.startMeterScaled,
    this.endMeterScaled,
    this.projectId,
    this.projectLabel,
    this.contact,
    this.site,
    this.incomeFen,
    this.unitPriceFen,
  }) {
    _requireNonEmpty(id, 'id');
    _requireNonEmpty(deviceId, 'deviceId');
    if (workDate <= 0) throw ArgumentError.value(workDate, 'workDate');
    if (quantityScaled <= 0) {
      throw ArgumentError.value(quantityScaled, 'quantityScaled');
    }
    if (startMeterScaled != null &&
        endMeterScaled != null &&
        endMeterScaled! < startMeterScaled!) {
      throw ArgumentError.value(endMeterScaled, 'endMeterScaled');
    }
  }

  final String id;
  final String deviceId;
  final int workDate;
  final MeasureUnit unit;
  final int quantityScaled;
  final int? startMeterScaled;
  final int? endMeterScaled;

  /// Source-side fields that must never be copied into the partner sync view.
  final String? projectId;
  final String? projectLabel;
  final String? contact;
  final String? site;
  final int? incomeFen;
  final int? unitPriceFen;
}

class PartnerDeviceSyncDeviceSnapshot {
  const PartnerDeviceSyncDeviceSnapshot({
    required this.id,
    required this.displayName,
    required this.brandOrModel,
    required this.active,
  });

  final String id;
  final String displayName;
  final String? brandOrModel;
  final bool active;

  Map<String, Object?> toMap() {
    return {
      'device_id': id,
      'display_name': displayName,
      'brand_or_model': brandOrModel,
      'active': active,
    };
  }
}

class PartnerDeviceSyncRecordSnapshot {
  const PartnerDeviceSyncRecordSnapshot({
    required this.id,
    required this.deviceId,
    required this.workDate,
    required this.unit,
    required this.quantityScaled,
    required this.startMeterScaled,
    required this.endMeterScaled,
  });

  final String id;
  final String deviceId;
  final int workDate;
  final MeasureUnit unit;
  final int quantityScaled;
  final int? startMeterScaled;
  final int? endMeterScaled;

  Map<String, Object?> toMap() {
    return {
      'record_id': id,
      'device_id': deviceId,
      'work_date': workDate,
      'unit': unit.dbValue,
      'quantity_scaled': quantityScaled,
      'start_meter_scaled': startMeterScaled,
      'end_meter_scaled': endMeterScaled,
    };
  }
}

class PartnerDeviceSyncSnapshot {
  PartnerDeviceSyncSnapshot({
    required Iterable<PartnerDeviceSyncDeviceSnapshot> devices,
    required Iterable<PartnerDeviceSyncRecordSnapshot> timingRecords,
    required Iterable<String> warnings,
    required this.redacted,
    required this.scopeLimited,
  }) : devices = List.unmodifiable(devices),
       timingRecords = List.unmodifiable(timingRecords),
       warnings = List.unmodifiable(warnings);

  final List<PartnerDeviceSyncDeviceSnapshot> devices;
  final List<PartnerDeviceSyncRecordSnapshot> timingRecords;
  final List<String> warnings;
  final bool redacted;
  final bool scopeLimited;
}

class PartnerDeviceSyncBoundary {
  const PartnerDeviceSyncBoundary({
    OperationScopePolicy scopePolicy = const OperationScopePolicy(),
    OperationPermissionPolicy permissionPolicy =
        const OperationPermissionPolicy(),
    OperationVisibilityPolicy visibilityPolicy =
        const OperationVisibilityPolicy(),
  }) : _scopePolicy = scopePolicy,
       _permissionPolicy = permissionPolicy,
       _visibilityPolicy = visibilityPolicy;

  final OperationScopePolicy _scopePolicy;
  final OperationPermissionPolicy _permissionPolicy;
  final OperationVisibilityPolicy _visibilityPolicy;

  PartnerDeviceSyncSnapshot buildSnapshot({
    required PartnerDeviceSyncContext context,
    required Iterable<PartnerDeviceSyncDevice> devices,
    required Iterable<PartnerDeviceSyncTimingRecord> timingRecords,
  }) {
    final warnings = _warningsFor(context);
    if (warnings.isNotEmpty) {
      return PartnerDeviceSyncSnapshot(
        devices: const [],
        timingRecords: const [],
        warnings: warnings,
        redacted: true,
        scopeLimited: true,
      );
    }

    final allowedDevices = <String, PartnerDeviceSyncDeviceSnapshot>{};
    for (final device in devices) {
      if (!_canAccessDevice(context, device.id)) continue;
      allowedDevices[device.id] = PartnerDeviceSyncDeviceSnapshot(
        id: device.id,
        displayName: device.displayName,
        brandOrModel: device.brandOrModel,
        active: device.active,
      );
    }

    final allowedRecords = <PartnerDeviceSyncRecordSnapshot>[];
    for (final record in timingRecords) {
      if (!allowedDevices.containsKey(record.deviceId)) continue;
      allowedRecords.add(
        PartnerDeviceSyncRecordSnapshot(
          id: record.id,
          deviceId: record.deviceId,
          workDate: record.workDate,
          unit: record.unit,
          quantityScaled: record.quantityScaled,
          startMeterScaled: record.startMeterScaled,
          endMeterScaled: record.endMeterScaled,
        ),
      );
    }

    return PartnerDeviceSyncSnapshot(
      devices: allowedDevices.values,
      timingRecords: allowedRecords,
      warnings: const [],
      redacted: true,
      scopeLimited: true,
    );
  }

  List<String> _warningsFor(PartnerDeviceSyncContext context) {
    final warnings = <String>[];
    if (context.scope.isExpired(context.now)) {
      warnings.add('scope expired');
    }
    if (context.actor.effectiveActorType != OperationActorType.partner) {
      warnings.add('partner sync requires partner actor');
    }
    if (!_permissionAllows(
          context.actor,
          OperationPermissionAction.readDevice,
        ) ||
        !_permissionAllows(
          context.actor,
          OperationPermissionAction.readTimingRecord,
        ) ||
        !_permissionAllows(
          context.actor,
          OperationPermissionAction.exportDeviceWorkHours,
        )) {
      warnings.add('actor is not allowed to read partner device sync data');
    }
    if (!_canSee(context.actor, OperationVisibilityCapability.deviceName) ||
        !_canSee(context.actor, OperationVisibilityCapability.timingBasic) ||
        !_canSee(
          context.actor,
          OperationVisibilityCapability.exportDeviceWorkHours,
        )) {
      warnings.add('actor cannot see partner device sync fields');
    }
    return List.unmodifiable(warnings);
  }

  bool _canAccessDevice(PartnerDeviceSyncContext context, String deviceId) {
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

  bool _permissionAllows(ActorContext actor, OperationPermissionAction action) {
    return _permissionPolicy.canPerform(actor: actor, action: action).allowed;
  }

  bool _canSee(ActorContext actor, OperationVisibilityCapability capability) {
    return _visibilityPolicy
        .canSee(actor: actor, capability: capability)
        .visible;
  }
}

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
