import 'package:flutter/services.dart';

/// 系统从外部（Files / 微信 / 邮件 / 文件管理器）打开 `.jzt` 时，原生层
/// 透传给 Flutter 的"文件名 + 文本内容"载荷。原生层不解析 envelope，
/// 业务校验仍由 Dart 端现有 parser / duplicate checker / importer 处理。
class InboundShareFile {
  const InboundShareFile({required this.content, required this.name});

  final String content;
  final String name;
}

/// 与原生层握手的最小通道：Dart 主动调用 `consumePending` 把队列里的
/// 入站文件取出来。原生层只入队、不向 Dart 主动推送，避免 cold start
/// 时 Dart handler 未就绪导致丢消息。
abstract class InboundShareFileChannel {
  Future<InboundShareFile?> consumePending();
}

/// `com.yuyuan.assetledger/share_inbox` 通道实现。iOS / Android 必须
/// 保持同名常量；改动前先同步 AppDelegate.swift / MainActivity.kt。
class MethodChannelInboundShareFileChannel implements InboundShareFileChannel {
  MethodChannelInboundShareFileChannel({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.yuyuan.assetledger/share_inbox');

  final MethodChannel _channel;

  @override
  Future<InboundShareFile?> consumePending() async {
    try {
      final raw = await _channel.invokeMapMethod<dynamic, dynamic>(
        'consumePending',
      );
      if (raw == null) return null;
      final content = raw['content'];
      final name = raw['name'];
      if (content is! String) return null;
      return InboundShareFile(
        content: content,
        name: name is String ? name : '',
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
