class JztShareEnvelope {
  const JztShareEnvelope({
    required this.magic,
    required this.formatVersion,
    required this.packageType,
    required this.producer,
    required this.createdAt,
    required this.shareId,
    required this.integrity,
    required this.payload,
  });

  static const magicValue = 'ASSET_LEDGER_JZTSHARE';
  static const supportedFormatVersion = 1;
  static const projectExternalWorkShareType = 'project_external_work_share';
  static const jsonPayloadEncoding = 'json';

  final String magic;
  final int formatVersion;
  final String packageType;
  final JztShareProducer producer;
  final String createdAt;
  final String shareId;
  final JztShareIntegrity integrity;
  final Map<String, Object?> payload;
}

class JztShareProducer {
  const JztShareProducer({
    required this.appName,
    required this.appVersion,
    required this.platform,
  });

  final String appName;
  final String appVersion;
  final String platform;
}

class JztShareIntegrity {
  const JztShareIntegrity({
    required this.payloadEncoding,
    required this.payloadSha256,
  });

  final String payloadEncoding;
  final String payloadSha256;
}
