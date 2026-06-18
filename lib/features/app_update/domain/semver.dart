class SemverVersion implements Comparable<SemverVersion> {
  const SemverVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  final int major;
  final int minor;
  final int patch;

  static final RegExp _numericPartPattern = RegExp(r'^\d+$');

  static SemverVersion? tryParse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final withoutBuild = trimmed.split('+').first;
    final core = withoutBuild.split('-').first;
    final parts = core.split('.');
    if (parts.length != 3) return null;

    final major = _tryParsePart(parts[0]);
    final minor = _tryParsePart(parts[1]);
    final patch = _tryParsePart(parts[2]);
    if (major == null || minor == null || patch == null) return null;

    return SemverVersion(major: major, minor: minor, patch: patch);
  }

  static int? compareStrings(String left, String right) {
    final parsedLeft = tryParse(left);
    final parsedRight = tryParse(right);
    if (parsedLeft == null || parsedRight == null) return null;
    return parsedLeft.compareTo(parsedRight);
  }

  static int? _tryParsePart(String value) {
    if (!_numericPartPattern.hasMatch(value)) return null;
    return int.tryParse(value);
  }

  @override
  int compareTo(SemverVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) return majorCompare.sign;

    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) return minorCompare.sign;

    return patch.compareTo(other.patch).sign;
  }

  @override
  bool operator ==(Object other) {
    return other is SemverVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
