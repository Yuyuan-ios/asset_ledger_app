import 'domain_failure.dart';

class ErrorMessageMapper {
  const ErrorMessageMapper._();

  static String toUserMessage(Object error, {String fallback = '操作失败，请稍后重试。'}) {
    if (error is DomainFailure) return error.message;
    if (error is StateError) return error.message;
    if (error is ArgumentError) {
      return error.message?.toString() ?? '输入不合法';
    }
    return fallback;
  }
}
