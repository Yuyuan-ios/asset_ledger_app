import 'dart:convert';
import 'dart:typed_data';

import 'package:asset_ledger/data/services/project_share_file_picker.dart';
import 'package:asset_ledger/features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePicker implements ProjectShareFilePicker {
  _FakePicker({this.result, this.throwError});
  final PickedShareFile? result;
  final Object? throwError;

  @override
  Future<PickedShareFile?> pick() async {
    final err = throwError;
    if (err != null) throw err;
    return result;
  }
}

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  const sample = '{"magic":"ASSET_LEDGER_JZTSHARE"}';

  test('.jzt file is read into text content', () async {
    final useCase = PickExternalWorkShareFileUseCase(
      _FakePicker(
        result: PickedShareFile(name: '老王_20260519.jzt', bytes: _utf8(sample)),
      ),
    );
    final r = await useCase.pick();
    expect(r, isA<PickShareFileContent>());
    expect((r as PickShareFileContent).content, sample);
  });

  test('historical .jztshare file is still accepted', () async {
    final useCase = PickExternalWorkShareFileUseCase(
      _FakePicker(
        result: PickedShareFile(name: 'old.jztshare', bytes: _utf8(sample)),
      ),
    );
    final r = await useCase.pick();
    expect(r, isA<PickShareFileContent>());
    expect((r as PickShareFileContent).content, sample);
  });

  test('unsupported extension returns a friendly error', () async {
    final useCase = PickExternalWorkShareFileUseCase(
      _FakePicker(
        result: PickedShareFile(name: 'note.txt', bytes: _utf8(sample)),
      ),
    );
    final r = await useCase.pick();
    expect(r, isA<PickShareFileError>());
    expect((r as PickShareFileError).message, '请选择机账通 .jzt 分享包');
  });

  test('unreadable file (no bytes, no path) returns read error', () async {
    final useCase = PickExternalWorkShareFileUseCase(
      _FakePicker(result: const PickedShareFile(name: 'x.jzt')),
    );
    final r = await useCase.pick();
    expect(r, isA<PickShareFileError>());
    expect((r as PickShareFileError).message, '读取分享包失败，请重新选择文件');
  });

  test('empty content returns read error', () async {
    final useCase = PickExternalWorkShareFileUseCase(
      _FakePicker(
        result: PickedShareFile(name: 'x.jzt', bytes: _utf8('   ')),
      ),
    );
    final r = await useCase.pick();
    expect(r, isA<PickShareFileError>());
    expect((r as PickShareFileError).message, '读取分享包失败，请重新选择文件');
  });

  test('cancelled selection is not an error', () async {
    final useCase = PickExternalWorkShareFileUseCase(_FakePicker());
    final r = await useCase.pick();
    expect(r, isA<PickShareFileCancelled>());
  });

  test('picker exception is mapped to a friendly read error', () async {
    final useCase = PickExternalWorkShareFileUseCase(
      _FakePicker(throwError: Exception('boom')),
    );
    final r = await useCase.pick();
    expect(r, isA<PickShareFileError>());
    expect((r as PickShareFileError).message, '读取分享包失败，请重新选择文件');
  });
}
