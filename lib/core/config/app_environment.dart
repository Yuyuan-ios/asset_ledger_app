enum BuildEnvironment {
  production,
  staging,
  local;

  static const String defineKey = 'FLEET_LEDGER_BUILD_ENV';
  static const String _currentValue = String.fromEnvironment(
    defineKey,
    defaultValue: 'production',
  );

  static BuildEnvironment get current => parse(_currentValue);

  static BuildEnvironment parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'production' => BuildEnvironment.production,
      'staging' => BuildEnvironment.staging,
      'local' => BuildEnvironment.local,
      _ => BuildEnvironment.production,
    };
  }
}

enum RuntimeAccessMode {
  normal,
  sandbox,
  demo;

  static const String defineKey = 'FLEET_LEDGER_ACCESS_MODE';
  static const String _configuredValue = String.fromEnvironment(defineKey);

  static RuntimeAccessMode? get configuredDefault =>
      parseOrNull(_configuredValue);

  static RuntimeAccessMode? parseOrNull(String value) {
    return switch (value.trim().toLowerCase()) {
      'normal' => RuntimeAccessMode.normal,
      'sandbox' => RuntimeAccessMode.sandbox,
      'demo' => RuntimeAccessMode.demo,
      '' => null,
      _ => null,
    };
  }

  static RuntimeAccessMode parse(String value) {
    return parseOrNull(value) ?? RuntimeAccessMode.normal;
  }
}

class ReviewAccessPolicy {
  const ReviewAccessPolicy({
    required this.enabled,
    this.identifiers = const <String>{},
    this.emails = const <String>{},
    this.userIds = const <String>{},
  });

  static const String enabledKey = 'REVIEW_ACCESS_MODE_ENABLED';
  static const String identifiersKey = 'REVIEW_ACCESS_IDENTIFIERS';
  static const String emailsKey = 'REVIEW_ACCESS_EMAILS';
  static const String phoneNumbersKey = 'REVIEW_ACCESS_PHONE_NUMBERS';
  static const String userIdsKey = 'REVIEW_ACCESS_USER_IDS';

  static const bool _enabledFromEnvironment = bool.fromEnvironment(enabledKey);
  static const String _identifiersFromEnvironment = String.fromEnvironment(
    identifiersKey,
  );
  static const String _emailsFromEnvironment = String.fromEnvironment(
    emailsKey,
  );
  static const String _phoneNumbersFromEnvironment = String.fromEnvironment(
    phoneNumbersKey,
  );
  static const String _userIdsFromEnvironment = String.fromEnvironment(
    userIdsKey,
  );

  static ReviewAccessPolicy get fromEnvironment {
    return ReviewAccessPolicy(
      enabled: _enabledFromEnvironment,
      identifiers: _parseIdentifiers(
        _identifiersFromEnvironment,
        _phoneNumbersFromEnvironment,
      ),
      emails: _parseIdentifiers(_emailsFromEnvironment),
      userIds: _parseUserIds(_userIdsFromEnvironment),
    );
  }

  final bool enabled;
  final Set<String> identifiers;
  final Set<String> emails;
  final Set<String> userIds;

  bool isReviewIdentifier(String? value) {
    if (!enabled) return false;
    final normalized = _normalizeIdentifier(value);
    return normalized.isNotEmpty &&
        (identifiers.contains(normalized) || emails.contains(normalized));
  }

  bool isAllowedAuthenticatedUser({
    required String? identifier,
    required String? email,
    required String? userId,
  }) {
    if (!enabled) return false;
    return isReviewIdentifier(identifier) ||
        _isAllowedEmail(email) ||
        _isAllowedUserId(userId);
  }

  bool _isAllowedEmail(String? value) {
    final normalized = _normalizeIdentifier(value);
    return normalized.isNotEmpty && emails.contains(normalized);
  }

  bool _isAllowedUserId(String? value) {
    final normalized = _normalizeUserId(value);
    return normalized.isNotEmpty && userIds.contains(normalized);
  }

  static Set<String> _parseIdentifiers(String primary, [String extra = '']) {
    return <String>{}
      ..addAll(_splitIdentifiers(primary))
      ..addAll(_splitIdentifiers(extra));
  }

  static Iterable<String> _splitIdentifiers(String value) {
    return value
        .split(RegExp(r'[,;\s]+'))
        .map(_normalizeIdentifier)
        .where((identifier) => identifier.isNotEmpty);
  }

  static String normalizeIdentifier(String? value) =>
      _normalizeIdentifier(value);

  static String _normalizeIdentifier(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('@')) return trimmed;
    return trimmed.replaceAll(RegExp(r'[\s()\-]'), '');
  }

  static Set<String> _parseUserIds(String value) {
    return value
        .split(RegExp(r'[,;\s]+'))
        .map(_normalizeUserId)
        .where((userId) => userId.isNotEmpty)
        .toSet();
  }

  static String _normalizeUserId(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }
}

class RuntimeAccessResolver {
  const RuntimeAccessResolver({
    required this.buildEnvironment,
    this.configuredDefaultAccessMode,
    this.reviewAccessPolicy = const ReviewAccessPolicy(enabled: false),
  });

  factory RuntimeAccessResolver.fromEnvironment() {
    return RuntimeAccessResolver(
      buildEnvironment: BuildEnvironment.current,
      configuredDefaultAccessMode: RuntimeAccessMode.configuredDefault,
      reviewAccessPolicy: ReviewAccessPolicy.fromEnvironment,
    );
  }

  final BuildEnvironment buildEnvironment;
  final RuntimeAccessMode? configuredDefaultAccessMode;
  final ReviewAccessPolicy reviewAccessPolicy;

  RuntimeAccessMode get defaultAccessMode {
    final configured = configuredDefaultAccessMode;
    if (configured != null) return configured;
    return switch (buildEnvironment) {
      BuildEnvironment.production => RuntimeAccessMode.normal,
      BuildEnvironment.staging => RuntimeAccessMode.sandbox,
      BuildEnvironment.local => RuntimeAccessMode.demo,
    };
  }

  RuntimeAccessMode resolve({
    String? accountIdentifier,
    String? email,
    String? userId,
    bool isAuthenticated = false,
  }) {
    if (isAuthenticated &&
        reviewAccessPolicy.isAllowedAuthenticatedUser(
          identifier: accountIdentifier,
          email: email,
          userId: userId,
        )) {
      return RuntimeAccessMode.sandbox;
    }
    return defaultAccessMode;
  }
}

class RuntimeGate {
  const RuntimeGate._();

  static RuntimeAccessMode _accessMode =
      RuntimeAccessResolver.fromEnvironment().defaultAccessMode;

  static BuildEnvironment get buildEnvironment => BuildEnvironment.current;

  static RuntimeAccessMode get accessMode => _accessMode;

  static ReviewAccessPolicy get reviewAccessPolicy =>
      ReviewAccessPolicy.fromEnvironment;

  static void resolveAccessForAccount({
    String? accountIdentifier,
    String? email,
    String? userId,
    bool isAuthenticated = false,
    ReviewAccessPolicy? reviewAccessPolicy,
  }) {
    final baseResolver = RuntimeAccessResolver.fromEnvironment();
    final resolver = RuntimeAccessResolver(
      buildEnvironment: baseResolver.buildEnvironment,
      configuredDefaultAccessMode: baseResolver.configuredDefaultAccessMode,
      reviewAccessPolicy: reviewAccessPolicy ?? baseResolver.reviewAccessPolicy,
    );
    _accessMode = resolver.resolve(
      accountIdentifier: accountIdentifier,
      email: email,
      userId: userId,
      isAuthenticated: isAuthenticated,
    );
  }

  static void setAccessModeForTest(RuntimeAccessMode mode) {
    _accessMode = mode;
  }

  static void resetForTest() {
    _accessMode = RuntimeAccessResolver.fromEnvironment().defaultAccessMode;
  }

  static bool get isProductionBuild =>
      buildEnvironment == BuildEnvironment.production;

  static bool get isStagingBuild =>
      buildEnvironment == BuildEnvironment.staging;

  static bool get isLocalBuild => buildEnvironment == BuildEnvironment.local;

  static bool get isNormalAccess => accessMode == RuntimeAccessMode.normal;

  static bool get isSandboxAccess => accessMode == RuntimeAccessMode.sandbox;

  static bool get isDemoAccess => accessMode == RuntimeAccessMode.demo;

  static bool get shouldBypassAuth => isSandboxAccess || isDemoAccess;

  static bool get shouldBypassIap => isSandboxAccess || isDemoAccess;

  static bool get shouldForceMaxEntitlement => shouldBypassIap;

  static bool get shouldUseMockSync => isSandboxAccess;

  static bool get shouldUseMockCloud => isSandboxAccess;

  static bool get shouldDisableBackupNetwork => isSandboxAccess || isDemoAccess;

  static bool get shouldDisableAppUpdateNetwork =>
      isSandboxAccess || isDemoAccess;

  static bool get shouldSeedDemoData => isSandboxAccess || isDemoAccess;
}
