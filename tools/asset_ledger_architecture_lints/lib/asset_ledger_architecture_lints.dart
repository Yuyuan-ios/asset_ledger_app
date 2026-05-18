// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

PluginBase createPlugin() => _AssetLedgerArchitectureLints();

class _AssetLedgerArchitectureLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
    _NoUiImportsFromDataOrState(),
    _NoStoreReadsInReusableUi(),
    _NoFontFamilyInUiLayers(),
    _NoTextStyleInMigratedModules(),
    _NoProjectKeyInCoreIdentityPath(),
    _NoFeatureModelDataImplementationImports(),
    _NoDataLayerImportsFromFeatures(),
    _NoCoreLayerImportsFromUpperLayers(),
    _NoEnumValuesByName(),
  ];
}

class _NoUiImportsFromDataOrState extends DartLintRule {
  const _NoUiImportsFromDataOrState() : super(code: _code);

  static const _code = LintCode(
    name: 'no_ui_imports_from_data_or_state',
    problemMessage:
        'Data and state layers must not import components, patterns, or feature view files.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!_isDataOrStateFile(path)) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null || !_isForbiddenUiImport(uri)) return;
      reporter.atNode(node.uri, code);
    });
  }
}

class _NoStoreReadsInReusableUi extends DartLintRule {
  const _NoStoreReadsInReusableUi() : super(code: _code);

  static const _code = LintCode(
    name: 'no_store_reads_in_reusable_ui',
    problemMessage:
        'components/ and patterns/ must not call context.watch/read directly.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!_isReusableUiFile(path)) return;

    context.registry.addMethodInvocation((node) {
      final target = node.target?.toSource().trim();
      final methodName = node.methodName.name;
      if (target != 'context') return;
      if (methodName != 'watch' && methodName != 'read') return;
      reporter.atNode(node.methodName, code);
    });
  }
}

class _NoFontFamilyInUiLayers extends DartLintRule {
  const _NoFontFamilyInUiLayers() : super(code: _code);

  static const _code = LintCode(
    name: 'no_font_family_in_ui_layers',
    problemMessage:
        'Do not set fontFamily directly in UI layers; use Theme textTheme/AppTypography instead.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!_isFeatureOrReusableUiFile(path)) return;

    context.registry.addNamedExpression((node) {
      if (node.name.label.name != 'fontFamily') return;
      reporter.atNode(node.name, code);
    });
  }
}

class _NoTextStyleInMigratedModules extends DartLintRule {
  const _NoTextStyleInMigratedModules() : super(code: _code);

  static const _code = LintCode(
    name: 'no_textstyle_in_migrated_modules',
    problemMessage:
        'Migrated modules must use AppTypography/textTheme instead of direct TextStyle constructors.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!_isMigratedTypographyModule(path) ||
        _isTypographyTextStyleAllowed(path)) {
      return;
    }

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'TextStyle') return;
      reporter.atNode(node.constructorName, code);
    });
  }
}

class _NoProjectKeyInCoreIdentityPath extends DartLintRule {
  const _NoProjectKeyInCoreIdentityPath() : super(code: _code);

  static const _code = LintCode(
    name: 'no_project_key_in_core_identity_path',
    problemMessage:
        'Core project identity paths must resolve project_id through ProjectResolver, not legacy ProjectKey/ProjectId helpers.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!_isCoreProjectIdentityPath(path)) return;

    context.registry.addMethodInvocation((node) {
      final target = node.target?.toSource().trim();
      final methodName = node.methodName.name;
      final isLegacyProjectId =
          target == 'ProjectId' && methodName.startsWith('legacy');
      final isProjectKeyIdentity =
          target == 'ProjectKey' &&
          (methodName == 'buildKey' || methodName == 'fromKey');
      if (!isLegacyProjectId && !isProjectKeyIdentity) return;
      reporter.atNode(node.methodName, code);
    });
  }
}

class _NoFeatureModelDataImplementationImports extends DartLintRule {
  const _NoFeatureModelDataImplementationImports() : super(code: _code);

  static const _code = LintCode(
    name: 'no_feature_model_data_implementation_imports',
    problemMessage:
        'Feature model files must not import data db/repository/service implementation layers.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!RegExp(r'/lib/features/[^/]+/model/').hasMatch(path)) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;
      if (!_isDataImplementationImport(uri)) return;
      reporter.atNode(node.uri, code);
    });
  }
}

class _NoDataLayerImportsFromFeatures extends DartLintRule {
  const _NoDataLayerImportsFromFeatures() : super(code: _code);

  static const _code = LintCode(
    name: 'no_data_layer_imports_from_features',
    problemMessage:
        'Data layer files must not import the features layer; persistence '
        'concerns belong in data/, not under features/.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!path.contains('/lib/data/')) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null || !_isFeaturesImport(uri)) return;
      reporter.atNode(node.uri, code);
    });
  }
}

class _NoCoreLayerImportsFromUpperLayers extends DartLintRule {
  const _NoCoreLayerImportsFromUpperLayers() : super(code: _code);

  static const _code = LintCode(
    name: 'no_core_layer_imports_from_upper_layers',
    problemMessage:
        'Core layer files must not import data, app or features; core must '
        'stay dependency-free of upper layers.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = _normalizePath(resolver.path);
    if (!path.contains('/lib/core/')) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null || !_isUpperLayerImport(uri)) return;
      reporter.atNode(node.uri, code);
    });
  }
}

class _NoEnumValuesByName extends DartLintRule {
  const _NoEnumValuesByName() : super(code: _code);

  static const _code = LintCode(
    name: 'no_enum_values_by_name',
    problemMessage:
        'Do not parse external enum input with enum.values.byName; use an explicit safe parser.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'byName') return;
      final target = node.target?.toSource().trim() ?? '';
      if (!target.endsWith('.values')) return;
      reporter.atNode(node.methodName, code);
    });
  }
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

bool _isDataOrStateFile(String path) {
  if (path.contains('/lib/data/')) return true;
  return RegExp(r'/lib/features/[^/]+/state/').hasMatch(path);
}

bool _isReusableUiFile(String path) {
  return path.contains('/lib/components/') || path.contains('/lib/patterns/');
}

bool _isFeatureOrReusableUiFile(String path) {
  return path.contains('/lib/features/') ||
      path.contains('/lib/components/') ||
      path.contains('/lib/patterns/');
}

bool _isMigratedTypographyModule(String path) {
  return RegExp(
        r'/lib/features/(account|fuel|maintenance|timing)/',
      ).hasMatch(path) ||
      RegExp(
        r'/lib/patterns/(account|fuel|maintenance|timing)/',
      ).hasMatch(path) ||
      RegExp(
        r'/lib/components/(feedback|buttons|fields|list|avatars|pickers)/',
      ).hasMatch(path);
}

bool _isTypographyTextStyleAllowed(String path) {
  // CustomPainter text rendering in this file does not have BuildContext.
  return path.contains(
    '/lib/patterns/account/account_overview_card_pattern.dart',
  );
}

bool _isCoreProjectIdentityPath(String path) {
  return path.contains('/lib/features/timing/use_cases/') ||
      path.contains('/lib/data/repositories/timing_repository.dart');
}

bool _isDataImplementationImport(String uri) {
  final normalized = uri.replaceAll('\\', '/');
  if (normalized.startsWith('package:')) {
    if (!normalized.startsWith('package:asset_ledger/')) return false;
    return _isDataImplementationPath(
      normalized.substring('package:asset_ledger/'.length),
    );
  }
  return _isDataImplementationPath(normalized);
}

bool _isDataImplementationPath(String path) {
  return path.contains('data/db/') ||
      path.contains('data/repositories/') ||
      path.contains('data/services/');
}

bool _isForbiddenUiImport(String uri) {
  final normalized = uri.replaceAll('\\', '/');

  if (normalized.startsWith('package:')) {
    if (!normalized.startsWith('package:asset_ledger/')) return false;
    final packagePath = normalized.substring('package:asset_ledger/'.length);
    return _isUiLayerPath(packagePath);
  }

  return _isUiLayerPath(normalized);
}

bool _isUiLayerPath(String path) {
  return path.contains('components/') ||
      path.contains('patterns/') ||
      RegExp(r'(^|/)features/[^/]+/view/').hasMatch(path);
}

bool _isFeaturesImport(String uri) {
  final normalized = uri.replaceAll('\\', '/');
  if (normalized.startsWith('package:')) {
    if (!normalized.startsWith('package:asset_ledger/')) return false;
    return normalized
        .substring('package:asset_ledger/'.length)
        .startsWith('features/');
  }
  return normalized.contains('features/');
}

bool _isUpperLayerImport(String uri) {
  final normalized = uri.replaceAll('\\', '/');
  bool hitsUpper(String path) =>
      path.startsWith('data/') ||
      path.startsWith('app/') ||
      path.startsWith('features/') ||
      path.contains('/data/') ||
      path.contains('/app/') ||
      path.contains('/features/');
  if (normalized.startsWith('package:')) {
    if (!normalized.startsWith('package:asset_ledger/')) return false;
    return hitsUpper(normalized.substring('package:asset_ledger/'.length));
  }
  return hitsUpper(normalized);
}
