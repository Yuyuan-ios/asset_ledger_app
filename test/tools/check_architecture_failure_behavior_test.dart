@Tags(['arch-script'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Architecture script failure behavior: verifies that
/// tools/check_architecture.sh fails (non-zero exit) when:
///   1) the current repo state passes (sanity baseline), AND
///   2) a temporary violation is introduced, the script catches it AND exits
///      with a non-zero code, AND
///   3) once the violation is removed the script returns to passing.
///
/// This locks in the fix for the "false negative" where the script printed
/// violations but still exited 0.
void main() {
  // 这是会真正调用 bash 运行架构脚本的端到端测试；只在本地 / CI 的 POSIX 环境上跑。
  // 不要并行运行，避免对临时探针文件的写入彼此干扰。
  test('clean repo: arch script exits 0', () async {
    final result = await _runArchScript();
    expect(
      result.exitCode,
      0,
      reason:
          'baseline check_architecture.sh should pass on clean repo. '
          'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
  }, tags: ['arch-script']);

  test(
    'introducing a direct TextStyle violation makes arch script exit non-zero',
    () async {
      final probePath = p.join(
        _repoRoot,
        'lib/patterns/device/__arch_probe_textstyle.dart',
      );
      final probe = File(probePath);
      try {
        await probe.writeAsString(
          "// Temporary probe file for check_architecture.sh test.\n"
          "import 'package:flutter/material.dart';\n"
          "TextStyle archProbeStyle() => TextStyle(fontSize: 12);\n",
        );

        final result = await _runArchScript();
        expect(
          result.exitCode,
          isNot(0),
          reason:
              'arch script must fail when a direct TextStyle violation exists. '
              'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(
          result.stdout + result.stderr,
          contains('__arch_probe_textstyle.dart'),
          reason: 'failure output must point at the offending file.',
        );
      } finally {
        if (await probe.exists()) {
          await probe.delete();
        }
      }

      // After cleanup, baseline still passes.
      final after = await _runArchScript();
      expect(
        after.exitCode,
        0,
        reason:
            'after removing probe, arch script must pass again. '
            'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
      );
    },
    tags: ['arch-script'],
  );

  // ==========================================================================
  // 阶段 C Step 3：守住 timing pattern 边界 + patterns 全局基础设施依赖禁用。
  //
  // 每个探针写一份只触发"目标规则"的临时 .dart 文件，验证：
  //   1) 脚本 exit 非 0；
  //   2) 输出中包含探针文件名（错误信息有指向性）；
  //   3) 删除探针后 baseline 再次为 0。
  //
  // 探针文件内容只服务于 grep 检查，不要求 Dart 可编译；它们只在测试方法
  // 生命周期内存在，flutter analyze 不会扫到。
  // ==========================================================================

  _archProbeTest(
    name:
        'patterns_timing_no_data_services: '
        'data/services import in lib/patterns/timing fails',
    relativeProbePath:
        'lib/patterns/timing/__arch_probe_data_services_import.dart',
    probeContent:
        "// Probe: patterns_timing_no_data_services\n"
        "import 'package:asset_ledger/data/services/timing_service.dart';\n"
        "// referenced to silence unused-import in static analyzers if scanned:\n"
        "void _archProbeUse() { TimingService; }\n",
  );

  _archProbeTest(
    name:
        'patterns_timing_no_timing_service: '
        'direct TimingService call in lib/patterns/timing fails',
    relativeProbePath:
        'lib/patterns/timing/__arch_probe_timing_service_call.dart',
    probeContent:
        "// Probe: patterns_timing_no_timing_service\n"
        "// (does not import data/services to avoid triggering the import rule)\n"
        "class _TimingServiceStub { static int currentMeter() => 0; }\n"
        "int archProbe() => TimingService.currentMeter();\n",
  );

  _archProbeTest(
    name:
        'patterns_timing_no_device_label: '
        'direct DeviceLabel call in lib/patterns/timing fails',
    relativeProbePath:
        'lib/patterns/timing/__arch_probe_device_label_call.dart',
    probeContent:
        "// Probe: patterns_timing_no_device_label\n"
        "String archProbe() => DeviceLabel.indexOnly('x');\n",
  );

  _archProbeTest(
    name:
        'patterns_timing_no_provider_context: '
        'Provider.of usage in lib/patterns/timing fails',
    relativeProbePath: 'lib/patterns/timing/__arch_probe_provider_of.dart',
    probeContent:
        "// Probe: patterns_timing_no_provider_context\n"
        "import 'package:flutter/widgets.dart';\n"
        "Object? archProbe(BuildContext c) => Provider.of<int>(c);\n",
  );

  // 阶段 C Step 4：service 边界规则扩大到 lib/patterns/device，下面两个探针
  // 验证 device pattern 同样会被守住。
  _archProbeTest(
    name:
        'patterns_ui_no_data_services: '
        'data/services import in lib/patterns/device fails',
    relativeProbePath:
        'lib/patterns/device/__arch_probe_data_services_import.dart',
    probeContent:
        "// Probe: patterns_ui_no_data_services (device scope)\n"
        "import 'package:asset_ledger/data/services/timing_service.dart';\n"
        "void _archProbeUse() { TimingService; }\n",
  );

  _archProbeTest(
    name:
        'patterns_ui_no_device_label: '
        'direct DeviceLabel call in lib/patterns/device fails',
    relativeProbePath:
        'lib/patterns/device/__arch_probe_device_label_call.dart',
    probeContent:
        "// Probe: patterns_ui_no_device_label (device scope)\n"
        "String archProbe() => DeviceLabel.indexOnly('x');\n",
  );

  _archProbeTest(
    name:
        'patterns_no_infrastructure_imports: '
        'infrastructure import anywhere under lib/patterns fails',
    relativeProbePath:
        'lib/patterns/account/__arch_probe_infrastructure_import.dart',
    probeContent:
        "// Probe: patterns_no_infrastructure_imports\n"
        "import 'package:asset_ledger/infrastructure/local/account/"
        "project_settlement_impact_service.dart';\n"
        "void archProbe() { ProjectSettlementImpactService; }\n",
  );

  _archProbeTest(
    name:
        'patterns_no_repository_imports: '
        'repository import anywhere under lib/patterns fails',
    relativeProbePath:
        'lib/patterns/account/__arch_probe_repository_import.dart',
    probeContent:
        "// Probe: patterns_no_repository_imports\n"
        "import 'package:asset_ledger/data/repositories/"
        "account_payment_repository.dart';\n"
        "void archProbe() { AccountPaymentRepository; }\n",
  );

  _archProbeTest(
    name:
        'patterns_no_db_imports: '
        'db import anywhere under lib/patterns fails',
    relativeProbePath: 'lib/patterns/account/__arch_probe_db_import.dart',
    probeContent:
        "// Probe: patterns_no_db_imports\n"
        "import 'package:asset_ledger/data/db/database.dart';\n"
        "void archProbe() { AppDatabase; }\n",
  );

  _archProbeTest(
    name:
        'patterns_no_use_case_imports: '
        'use_cases import anywhere under lib/patterns fails',
    relativeProbePath: 'lib/patterns/account/__arch_probe_use_case_import.dart',
    probeContent:
        "// Probe: patterns_no_use_case_imports\n"
        "import 'package:asset_ledger/features/timing/use_cases/"
        "save_timing_record_use_case.dart';\n"
        "void archProbe() { SaveTimingRecordUseCase; }\n",
  );

  // R5.24: composition_no_default_const_sync_enqueuer — a bare/no-arg
  // *SyncEnqueuer() construction in the composition root must fail the script.
  _archProbeTest(
    name:
        'composition_no_default_const_sync_enqueuer: '
        'const no-arg SyncEnqueuer construction in lib/app fails',
    relativeProbePath:
        'lib/app/providers/__arch_probe_default_const_enqueuer.dart',
    probeContent:
        "// Probe: composition_no_default_const_sync_enqueuer\n"
        "Object archProbe() => const AccountPaymentSyncEnqueuer();\n",
  );

  _archProbeTest(
    name:
        'composition_no_default_const_sync_enqueuer: '
        'bare no-arg SyncEnqueuer construction in lib/app fails',
    relativeProbePath: 'lib/app/providers/__arch_probe_bare_enqueuer.dart',
    probeContent:
        "// Probe: composition_no_default_const_sync_enqueuer (bare)\n"
        "Object archProbe() => ExternalWorkSyncEnqueuer();\n",
  );

  _archProbeTest(
    name:
        'no_default_sync_enqueuer_construction: '
        'method body no-arg SyncEnqueuer construction in lib/data fails',
    relativeProbePath:
        'lib/data/repositories/__arch_probe_sync_enqueuer_method_body.dart',
    probeContent:
        "// Probe: no_default_sync_enqueuer_construction method body\n"
        "Object archProbe() {\n"
        "  return const AccountPaymentSyncEnqueuer();\n"
        "}\n",
  );

  _archProbeTest(
    name:
        'no_default_sync_enqueuer_construction: '
        'getter and provider body no-arg SyncEnqueuer construction fails',
    relativeProbePath:
        'lib/infrastructure/local/account/'
        '__arch_probe_sync_enqueuer_getter_provider.dart',
    probeContent:
        "// Probe: no_default_sync_enqueuer_construction getter/provider body\n"
        "Object get archProbeGetter => ProjectWriteOffSyncEnqueuer();\n"
        "Object archProbeProvider() => const ProjectSyncEnqueuer();\n",
  );

  // Lock the harder-to-grep construction shapes the rule must still catch:
  // multi-line empty parens, spaced empty parens, and a field initializer that
  // bypasses DI. These are verified working today; the probes guard against a
  // future regex simplification quietly dropping them.
  _archProbeTest(
    name:
        'no_default_sync_enqueuer_construction: '
        'multi-line empty-parens SyncEnqueuer construction fails',
    relativeProbePath:
        'lib/data/repositories/__arch_probe_sync_enqueuer_multiline.dart',
    probeContent:
        "// Probe: no_default_sync_enqueuer_construction multi-line empty parens\n"
        "Object archProbe() {\n"
        "  return AccountPaymentSyncEnqueuer(\n"
        "  );\n"
        "}\n",
  );

  _archProbeTest(
    name:
        'no_default_sync_enqueuer_construction: '
        'spaced empty-parens SyncEnqueuer construction fails',
    relativeProbePath:
        'lib/data/repositories/__arch_probe_sync_enqueuer_spaced.dart',
    probeContent:
        "// Probe: no_default_sync_enqueuer_construction spaced empty parens\n"
        "Object archProbe() => AccountPaymentSyncEnqueuer ( ) ;\n",
  );

  _archProbeTest(
    name:
        'no_default_sync_enqueuer_construction: '
        'field-initializer no-arg SyncEnqueuer construction fails',
    relativeProbePath:
        'lib/infrastructure/local/account/'
        '__arch_probe_sync_enqueuer_field_initializer.dart',
    probeContent:
        "// Probe: no_default_sync_enqueuer_construction field initializer\n"
        "class _ArchProbeHolder {\n"
        "  final Object enqueuer = const AccountPaymentSyncEnqueuer();\n"
        "}\n",
  );

  // Non-regression: enqueuer construction WITH explicit dependencies, a doc
  // comment mentioning an enqueuer, and a plain type annotation must NOT be
  // flagged in the composition root.
  test('arch script does not flag explicit-dependency enqueuer construction or '
      'type references in lib/app', () async {
    final probePath = p.join(
      _repoRoot,
      'lib/app/providers/__arch_probe_enqueuer_false_positive.dart',
    );
    final probe = File(probePath);
    try {
      await probe.writeAsString(
        "// Probe: composition enqueuer false-positive guard.\n"
        "// const AccountPaymentSyncEnqueuer() mentioned in a comment only.\n"
        "/// Doc reference to ProjectSyncEnqueuer should not match.\n"
        "class _Holder {\n"
        "  // Explicit-dependency construction is the sanctioned form and\n"
        "  // must not be flagged (non-empty parens).\n"
        "  final Object e = AccountPaymentSyncEnqueuer(\n"
        "    syncOutboxRepository: _fakeRepo,\n"
        "  );\n"
        "  final Object? typeOnly = null; // ExternalWorkSyncEnqueuer ref in comment\n"
        "}\n"
        "Object? _fakeRepo;\n",
      );
      final result = await _runArchScript();
      expect(
        result.exitCode,
        0,
        reason:
            'explicit-dependency enqueuer construction and comment/type '
            'references must not trip the rule. '
            'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
    final after = await _runArchScript();
    expect(
      after.exitCode,
      0,
      reason:
          'baseline must pass after removing the false-positive probe. '
          'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
    );
  }, tags: ['arch-script']);

  test(
    'arch script does not flag SyncEnqueuer constructor default parameters',
    () async {
      final probePath = p.join(
        _repoRoot,
        'lib/data/repositories/__arch_probe_sync_enqueuer_default_param.dart',
      );
      final probe = File(probePath);
      try {
        await probe.writeAsString(
          "// Probe: default parameter SyncEnqueuer seams stay legal.\n"
          "class _ArchProbeRepository {\n"
          "  const _ArchProbeRepository({\n"
          "    AccountPaymentSyncEnqueuer syncEnqueuer =\n"
          "        const AccountPaymentSyncEnqueuer(),\n"
          "    this.projectSyncEnqueuer = const ProjectSyncEnqueuer(),\n"
          "  });\n"
          "  final ProjectSyncEnqueuer projectSyncEnqueuer;\n"
          "}\n",
        );
        final result = await _runArchScript();
        expect(
          result.exitCode,
          0,
          reason:
              'constructor default-parameter enqueuer seams must stay legal. '
              'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
      } finally {
        if (await probe.exists()) {
          await probe.delete();
        }
      }
      final after = await _runArchScript();
      expect(
        after.exitCode,
        0,
        reason:
            'baseline must pass after removing the default-parameter probe. '
            'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
      );
    },
    tags: ['arch-script'],
  );

  test('arch script does not flag SyncEnqueuer comments, type annotations, or '
      'class declarations', () async {
    final probePath = p.join(
      _repoRoot,
      'lib/infrastructure/local/account/'
      '__arch_probe_sync_enqueuer_non_creation_refs.dart',
    );
    final probe = File(probePath);
    try {
      await probe.writeAsString(
        "// Probe: comments/type/class refs are not constructions.\n"
        "// const AccountPaymentSyncEnqueuer() appears in a comment only.\n"
        "/// ProjectWriteOffSyncEnqueuer() is doc-only.\n"
        "class TimingRecordSyncEnqueuer {}\n"
        "class _ArchProbeTypeHolder {\n"
        "  const _ArchProbeTypeHolder(this.enqueuer);\n"
        "  final AccountPaymentSyncEnqueuer? enqueuer;\n"
        "}\n",
      );
      final result = await _runArchScript();
      expect(
        result.exitCode,
        0,
        reason:
            'comments, class declarations, and type annotations must not '
            'trip the SyncEnqueuer construction rule. '
            'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
    final after = await _runArchScript();
    expect(
      after.exitCode,
      0,
      reason:
          'baseline must pass after removing the non-creation refs probe. '
          'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
    );
  }, tags: ['arch-script']);

  // 非误伤回归：往 patterns/timing 写一个"看似可疑但实际合法"的 Dart 片段，
  // 验证既不触发任何新规则也不影响既有 baseline。
  // 包含：
  //   - data/models 导入（C3 不应禁）
  //   - 名为 selectedDeviceLabel 的本地变量（不应被当成 DeviceLabel.x 误判）
  //   - 名为 myTimingService 的局部变量（不应被当成 TimingService 误判）
  //   - 注释里提及 TimingService（已有先例：timing_detail_content_pattern.dart 顶部 doc）
  //   - SingleTickerProviderStateMixin / ChangeNotifierProvider 命名
  test('arch script does not regress on legitimate patterns code shapes '
      '(data/models import, lookalike local var names, comments)', () async {
    final probePath = p.join(
      _repoRoot,
      'lib/patterns/timing/__arch_probe_false_positive_guard.dart',
    );
    final probe = File(probePath);
    try {
      await probe.writeAsString(
        "// Probe: false-positive guard for C3 rules.\n"
        "// Mentions TimingService.currentMeter in a doc comment only.\n"
        "/// TimingService.currentMeter — doc-only reference.\n"
        "import 'package:asset_ledger/data/models/device.dart';\n"
        "String archProbeFalsePositiveGuard(Device d) {\n"
        "  final selectedDeviceLabel = d.name;\n"
        "  final myTimingService = d.name;\n"
        "  // ChangeNotifierProvider / SingleTickerProviderStateMixin are\n"
        "  // first-class Flutter symbols and must not match the\n"
        "  // patterns_timing_no_provider_context rule.\n"
        "  const _ = 'ChangeNotifierProvider<int> SingleTickerProviderStateMixin';\n"
        "  return selectedDeviceLabel + myTimingService;\n"
        "}\n",
      );
      final result = await _runArchScript();
      expect(
        result.exitCode,
        0,
        reason:
            'legitimate patterns code must not trigger any new rule. '
            'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
    // baseline still passes after cleanup.
    final after = await _runArchScript();
    expect(
      after.exitCode,
      0,
      reason:
          'baseline must pass after removing the false-positive probe. '
          'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
    );
  }, tags: ['arch-script']);
}

/// 通用探针测试封装：写一个临时 .dart 文件触发某条规则，验证脚本失败 +
/// 输出含文件名，删除后 baseline 恢复。
void _archProbeTest({
  required String name,
  required String relativeProbePath,
  required String probeContent,
}) {
  test(name, () async {
    final probePath = p.join(_repoRoot, relativeProbePath);
    final probe = File(probePath);
    final probeFilename = p.basename(relativeProbePath);
    try {
      await probe.writeAsString(probeContent);
      final result = await _runArchScript();
      expect(
        result.exitCode,
        isNot(0),
        reason:
            'rule should make arch script fail. '
            'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
      expect(
        result.stdout + result.stderr,
        contains(probeFilename),
        reason:
            'failure output must point at the offending file ($probeFilename). '
            'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
      );
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
    final after = await _runArchScript();
    expect(
      after.exitCode,
      0,
      reason:
          'after removing probe, arch script must pass again. '
          'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
    );
  }, tags: ['arch-script']);
}

String get _repoRoot {
  // test/tools/<this file> → ../../ is repo root.
  final scriptDir = File(Platform.script.toFilePath()).parent;
  // For `flutter test` the script path can be the dart kernel; use cwd fallback.
  final fromCwd = Directory.current.path;
  if (File(p.join(fromCwd, 'tools', 'check_architecture.sh')).existsSync()) {
    return fromCwd;
  }
  return p.normalize(p.join(scriptDir.path, '..', '..'));
}

Future<ProcessResult> _runArchScript() async {
  final scriptPath = p.join(_repoRoot, 'tools', 'check_architecture.sh');
  return Process.run('bash', [scriptPath], workingDirectory: _repoRoot);
}
