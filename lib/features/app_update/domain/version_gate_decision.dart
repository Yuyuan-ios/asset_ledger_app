enum VersionGateLevel { none, optional, forced }

class VersionGateDecision {
  const VersionGateDecision._({
    required this.level,
    this.updateUrl,
    this.title,
    this.content,
  });

  const VersionGateDecision.none() : this._(level: VersionGateLevel.none);

  const VersionGateDecision.optional({
    required String updateUrl,
    required String? title,
    required String? content,
  }) : this._(
         level: VersionGateLevel.optional,
         updateUrl: updateUrl,
         title: title,
         content: content,
       );

  const VersionGateDecision.forced({
    required String updateUrl,
    required String? title,
    required String? content,
  }) : this._(
         level: VersionGateLevel.forced,
         updateUrl: updateUrl,
         title: title,
         content: content,
       );

  final VersionGateLevel level;
  final String? updateUrl;
  final String? title;
  final String? content;

  bool get blocksUsage => level == VersionGateLevel.forced;
}
