enum SyncStatus {
  localOnly,
  pendingUpload,
  synced,
  pendingUpdate,
  pendingDelete,
  conflict,
  failed;

  static SyncStatus parse(String value) {
    return SyncStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SyncStatus.failed,
    );
  }
}

enum SyncOutboxStatus {
  pending,
  processing,
  synced,
  failed;

  static SyncOutboxStatus parse(String value) {
    return SyncOutboxStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => SyncOutboxStatus.failed,
    );
  }
}

enum WorkRecordReviewStatus {
  draft,
  submitted,
  accepted,
  rejected,
  merged,
  conflict,
  deleted;

  static WorkRecordReviewStatus parse(String value) {
    return WorkRecordReviewStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => WorkRecordReviewStatus.conflict,
    );
  }
}
