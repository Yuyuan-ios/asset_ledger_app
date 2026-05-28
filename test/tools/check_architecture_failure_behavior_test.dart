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
    name: 'patterns_timing_no_data_services: '
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
    name: 'patterns_timing_no_timing_service: '
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
    name: 'patterns_timing_no_device_label: '
        'direct DeviceLabel call in lib/patterns/timing fails',
    relativeProbePath:
        'lib/patterns/timing/__arch_probe_device_label_call.dart',
    probeContent:
        "// Probe: patterns_timing_no_device_label\n"
        "String archProbe() => DeviceLabel.indexOnly('x');\n",
  );

  _archProbeTest(
    name: 'patterns_timing_no_provider_context: '
        'Provider.of usage in lib/patterns/timing fails',
    relativeProbePath:
        'lib/patterns/timing/__arch_probe_provider_of.dart',
    probeContent:
        "// Probe: patterns_timing_no_provider_context\n"
        "import 'package:flutter/widgets.dart';\n"
        "Object? archProbe(BuildContext c) => Provider.of<int>(c);\n",
  );

  _archProbeTest(
    name: 'patterns_no_infrastructure_imports: '
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
    name: 'patterns_no_repository_imports: '
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
    name: 'patterns_no_db_imports: '
        'db import anywhere under lib/patterns fails',
    relativeProbePath:
        'lib/patterns/account/__arch_probe_db_import.dart',
    probeContent:
        "// Probe: patterns_no_db_imports\n"
        "import 'package:asset_ledger/data/db/database.dart';\n"
        "void archProbe() { AppDatabase; }\n",
  );

  _archProbeTest(
    name: 'patterns_no_use_case_imports: '
        'use_cases import anywhere under lib/patterns fails',
    relativeProbePath:
        'lib/patterns/account/__arch_probe_use_case_import.dart',
    probeContent:
        "// Probe: patterns_no_use_case_imports\n"
        "import 'package:asset_ledger/features/timing/use_cases/"
        "save_timing_record_use_case.dart';\n"
        "void archProbe() { SaveTimingRecordUseCase; }\n",
  );

  // 非误伤回归：往 patterns/timing 写一个"看似可疑但实际合法"的 Dart 片段，
  // 验证既不触发任何新规则也不影响既有 baseline。
  // 包含：
  //   - data/models 导入（C3 不应禁）
  //   - 名为 selectedDeviceLabel 的本地变量（不应被当成 DeviceLabel.x 误判）
  //   - 名为 myTimingService 的局部变量（不应被当成 TimingService 误判）
  //   - 注释里提及 TimingService（已有先例：timing_detail_content_pattern.dart 顶部 doc）
  //   - SingleTickerProviderStateMixin / ChangeNotifierProvider 命名
  test(
    'arch script does not regress on legitimate patterns code shapes '
    '(data/models import, lookalike local var names, comments)',
    () async {
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
          reason: 'legitimate patterns code must not trigger any new rule. '
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
        reason: 'baseline must pass after removing the false-positive probe. '
            'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
      );
    },
    tags: ['arch-script'],
  );
}

/// 通用探针测试封装：写一个临时 .dart 文件触发某条规则，验证脚本失败 +
/// 输出含文件名，删除后 baseline 恢复。
void _archProbeTest({
  required String name,
  required String relativeProbePath,
  required String probeContent,
}) {
  test(
    name,
    () async {
      final probePath = p.join(_repoRoot, relativeProbePath);
      final probe = File(probePath);
      final probeFilename = p.basename(relativeProbePath);
      try {
        await probe.writeAsString(probeContent);
        final result = await _runArchScript();
        expect(
          result.exitCode,
          isNot(0),
          reason: 'rule should make arch script fail. '
              'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        expect(
          result.stdout + result.stderr,
          contains(probeFilename),
          reason: 'failure output must point at the offending file ($probeFilename). '
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
        reason: 'after removing probe, arch script must pass again. '
            'stdout:\n${after.stdout}\nstderr:\n${after.stderr}',
      );
    },
    tags: ['arch-script'],
  );
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
