import 'dart:convert';
import 'dart:io';

/// Usage:
///   dart run tools/gen_figma_tokens.dart [tokens.json] [out_dart]
/// Example:
///   dart run tools/gen_figma_tokens.dart assets/tokens/tokens.json lib/presentation/theme/tokens/generated/figma_tokens.g.dart
///
/// Supports:
/// - Tokens Studio / W3C tokens: leaf nodes with {"$value": ..., "$type": ...}
/// - Simple flat tokens: "colors"/"radii"/"space"/"text"
void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tools/gen_figma_tokens.dart <tokens.json> <out_dart>',
    );
    exit(64);
  }
  final inPath = args[0];
  final outPath = args[1];

  final raw = await File(inPath).readAsString();
  final data = jsonDecode(raw);

  final leaves = <_TokenLeaf>[];
  _walk(data, [], leaves);

  // Partition by semantic group.
  final colors = <String, String>{};
  final radii = <String, double>{};
  final space = <String, double>{};
  final text = <String, _TextStyleSpec>{};

  bool isColorType(_TokenLeaf t) =>
      (t.type?.toLowerCase() == 'color') ||
      t.path.isNotEmpty &&
          (t.path.first == 'color' || t.path.first == 'colors');

  bool isRadiusType(_TokenLeaf t) =>
      (t.type?.toLowerCase() == 'dimension' ||
          t.type?.toLowerCase() == 'number') &&
      t.path.isNotEmpty &&
      (t.path.first == 'radius' ||
          t.path.first == 'radii' ||
          t.path.first == 'cornerRadius');

  bool isSpaceType(_TokenLeaf t) =>
      (t.type?.toLowerCase() == 'dimension' ||
          t.type?.toLowerCase() == 'number') &&
      t.path.isNotEmpty &&
      (t.path.first == 'space' || t.path.first == 'spacing');

  bool isTextType(_TokenLeaf t) =>
      (t.type?.toLowerCase() == 'typography') ||
      (t.path.isNotEmpty &&
          (t.path.first == 'text' || t.path.first == 'typography'));

  for (final t in leaves) {
    if (isColorType(t)) {
      final name = _toCamel(_dropPrefix(t.path, ['color', 'colors']));
      final value = _parseColorToDart(t.value);
      if (name.isNotEmpty && value != null) colors[name] = value;
    } else if (isRadiusType(t)) {
      final name = _toCamel(
        _dropPrefix(t.path, ['radius', 'radii', 'cornerRadius']),
      );
      final v = _parsePxDouble(t.value);
      if (name.isNotEmpty && v != null) radii[name] = v;
    } else if (isSpaceType(t)) {
      final name = _toCamel(_dropPrefix(t.path, ['space', 'spacing']));
      final v = _parsePxDouble(t.value);
      if (name.isNotEmpty && v != null) space[name] = v;
    } else if (isTextType(t)) {
      final name = _toCamel(_dropPrefix(t.path, ['text', 'typography']));
      final spec = _parseTextStyle(t.value);
      if (name.isNotEmpty && spec != null) text[name] = spec;
    }
  }

  // Fallback: if using simple flat format, also accept top-level groups.
  if (colors.isEmpty && data is Map && data['colors'] is Map) {
    (data['colors'] as Map).forEach((k, v) {
      final name = _toCamel([k.toString()]);
      final value = _parseColorToDart(v);
      if (value != null) colors[name] = value;
    });
  }
  if (radii.isEmpty && data is Map && data['radii'] is Map) {
    (data['radii'] as Map).forEach((k, v) {
      final name = _toCamel([k.toString()]);
      final dv = _parsePxDouble(v);
      if (dv != null) radii[name] = dv;
    });
  }
  if (space.isEmpty && data is Map && data['space'] is Map) {
    (data['space'] as Map).forEach((k, v) {
      final name = _toCamel([k.toString()]);
      final dv = _parsePxDouble(v);
      if (dv != null) space[name] = dv;
    });
  }
  if (text.isEmpty && data is Map && data['text'] is Map) {
    (data['text'] as Map).forEach((k, v) {
      final name = _toCamel([k.toString()]);
      final spec = _parseTextStyle(v);
      if (spec != null) text[name] = spec;
    });
  }

  final buf = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT BY HAND.')
    ..writeln('// Generated from: $inPath')
    ..writeln("import 'package:flutter/material.dart';")
    ..writeln()
    ..writeln('class AppColors {')
    ..writeln('  const AppColors._();');

  final colorKeys = colors.keys.toList()..sort();
  for (final k in colorKeys) {
    buf.writeln('  static const $k = ${colors[k]};');
  }
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class AppRadii {');
  buf.writeln('  const AppRadii._();');
  final rKeys = radii.keys.toList()..sort();
  for (final k in rKeys) {
    buf.writeln('  static const double $k = ${radii[k]!.toStringAsFixed(2)};');
  }
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class AppSpace {');
  buf.writeln('  const AppSpace._();');
  final sKeys = space.keys.toList()..sort();
  for (final k in sKeys) {
    buf.writeln('  static const double $k = ${space[k]!.toStringAsFixed(2)};');
  }
  buf.writeln('}');
  buf.writeln();

  buf.writeln('class AppText {');
  buf.writeln('  const AppText._();');
  final tKeys = text.keys.toList()..sort();
  for (final k in tKeys) {
    final spec = text[k]!;
    buf.writeln('  static const $k = TextStyle(');
    if (spec.fontSize != null) buf.writeln('    fontSize: ${spec.fontSize},');
    if (spec.fontWeight != null) {
      buf.writeln('    fontWeight: FontWeight.w${spec.fontWeight},');
    }
    if (spec.height != null) buf.writeln('    height: ${spec.height},');
    if (spec.colorName != null) {
      buf.writeln('    color: AppColors.${spec.colorName},');
    }
    buf.writeln('  );');
    buf.writeln();
  }
  buf.writeln('}');
  buf.writeln();

  await File(outPath).writeAsString(buf.toString());
  stdout.writeln('Wrote $outPath');
}

class _TokenLeaf {
  final List<String> path;
  final dynamic value;
  final String? type;
  _TokenLeaf(this.path, this.value, this.type);
}

void _walk(dynamic node, List<String> path, List<_TokenLeaf> out) {
  if (node is Map) {
    if (node.containsKey(r'$value')) {
      out.add(_TokenLeaf(path, node[r'$value'], node[r'$type']?.toString()));
      return;
    }
    node.forEach((k, v) {
      _walk(v, [...path, k.toString()], out);
    });
  } else if (node is List) {
    for (var i = 0; i < node.length; i++) {
      _walk(node[i], [...path, i.toString()], out);
    }
  }
}

List<String> _dropPrefix(List<String> path, List<String> prefixes) {
  if (path.isEmpty) return path;
  if (prefixes.contains(path.first)) return path.sublist(1);
  return path;
}

String _toCamel(List<String> parts) {
  if (parts.isEmpty) return '';
  final cleaned = parts
      .map((p) => p.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), ' '))
      .join(' ');
  final words = cleaned
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  final first = words.first.toLowerCase();
  final rest = words
      .skip(1)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase());
  return ([first, ...rest]).join();
}

double? _parsePxDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  final m = RegExp(r'^-?\d+(\.\d+)?').firstMatch(s);
  if (m == null) return null;
  return double.tryParse(m.group(0)!);
}

/// Returns Dart code, e.g. `Color(0xFFF8F1EC)`
String? _parseColorToDart(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  // Hex: #RRGGBB or #AARRGGBB
  if (s.startsWith('#')) {
    final hex = s.substring(1);
    if (hex.length == 6) return 'Color(0xFF${hex.toUpperCase()})';
    if (hex.length == 8) return 'Color(0x${hex.toUpperCase()})';
  }
  // rgba(r,g,b,a)
  final rgba = RegExp(r'rgba?\(([^)]+)\)').firstMatch(s.toLowerCase());
  if (rgba != null) {
    final parts = rgba.group(1)!.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 3) {
      final r = int.tryParse(parts[0]);
      final g = int.tryParse(parts[1]);
      final b = int.tryParse(parts[2]);
      double a = 1.0;
      if (parts.length >= 4) a = double.tryParse(parts[3]) ?? 1.0;
      if (r == null || g == null || b == null) return null;
      final ai = (a.clamp(0.0, 1.0) * 255).round();
      final hex =
          ((ai & 0xFF) << 24) |
          ((r & 0xFF) << 16) |
          ((g & 0xFF) << 8) |
          (b & 0xFF);
      return 'Color(0x${hex.toRadixString(16).padLeft(8, '0').toUpperCase()})';
    }
  }
  return null;
}

class _TextStyleSpec {
  final double? fontSize;
  final int? fontWeight; // 100..900
  final double? height;
  final String? colorName; // reference to AppColors key
  _TextStyleSpec({this.fontSize, this.fontWeight, this.height, this.colorName});
}

_TextStyleSpec? _parseTextStyle(dynamic v) {
  if (v == null) return null;
  if (v is Map) {
    final fs = _parsePxDouble(v['fontSize'] ?? v['size'] ?? v['font_size']);
    final fwRaw = v['fontWeight'] ?? v['weight'] ?? v['font_weight'];
    int? fw;
    if (fwRaw is num) fw = fwRaw.toInt();
    if (fwRaw is String) {
      fw = int.tryParse(fwRaw.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    final lh = v['lineHeight'] ?? v['height'] ?? v['line_height'];
    double? height;
    if (lh is num) height = lh.toDouble();
    if (lh is String) {
      height = double.tryParse(lh.replaceAll(RegExp(r'[^0-9\.\-]'), ''));
    }
    final color = v['color'];
    String? colorName;
    if (color is String) {
      // Allow "colors.textPrimary" or "{color.textPrimary}"
      final c = color
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('colors.', '')
          .replaceAll('color.', '');
      colorName = _toCamel(c.split('.'));
    }
    return _TextStyleSpec(
      fontSize: fs,
      fontWeight: fw,
      height: height,
      colorName: colorName,
    );
  }
  return null;
}
