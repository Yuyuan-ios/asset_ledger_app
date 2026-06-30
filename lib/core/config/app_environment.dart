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
    this.password = '',
  });

  static const String enabledKey = 'REVIEW_ACCESS_MODE_ENABLED';
  static const String identifiersKey = 'REVIEW_ACCESS_IDENTIFIERS';
  static const String emailsKey = 'REVIEW_ACCESS_EMAILS';
  static const String phoneNumbersKey = 'REVIEW_ACCESS_PHONE_NUMBERS';
  static const String passwordKey = 'REVIEW_ACCESS_PASSWORD';

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
  static const String _passwordFromEnvironment = String.fromEnvironment(
    passwordKey,
  );

  static ReviewAccessPolicy get fromEnvironment {
    return ReviewAccessPolicy(
      enabled: _enabledFromEnvironment,
      identifiers: _parseIdentifiers(
        _identifiersFromEnvironment,
        _emailsFromEnvironment,
        _phoneNumbersFromEnvironment,
      ),
      password: _passwordFromEnvironment,
    );
  }

  final bool enabled;
  final Set<String> identifiers;
  final String password;

  bool get hasConfiguredCredential =>
      enabled && identifiers.isNotEmpty && password.isNotEmpty;

  bool isReviewIdentifier(String? value) {
    if (!enabled) return false;
    final normalized = _normalizeIdentifier(value);
    return normalized.isNotEmpty && identifiers.contains(normalized);
  }

  bool matchesCredentials({
    required String identifier,
    required String secret,
  }) {
    if (!hasConfiguredCredential) return false;
    return isReviewIdentifier(identifier) && secret == password;
  }

  static Set<String> _parseIdentifiers(
    String primary,
    String emails,
    String phones,
  ) {
    return <String>{}
      ..addAll(_splitIdentifiers(primary))
      ..addAll(_splitIdentifiers(emails))
      ..addAll(_splitIdentifiers(phones));
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
    bool isAuthenticated = false,
  }) {
    if (isAuthenticated &&
        reviewAccessPolicy.isReviewIdentifier(accountIdentifier)) {
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
