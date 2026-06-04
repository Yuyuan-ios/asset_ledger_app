import 'dart:io';

import 'package:asset_ledger/infrastructure/cloud/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('NoOpCloudApiClient requires an explicit dry-run opt-in', () {
    test('enableDryRun: true constructs and keeps no-op (204) behavior', () async {
      final client = NoOpCloudApiClient(enableDryRun: true);
      expect(client.enableDryRun, isTrue);

      final response = await client.send(
        const ApiRequest(method: 'POST', path: '/sync/outbox'),
      );
      // No-op contract: always a 204 no-content response, no body, no error.
      expect(response.statusCode, 204);
      expect(response.bodyJson, isNull);
      expect(response.error, isNull);
    });

    test('enableDryRun: false fails at construction time', () {
      // In debug/test builds the initializer-list assert fires (AssertionError);
      // in release builds asserts are stripped and the runtime guard throws
      // ArgumentError. Accept either so the contract is locked in both modes.
      expect(
        () => NoOpCloudApiClient(enableDryRun: false),
        throwsA(anyOf(isA<AssertionError>(), isA<ArgumentError>())),
      );
    });
  });

  test('old EmptyCloudApiClient symbol is gone from lib/ production code', () {
    final libDir = Directory(p.join(_repoRoot, 'lib'));
    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      // The renamed class must not survive as a type/constructor/identifier
      // anywhere in production code.
      if (source.contains('EmptyCloudApiClient')) {
        offenders.add(p.relative(entity.path, from: _repoRoot));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'EmptyCloudApiClient was renamed to NoOpCloudApiClient; lib/ must not '
          'reference the old name. Offending files:\n${offenders.join('\n')}',
    );
  });
}

String get _repoRoot {
  final fromCwd = Directory.current.path;
  if (File(p.join(fromCwd, 'pubspec.yaml')).existsSync() &&
      Directory(p.join(fromCwd, 'lib')).existsSync()) {
    return fromCwd;
  }
  final scriptDir = File(Platform.script.toFilePath()).parent;
  return p.normalize(p.join(scriptDir.path, '..', '..', '..'));
}
