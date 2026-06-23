import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// i18n 回归守护:已 key 化的文件,其**代码**(剥离注释后)不得再出现中文
/// (CJK)字符。用户可见文案必须走 AppLocalizations,中文只允许留在注释里。
///
/// 这是渐进式清单:每完成一个文件/模块的 key 化,加入 [migratedFiles]。
/// 反向锁定已完成的成果,防止后续提交往已迁移文件里重新硬编码中文。
const List<String> migratedFiles = <String>[
  'lib/app/inbound_share_file_gate.dart',
  'lib/features/app_update/domain/version_policy.dart',
  'lib/features/app_update/presentation/forced_update_blocker.dart',
  'lib/features/app_update/presentation/optional_update_prompt.dart',
  'lib/features/external_work/import_preview/use_cases/confirm_external_work_import_use_case.dart',
  'lib/features/external_work/import_preview/use_cases/handle_inbound_share_file_use_case.dart',
  'lib/features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart',
  'lib/features/external_work/import_preview/use_cases/prepare_external_work_import_preview_use_case.dart',
  'lib/features/external_work/import_preview/view/external_work_import_preview_page.dart',
  'lib/features/external_work/import_preview/view_model/external_work_import_preview_copy.dart',
  'lib/features/external_work/import_preview/view_model/external_work_import_preview_view_model.dart',
  'lib/features/timing/calculator/view/calculation_history_list.dart',
  'lib/features/timing/calculator/view/calculator_keypad.dart',
  'lib/features/timing/calculator/view/work_hour_calculator_sheet.dart',
  'lib/features/timing/presentation/widgets/timing_detail/timing_detail_form_sections.dart',
  'lib/features/sync/sync_conflict_review_controller.dart',
  'lib/features/sync/sync_conflict_review_page.dart',
  'lib/patterns/timing/card_main_chart_pattern.dart',
  'lib/patterns/timing/external_work_records_pattern.dart',
  'lib/patterns/timing/external_work_link_sheet.dart',
  'lib/patterns/timing/recent_records_pattern.dart',
  'lib/patterns/timing/section_header_pattern.dart',
  'lib/patterns/timing/tab_bar_pattern.dart',
  'lib/patterns/timing/timing_recent_records_slivers.dart',
  'lib/patterns/timing/timing_home_pattern.dart',
];

final RegExp _cjk = RegExp(r'[一-鿿㐀-䶿]');

/// 极简注释剥离:去掉 /* ... */ 块注释与 // 行注释。对已 key 化文件足够
/// (它们的中文只在注释里);用于回归守护,不追求完美解析。
String _stripComments(String source) {
  final withoutBlock = source.replaceAll(
    RegExp(r'/\*.*?\*/', dotAll: true),
    '',
  );
  final lines = withoutBlock.split('\n').map((line) {
    final idx = line.indexOf('//');
    return idx >= 0 ? line.substring(0, idx) : line;
  });
  return lines.join('\n');
}

void main() {
  group('i18n migrated files contain no hardcoded CJK in code', () {
    for (final path in migratedFiles) {
      test(path, () {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '清单文件不存在: $path');
        final code = _stripComments(file.readAsStringSync());
        final match = _cjk.firstMatch(code);
        expect(
          match,
          isNull,
          reason:
              '$path 代码中仍有硬编码中文(应走 AppLocalizations)：'
              '"${match == null ? '' : code.substring((match.start - 20).clamp(0, code.length), (match.start + 20).clamp(0, code.length))}"',
        );
      });
    }

    test('comment stripper detects CJK in real code but ignores comments', () {
      expect(_stripComments("// 中文注释\nfinal x = 1;"), isNot(matches(_cjk)));
      expect(_stripComments("/* 中文 */ final y = 2;"), isNot(matches(_cjk)));
      expect(_cjk.hasMatch(_stripComments("Text('中文');")), isTrue);
    });
  });
}
