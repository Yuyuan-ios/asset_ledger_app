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
