import 'package:flutter/foundation.dart';

/// =====================================================================
/// BaseStore
/// - 统一 loading / error / notifyListeners
/// - 只负责“执行框架”，不关心业务
/// =====================================================================
abstract class BaseStore extends ChangeNotifier {
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  @protected
  Future<T> run<T>(Future<T> Function() action) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await action();
      return result;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @protected
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
