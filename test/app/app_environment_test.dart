import 'package:asset_ledger/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(RuntimeGate.resetForTest);

  test('parses build environments', () {
    expect(BuildEnvironment.parse('production'), BuildEnvironment.production);
    expect(BuildEnvironment.parse('staging'), BuildEnvironment.staging);
    expect(BuildEnvironment.parse('local'), BuildEnvironment.local);
  });

  test('unknown build environment fails closed to production', () {
    expect(BuildEnvironment.parse(''), BuildEnvironment.production);
    expect(BuildEnvironment.parse('review'), BuildEnvironment.production);
    expect(
      BuildEnvironment.parse('unsupported_mode'),
      BuildEnvironment.production,
    );
  });

  test('current build environment initializes runtime access default', () {
    RuntimeGate.resetForTest();
    final expectedAccess = switch (BuildEnvironment.current) {
      BuildEnvironment.production => RuntimeAccessMode.normal,
      BuildEnvironment.staging => RuntimeAccessMode.sandbox,
      BuildEnvironment.local => RuntimeAccessMode.demo,
    };

    expect(RuntimeGate.buildEnvironment, BuildEnvironment.current);
    expect(RuntimeGate.accessMode, expectedAccess);
  });

  test('parses runtime access modes', () {
    expect(RuntimeAccessMode.parse('normal'), RuntimeAccessMode.normal);
    expect(RuntimeAccessMode.parse('sandbox'), RuntimeAccessMode.sandbox);
    expect(RuntimeAccessMode.parse('demo'), RuntimeAccessMode.demo);
    expect(RuntimeAccessMode.parse('review'), RuntimeAccessMode.normal);
  });

  test('default access mode follows build environment', () {
    expect(
      const RuntimeAccessResolver(
        buildEnvironment: BuildEnvironment.production,
      ).defaultAccessMode,
      RuntimeAccessMode.normal,
    );
    expect(
      const RuntimeAccessResolver(
        buildEnvironment: BuildEnvironment.staging,
      ).defaultAccessMode,
      RuntimeAccessMode.sandbox,
    );
    expect(
      const RuntimeAccessResolver(
        buildEnvironment: BuildEnvironment.local,
      ).defaultAccessMode,
      RuntimeAccessMode.demo,
    );
  });

  test('configured access mode overrides build default', () {
    expect(
      const RuntimeAccessResolver(
        buildEnvironment: BuildEnvironment.production,
        configuredDefaultAccessMode: RuntimeAccessMode.demo,
      ).defaultAccessMode,
      RuntimeAccessMode.demo,
    );
  });

  test('review access policy allows only authenticated whitelisted users', () {
    const policy = ReviewAccessPolicy(
      enabled: true,
      emails: {'review@example.com'},
      userIds: {'review-user-id'},
    );

    expect(
      policy.isAllowedAuthenticatedUser(
        identifier: 'review@example.com',
        email: null,
        userId: null,
      ),
      isTrue,
    );
    expect(
      policy.isAllowedAuthenticatedUser(
        identifier: null,
        email: 'review@example.com',
        userId: null,
      ),
      isTrue,
    );
    expect(
      policy.isAllowedAuthenticatedUser(
        identifier: null,
        email: null,
        userId: 'review-user-id',
      ),
      isTrue,
    );
    expect(
      policy.isAllowedAuthenticatedUser(
        identifier: 'user@example.com',
        email: 'user@example.com',
        userId: 'normal-user-id',
      ),
      isFalse,
    );
    expect(
      const ReviewAccessPolicy(
        enabled: false,
        emails: {'review@example.com'},
      ).isAllowedAuthenticatedUser(
        identifier: 'review@example.com',
        email: null,
        userId: null,
      ),
      isFalse,
    );
  });

  test('review account resolves production normal to sandbox access', () {
    const resolver = RuntimeAccessResolver(
      buildEnvironment: BuildEnvironment.production,
      reviewAccessPolicy: ReviewAccessPolicy(
        enabled: true,
        emails: {'review@example.com'},
      ),
    );

    expect(
      resolver.resolve(
        accountIdentifier: 'review@example.com',
        isAuthenticated: false,
      ),
      RuntimeAccessMode.normal,
    );
    expect(
      resolver.resolve(
        accountIdentifier: 'user@example.com',
        isAuthenticated: true,
      ),
      RuntimeAccessMode.normal,
    );
    expect(
      resolver.resolve(
        accountIdentifier: 'review@example.com',
        isAuthenticated: true,
      ),
      RuntimeAccessMode.sandbox,
    );
  });

  test('runtime gate exposes capability gates', () {
    RuntimeGate.setAccessModeForTest(RuntimeAccessMode.normal);
    expect(RuntimeGate.isNormalAccess, isTrue);
    expect(RuntimeGate.shouldBypassAuth, isFalse);
    expect(RuntimeGate.shouldBypassIap, isFalse);
    expect(RuntimeGate.shouldForceMaxEntitlement, isFalse);
    expect(RuntimeGate.shouldUseMockSync, isFalse);
    expect(RuntimeGate.shouldDisableBackupNetwork, isFalse);
    expect(RuntimeGate.shouldDisableAppUpdateNetwork, isFalse);
    expect(RuntimeGate.shouldSeedDemoData, isFalse);

    RuntimeGate.setAccessModeForTest(RuntimeAccessMode.sandbox);
    expect(RuntimeGate.isSandboxAccess, isTrue);
    expect(RuntimeGate.shouldBypassAuth, isTrue);
    expect(RuntimeGate.shouldBypassIap, isTrue);
    expect(RuntimeGate.shouldForceMaxEntitlement, isTrue);
    expect(RuntimeGate.shouldUseMockSync, isTrue);
    expect(RuntimeGate.shouldUseMockCloud, isTrue);
    expect(RuntimeGate.shouldDisableBackupNetwork, isTrue);
    expect(RuntimeGate.shouldDisableAppUpdateNetwork, isTrue);
    expect(RuntimeGate.shouldSeedDemoData, isTrue);

    RuntimeGate.setAccessModeForTest(RuntimeAccessMode.demo);
    expect(RuntimeGate.isDemoAccess, isTrue);
    expect(RuntimeGate.shouldBypassAuth, isTrue);
    expect(RuntimeGate.shouldUseMockSync, isFalse);
    expect(RuntimeGate.shouldDisableBackupNetwork, isTrue);
    expect(RuntimeGate.shouldDisableAppUpdateNetwork, isTrue);
    expect(RuntimeGate.shouldSeedDemoData, isTrue);
  });
}
