class DomainFailure implements Exception {
  const DomainFailure(this.code, this.message, {this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'DomainFailure($code): $message';
}
