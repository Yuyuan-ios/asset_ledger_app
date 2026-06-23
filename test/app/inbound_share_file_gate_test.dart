import 'package:asset_ledger/app/inbound_share_file_gate.dart';
import 'package:asset_ledger/data/services/inbound_share_file_channel.dart';
import 'package:asset_ledger/l10n/gen/app_localizations.dart';
import 'package:asset_ledger/l10n/gen/app_localizations_zh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _QueueChannel implements InboundShareFileChannel {
  _QueueChannel(this._queue);
  final List<InboundShareFile?> _queue;
  int consumeCallCount = 0;

  void enqueue(InboundShareFile file) {
    _queue.add(file);
  }

  @override
  Future<InboundShareFile?> consumePending() async {
    consumeCallCount++;
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }
}

Future<void> _pumpGate(
  WidgetTester tester, {
  required InboundShareFileChannel channel,
  required List<String> contents,
  required List<String> errors,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: InboundShareFileGate(
        channel: channel,
        onContent: (c) async {
          contents.add(c);
        },
        onError: errors.add,
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
  // first post-frame drain
  await tester.pumpAndSettle();
}

void main() {
  final zh = AppLocalizationsZh();

  testWidgets('drains a valid .jzt file on cold start and forwards content', (
    tester,
  ) async {
    final channel = _QueueChannel([
      const InboundShareFile(
        content: '{"magic":"ASSET_LEDGER_JZTSHARE"}',
        name: '老王.jzt',
      ),
    ]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    expect(contents, ['{"magic":"ASSET_LEDGER_JZTSHARE"}']);
    expect(errors, isEmpty);
    // 至少 2 次：一次取出文件，一次再读到 null。
    expect(channel.consumeCallCount, greaterThanOrEqualTo(2));
  });

  testWidgets('empty content surfaces a read-error message', (tester) async {
    final channel = _QueueChannel([
      const InboundShareFile(content: '   ', name: 'empty.jzt'),
    ]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    expect(contents, isEmpty);
    expect(errors, [zh.externalWorkPickReadFailure]);
  });

  testWidgets('non-.jzt extension surfaces invalid-type message', (
    tester,
  ) async {
    final channel = _QueueChannel([
      const InboundShareFile(content: '{}', name: 'note.txt'),
    ]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    expect(contents, isEmpty);
    expect(errors, [zh.externalWorkPickInvalidType]);
  });

  testWidgets('legacy .jztshare extension is rejected (no historical compat)', (
    tester,
  ) async {
    final channel = _QueueChannel([
      const InboundShareFile(content: '{}', name: 'legacy.jztshare'),
    ]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    expect(contents, isEmpty);
    expect(errors, [zh.externalWorkPickInvalidType]);
  });

  testWidgets('empty queue is a no-op (no content, no error)', (tester) async {
    final channel = _QueueChannel(<InboundShareFile?>[]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    expect(contents, isEmpty);
    expect(errors, isEmpty);
    expect(channel.consumeCallCount, greaterThanOrEqualTo(1));
  });

  testWidgets('lifecycle resumed drains a newly-arrived file', (tester) async {
    final channel = _QueueChannel(<InboundShareFile?>[]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    // 模拟 Android onNewIntent / iOS application(_:open:url:) 后的前台恢复。
    channel.enqueue(
      const InboundShareFile(content: '{"k":1}', name: 'inbound.jzt'),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(contents, ['{"k":1}']);
  });

  testWidgets('drains multiple queued files in order', (tester) async {
    final channel = _QueueChannel([
      const InboundShareFile(content: '{"a":1}', name: 'a.jzt'),
      const InboundShareFile(content: '{"b":2}', name: 'b.jzt'),
    ]);
    final contents = <String>[];
    final errors = <String>[];

    await _pumpGate(
      tester,
      channel: channel,
      contents: contents,
      errors: errors,
    );

    expect(contents, ['{"a":1}', '{"b":2}']);
    expect(errors, isEmpty);
  });
}
