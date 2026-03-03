class StoreFailure {
  final StoreFailureType type;
  final String message;
  final Object cause;

  const StoreFailure({
    required this.type,
    required this.message,
    required this.cause,
  });
}

enum StoreFailureType {
  validation,
  database,
  fileSystem,
  unknown,
}
