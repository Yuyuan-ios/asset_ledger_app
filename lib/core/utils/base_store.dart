import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../errors/store_failure.dart';

/// =====================================================================
/// BaseStore
/// - 统一 loading / error / notifyListeners
/// - 只负责“执行框架”，不关心业务
/// =====================================================================
abstract class BaseStore extends ChangeNotifier {
  bool _loading = false;
  StoreFailure? _failure;

  bool get loading => _loading;
  String? get error => _failure?.message;
  StoreFailure? get failure => _failure;

  @protected
  Future<T> run<T>(Future<T> Function() action) async {
    _loading = true;
    _failure = null;
    notifyListeners();

    try {
      final result = await action();
      return result;
    } catch (e) {
      _failure = _mapFailure(e);
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @protected
  void clearError() {
    _failure = null;
    notifyListeners();
  }

  StoreFailure _mapFailure(Object error) {
    if (error is StoreFailure) return error;
    if (error is ArgumentError) {
      return StoreFailure(
        type: StoreFailureType.validation,
        message: error.message?.toString() ?? '输入不合法',
        cause: error,
      );
    }
    if (error is DatabaseException) {
      return StoreFailure(
        type: StoreFailureType.database,
        message: '数据库操作失败，请稍后重试',
        cause: error,
      );
    }
    if (error is FileSystemException) {
      return StoreFailure(
        type: StoreFailureType.fileSystem,
        message: '文件操作失败，请检查文件是否可用',
        cause: error,
      );
    }
    return StoreFailure(
      type: StoreFailureType.unknown,
      message: error.toString(),
      cause: error,
    );
  }

  @protected
  Future<T> writeAndReload<T>({
    required Future<T> Function() write,
    required Future<void> Function() reload,
  }) async {
    return run(() async {
      final result = await write();
      await reload();
      return result;
    });
  }

  @protected
  Future<T> writeAndPatchLocalState<T>({
    required Future<T> Function() write,
    required void Function(T result) patch,
  }) async {
    return run(() async {
      final result = await write();
      patch(result);
      return result;
    });
  }
}
