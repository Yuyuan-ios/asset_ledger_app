import '../../../core/operations/operation_access_control.dart';
import '../../../core/operations/operation_actor_scope.dart';
import '../../../core/operations/operation_actor_type.dart';

enum McpReadQueryType { devices, projects, receivables, paymentStatus }

class McpReadQueryContext {
  const McpReadQueryContext({
    required this.actor,
    required this.scope,
    required this.now,
  });

  final ActorContext actor;
  final ActorScope scope;
  final DateTime now;
}

class McpReadQueryRequest {
  const McpReadQueryRequest({required this.type, this.keyword});

  final McpReadQueryType type;
  final String? keyword;
}

class McpReadQueryResult {
  McpReadQueryResult({
    required Iterable<Map<String, Object?>> items,
    required Iterable<String> warnings,
    required this.redacted,
    required this.scopeLimited,
  }) : items = List.unmodifiable(
         items.map((item) => Map<String, Object?>.unmodifiable(item)),
       ),
       warnings = List.unmodifiable(warnings);

  final List<Map<String, Object?>> items;
  final List<String> warnings;
  final bool redacted;
  final bool scopeLimited;
}

class McpDeviceFact {
  McpDeviceFact({
    required this.deviceId,
    required this.displayName,
    this.brandOrModel,
    this.active = true,
    this.localDeviceId,
    this.deviceAutoNumber,
  }) {
    _requireNonEmpty(deviceId, 'deviceId');
    _requireNonEmpty(displayName, 'displayName');
  }

  final String deviceId;
  final String displayName;
  final String? brandOrModel;
  final bool active;
  final String? localDeviceId;
  final String? deviceAutoNumber;
}

class McpProjectFact {
  McpProjectFact({
    required this.projectId,
    required this.projectLabel,
    this.contact,
    this.site,
    this.shareId,
    this.phone,
  }) {
    _requireNonEmpty(projectId, 'projectId');
    _requireNonEmpty(projectLabel, 'projectLabel');
  }

  final String projectId;
  final String projectLabel;
  final String? contact;
  final String? site;
  final String? shareId;
  final String? phone;
}

class McpReceivableFact {
  McpReceivableFact({
    required this.projectId,
    required this.projectLabel,
    required this.receivableFen,
    required this.receivedFen,
    required this.writeOffFen,
    required this.remainingFen,
    required this.paymentStatus,
  }) {
    _requireNonEmpty(projectId, 'projectId');
    _requireNonEmpty(projectLabel, 'projectLabel');
  }

  final String projectId;
  final String projectLabel;
  final int receivableFen;
  final int receivedFen;
  final int writeOffFen;
  final int remainingFen;
  final String paymentStatus;
}

class McpReadLedgerFacts {
  McpReadLedgerFacts({
    required Iterable<McpDeviceFact> devices,
    required Iterable<McpProjectFact> projects,
    required Iterable<McpReceivableFact> receivables,
  }) : devices = List.unmodifiable(devices),
       projects = List.unmodifiable(projects),
       receivables = List.unmodifiable(receivables);

  final List<McpDeviceFact> devices;
  final List<McpProjectFact> projects;
  final List<McpReceivableFact> receivables;
}

class McpReadQueryMock {
  const McpReadQueryMock({
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

  McpReadQueryResult query({
    required McpReadQueryContext context,
    required McpReadLedgerFacts facts,
    required McpReadQueryRequest request,
  }) {
    final warnings = _warningsFor(context);
    if (warnings.isNotEmpty) {
      return _empty(context, warnings);
    }

    switch (request.type) {
      case McpReadQueryType.devices:
        return _queryDevices(context, facts.devices, request.keyword);
      case McpReadQueryType.projects:
        return _queryProjects(context, facts.projects, request.keyword);
      case McpReadQueryType.receivables:
        return _queryReceivables(context, facts.receivables, request.keyword);
      case McpReadQueryType.paymentStatus:
        return _queryPaymentStatus(context, facts.receivables, request.keyword);
    }
  }

  McpReadQueryResult _queryDevices(
    McpReadQueryContext context,
    Iterable<McpDeviceFact> devices,
    String? keyword,
  ) {
    if (!_permissionAllows(
          context.actor,
          OperationPermissionAction.readDevice,
        ) ||
        !_canSee(context.actor, OperationVisibilityCapability.deviceName)) {
      return _empty(context, const ['device query not allowed']);
    }
    final normalizedKeyword = _normalize(keyword);
    final items = <Map<String, Object?>>[];
    for (final device in devices) {
      if (!_canAccessDevice(context, device.deviceId)) continue;
      if (normalizedKeyword.isNotEmpty &&
          !_containsKeyword([
            device.displayName,
            device.brandOrModel,
          ], normalizedKeyword)) {
        continue;
      }
      items.add({
        'type': 'device',
        'device_label': device.displayName,
        'brand_or_model': device.brandOrModel,
        'active': device.active,
      });
    }
    return _result(context, items);
  }

  McpReadQueryResult _queryProjects(
    McpReadQueryContext context,
    Iterable<McpProjectFact> projects,
    String? keyword,
  ) {
    if (!_permissionAllows(
          context.actor,
          OperationPermissionAction.readProject,
        ) ||
        !_canSee(context.actor, OperationVisibilityCapability.projectLabel)) {
      return _empty(context, const ['project query not allowed']);
    }
    final normalizedKeyword = _normalize(keyword);
    final items = projects
        .where(
          (project) =>
              normalizedKeyword.isEmpty ||
              _containsKeyword([project.projectLabel], normalizedKeyword),
        )
        .map<Map<String, Object?>>(
          (project) => {
            'type': 'project',
            'project_label': project.projectLabel,
          },
        );
    return _result(context, items);
  }

  McpReadQueryResult _queryReceivables(
    McpReadQueryContext context,
    Iterable<McpReceivableFact> receivables,
    String? keyword,
  ) {
    if (!_canReadFinancialProjectData(context.actor)) {
      return _empty(context, const ['receivable query not allowed']);
    }
    final normalizedKeyword = _normalize(keyword);
    final items = receivables
        .where(
          (receivable) =>
              normalizedKeyword.isEmpty ||
              _containsKeyword([receivable.projectLabel], normalizedKeyword),
        )
        .map<Map<String, Object?>>(
          (receivable) => {
            'type': 'receivable',
            'project_label': receivable.projectLabel,
            'receivable_fen': receivable.receivableFen,
            'received_fen': receivable.receivedFen,
            'write_off_fen': receivable.writeOffFen,
            'remaining_fen': receivable.remainingFen,
          },
        );
    return _result(context, items);
  }

  McpReadQueryResult _queryPaymentStatus(
    McpReadQueryContext context,
    Iterable<McpReceivableFact> receivables,
    String? keyword,
  ) {
    if (!_canReadFinancialProjectData(context.actor)) {
      return _empty(context, const ['payment status query not allowed']);
    }
    final normalizedKeyword = _normalize(keyword);
    final items = receivables
        .where(
          (receivable) =>
              normalizedKeyword.isEmpty ||
              _containsKeyword([receivable.projectLabel], normalizedKeyword),
        )
        .map<Map<String, Object?>>(
          (receivable) => {
            'type': 'payment_status',
            'project_label': receivable.projectLabel,
            'payment_status': receivable.paymentStatus,
            'remaining_fen': receivable.remainingFen,
          },
        );
    return _result(context, items);
  }

  bool _canReadFinancialProjectData(ActorContext actor) {
    return _permissionAllows(actor, OperationPermissionAction.readProject) &&
        _canSee(actor, OperationVisibilityCapability.projectLabel) &&
        _canSee(actor, OperationVisibilityCapability.financialAmount) &&
        _canSee(actor, OperationVisibilityCapability.payment);
  }

  List<String> _warningsFor(McpReadQueryContext context) {
    if (context.scope.isExpired(context.now)) {
      return const ['scope expired'];
    }
    if (context.actor.isUnknown || context.actor.isSystem) {
      return const ['actor cannot use mcp read query'];
    }
    if (context.actor.isAgent && !context.actor.hasDelegatedScope) {
      return const ['agent requires delegated actor scope'];
    }
    return const [];
  }

  bool _canAccessDevice(McpReadQueryContext context, String deviceId) {
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

  McpReadQueryResult _result(
    McpReadQueryContext context,
    Iterable<Map<String, Object?>> items,
  ) {
    return McpReadQueryResult(
      items: items,
      warnings: const [],
      redacted: context.actor.effectiveActorType != OperationActorType.owner,
      scopeLimited:
          !context.scope.isFullOwner ||
          context.actor.effectiveActorType != OperationActorType.owner,
    );
  }

  McpReadQueryResult _empty(
    McpReadQueryContext context,
    Iterable<String> warnings,
  ) {
    return McpReadQueryResult(
      items: const [],
      warnings: warnings,
      redacted: context.actor.effectiveActorType != OperationActorType.owner,
      scopeLimited: true,
    );
  }
}

bool _containsKeyword(Iterable<String?> fields, String keyword) {
  return fields.any((field) => field?.toLowerCase().contains(keyword) ?? false);
}

String _normalize(String? value) => value?.trim().toLowerCase() ?? '';

void _requireNonEmpty(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
}
