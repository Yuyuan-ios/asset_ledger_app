import 'package:asset_ledger/data/services/inbound_share_file_channel.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/handle_inbound_share_file_use_case.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const useCase = HandleInboundShareFileUseCase();
  const sample = '{"magic":"ASSET_LEDGER_JZTSHARE"}';

  test('inbound .jzt content surfaces as PickShareFileContent', () {
    final result = useCase.handle(
      const InboundShareFile(content: sample, name: '老王_20260519.jzt'),
    );
    expect(result, isA<PickShareFileContent>());
    expect((result as PickShareFileContent).content, sample);
  });

  test('inbound .jzt with mixed-case extension is still accepted', () {
    final result = useCase.handle(
      const InboundShareFile(content: sample, name: 'Share.JZT'),
    );
    expect(result, isA<PickShareFileContent>());
  });

  test('inbound legacy .jztshare is rejected (no historical compat)', () {
    final result = useCase.handle(
      const InboundShareFile(content: sample, name: 'old.jztshare'),
    );
    expect(result, isA<PickShareFileError>());
    expect(
      (result as PickShareFileError).code,
      PickShareFileErrorCode.invalidType,
    );
  });

  test('inbound non-.jzt extension is rejected with friendly message', () {
    final result = useCase.handle(
      const InboundShareFile(content: sample, name: 'note.txt'),
    );
    expect(result, isA<PickShareFileError>());
    expect(
      (result as PickShareFileError).code,
      PickShareFileErrorCode.invalidType,
    );
  });

  test('inbound empty content (whitespace only) is rejected', () {
    final result = useCase.handle(
      const InboundShareFile(content: '   \n\t  ', name: 'x.jzt'),
    );
    expect(result, isA<PickShareFileError>());
    expect(
      (result as PickShareFileError).code,
      PickShareFileErrorCode.readFailure,
    );
  });

  test(
    'inbound nameless file (e.g. content URI without DISPLAY_NAME) is rejected',
    () {
      final result = useCase.handle(
        const InboundShareFile(content: sample, name: ''),
      );
      expect(result, isA<PickShareFileError>());
      expect(
        (result as PickShareFileError).code,
        PickShareFileErrorCode.invalidType,
      );
    },
  );
}
