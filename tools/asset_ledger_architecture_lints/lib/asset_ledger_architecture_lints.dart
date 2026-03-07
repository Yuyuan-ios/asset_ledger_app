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
