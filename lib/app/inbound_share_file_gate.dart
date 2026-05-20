import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/services/inbound_share_file_channel.dart';
import '../features/external_work/import_preview/use_cases/handle_inbound_share_file_use_case.dart';
import '../features/external_work/import_preview/use_cases/pick_external_work_share_file_use_case.dart';
import '../features/external_work/import_preview/view/external_work_import_preview_page.dart';
import '../features/timing/state/timing_external_work_store.dart';

/// Signature for delivering inbound-file content into the import preview.
typedef InboundShareContentHandler = Future<void> Function(String content);

/// Signature for surfacing inbound-file errors to the user.
typedef InboundShareErrorHandler = void Function(String message);

/// 监听原生通道，把系统外部打开的 `.jzt` 文件内容引入 App 内导入预览流程。
/// 自身只负责：(1) 启动 / 前台恢复时排空原生队列；(2) 调用纯 Dart use case
/// 做扩展名 + 非空校验；(3) 进入现有 `ExternalWorkImportPreviewPage`；
/// (4) 预览返回后刷新 `TimingExternalWorkStore`。
///
/// envelope / payload_sha256 / backup 拒绝 / duplicate / importer 全部
/// 沿用现有 prepare/confirm 链路，不在本组件复制业务逻辑。
class InboundShareFileGate extends StatefulWidget {
  const InboundShareFileGate({
    super.key,
    required this.child,
    this.channel,
    this.handleUseCase,
    this.onContent,
    this.onError,
  });

  final Widget child;
  final InboundShareFileChannel? channel;
  final HandleInboundShareFileUseCase? handleUseCase;

  /// 注入测试覆盖；生产默认推 `ExternalWorkImportPreviewPage` 并刷新 store。
  final InboundShareContentHandler? onContent;

  /// 注入测试覆盖；生产默认 SnackBar 提示。
  final InboundShareErrorHandler? onError;

  @override
  State<InboundShareFileGate> createState() => _InboundShareFileGateState();
}

class _InboundShareFileGateState extends State<InboundShareFileGate>
    with WidgetsBindingObserver {
  late final InboundShareFileChannel _channel;
  late final HandleInboundShareFileUseCase _handleUseCase;
  bool _draining = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel ?? MethodChannelInboundShareFileChannel();
    _handleUseCase =
        widget.handleUseCase ?? const HandleInboundShareFileUseCase();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_drain());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (mounted) {
        final pending = await _channel.consumePending();
        if (pending == null) return;
        if (!mounted) return;
        await _dispatch(pending);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _dispatch(InboundShareFile file) async {
    final result = _handleUseCase.handle(file);
    switch (result) {
      case PickShareFileCancelled():
        return;
      case PickShareFileError(:final message):
        (widget.onError ?? _defaultErrorHandler)(message);
      case PickShareFileContent(:final content):
        await (widget.onContent ?? _defaultContentHandler)(content);
    }
  }

  Future<void> _defaultContentHandler(String content) async {
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (navigator == null) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExternalWorkImportPreviewPage(initialContent: content),
      ),
    );
    if (!mounted) return;
    final store = _readStore();
    if (store != null) {
      unawaited(store.loadAll());
    }
  }

  TimingExternalWorkStore? _readStore() {
    try {
      return context.read<TimingExternalWorkStore>();
    } catch (_) {
      return null;
    }
  }

  void _defaultErrorHandler(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
