import 'dart:convert';

import 'package:archive/archive.dart';

import '../models/timing_worklog_report.dart';

class TimingWorklogExcelWriter {
  const TimingWorklogExcelWriter({this.recordsPerPage = defaultRecordsPerPage});

  static const int defaultRecordsPerPage = 20;
  static const int columnCount = 16;
  static const String signatureText =
      '本人已核对上述设备工时记录，确认数据真实无误，同意按此进行结算。项目负责人签字：                日期：';

  final int recordsPerPage;

  List<int> write(TimingWorklogReport report) {
    final sheet = _SheetXmlBuilder(
      report: report,
      recordsPerPage: recordsPerPage,
    );
    final archive = Archive()
      ..addFile(_textFile('[Content_Types].xml', _contentTypesXml))
      ..addFile(_textFile('_rels/.rels', _rootRelsXml))
      ..addFile(_textFile('docProps/app.xml', _appPropsXml))
      ..addFile(_textFile('docProps/core.xml', _corePropsXml))
      ..addFile(_textFile('xl/worksheets/sheet1.xml', sheet.build()))
      ..addFile(_textFile('xl/workbook.xml', _workbookXml(sheet.lastRow)))
      ..addFile(_textFile('xl/_rels/workbook.xml.rels', _workbookRelsXml))
      ..addFile(_textFile('xl/styles.xml', _stylesXml));
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw const TimingWorklogExcelWriterException('工时表生成失败');
    return bytes;
  }

  List<TimingWorklogPage> paginate(TimingWorklogReport report) {
    if (report.rows.isEmpty) return const [];
    final pages = <TimingWorklogPage>[];
    for (var start = 0; start < report.rows.length; start += recordsPerPage) {
      final end = (start + recordsPerPage).clamp(0, report.rows.length);
      pages.add(
        TimingWorklogPage(
          number: pages.length + 1,
          rows: report.rows.sublist(start, end),
        ),
      );
    }
    return pages;
  }

  static ArchiveFile _textFile(String name, String content) {
    final data = utf8.encode(content);
    return ArchiveFile(name, data.length, data);
  }
}

class TimingWorklogPage {
  const TimingWorklogPage({required this.number, required this.rows});
  final int number;
  final List<TimingWorklogReportRow> rows;
}

class TimingWorklogExcelWriterException implements Exception {
  const TimingWorklogExcelWriterException(this.message);
  final String message;
  @override
  String toString() => message;
}

class _SheetXmlBuilder {
  _SheetXmlBuilder({required this.report, required this.recordsPerPage});
  final TimingWorklogReport report;
  final int recordsPerPage;
  final _rows = StringBuffer();
  final _merges = <String>[];
  final _breaks = <int>[];
  var _row = 0;
  int get lastRow => _row;

  String build() {
    if (report.rows.isEmpty) {
      _appendPage(const [], isLast: true);
    } else {
      for (var start = 0; start < report.rows.length; start += recordsPerPage) {
        final end = (start + recordsPerPage).clamp(0, report.rows.length);
        _appendPage(
          report.rows.sublist(start, end),
          isLast: end == report.rows.length,
        );
      }
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<dimension ref="A1:P$_row"/><sheetViews><sheetView workbookViewId="0"/></sheetViews><sheetFormatPr defaultRowHeight="18"/>
<cols>$_colsXml</cols><sheetData>$_rows</sheetData><mergeCells count="${_merges.length}">${_merges.map((r) => '<mergeCell ref="$r"/>').join()}</mergeCells>${_breaksXml()}
<printOptions horizontalCentered="1"/><pageMargins left="0.25" right="0.25" top="0.35" bottom="0.35" header="0.2" footer="0.2"/><pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>
</worksheet>''';
  }

  void _appendPage(
    List<TimingWorklogReportRow> pageRows, {
    required bool isLast,
  }) {
    final titleRow = _row + 1;
    _textRow([report.title], 1, 30);
    _merges.add('A$titleRow:P$titleRow');
    _headerRows();
    for (final row in pageRows) {
      _dataRow(row);
    }
    for (var i = pageRows.length; i < recordsPerPage; i += 1) {
      _mixedRow(List<_Cell>.filled(16, const _Cell.text('')), 3, 20);
    }
    _totalRow(pageRows, isLast: isLast);
    final signatureRow = _row + 1;
    _textRow([TimingWorklogExcelWriter.signatureText], 5, 32);
    _merges.add('A$signatureRow:P$signatureRow');
    if (!isLast) _breaks.add(_row);
  }

  void _headerRows() {
    final top = _row + 1;
    _textRow(
      [
        '序号',
        '日期',
        '机型',
        '驾驶员',
        '施工地点',
        '',
        '工作内容',
        '上午',
        '中午',
        '中午',
        '下午',
        '合计时间（时）',
        '',
        '',
        '负责人',
        '备注',
      ],
      2,
      22,
    );
    _textRow(
      [
        '',
        '',
        '',
        '',
        '地点',
        '项目名称',
        '',
        '',
        '',
        '',
        '',
        '上午',
        '下午',
        '全天',
        '',
        '',
      ],
      2,
      22,
    );
    final bottom = _row;
    for (final col in ['A', 'B', 'C', 'D', 'G', 'H', 'I', 'J', 'K', 'O', 'P']) {
      _merges.add('$col$top:$col$bottom');
    }
    _merges
      ..add('E$top:F$top')
      ..add('L$top:N$top');
  }

  void _dataRow(TimingWorklogReportRow row) {
    _mixedRow(
      [
        _Cell.number(row.sequence.toDouble()),
        _Cell.text(_dateWithDots(row.date)),
        _Cell.text(row.deviceName),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        _Cell.number(row.startMeter),
        _Cell.number(row.endMeter),
        _Cell.number(row.hours),
        const _Cell.text(''),
        const _Cell.text(''),
      ],
      3,
      20,
    );
  }

  void _totalRow(
    List<TimingWorklogReportRow> pageRows, {
    required bool isLast,
  }) {
    final pageTotal = pageRows.fold<double>(0, (sum, row) => sum + row.hours);
    final label = isLast ? '合计' : '小计';
    final total = isLast ? report.totalHours : pageTotal;
    _mixedRow(
      [
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        _Cell.text(label),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        const _Cell.text(''),
        _Cell.number(total),
        const _Cell.text(''),
        const _Cell.text(''),
      ],
      4,
      22,
    );
  }

  void _textRow(List<String> values, int style, double height) {
    _row += 1;
    final cells = <String>[];
    for (var i = 0; i < TimingWorklogExcelWriter.columnCount; i += 1) {
      cells.add(
        _textCell(_cellRef(i, _row), i < values.length ? values[i] : '', style),
      );
    }
    _rows.write(
      '<row r="$_row" ht="$height" customHeight="1">${cells.join()}</row>',
    );
  }

  void _mixedRow(List<_Cell> values, int style, double height) {
    _row += 1;
    final cells = <String>[];
    for (var i = 0; i < TimingWorklogExcelWriter.columnCount; i += 1) {
      final value = i < values.length ? values[i] : const _Cell.text('');
      cells.add(
        value.isNumber
            ? _numberCell(_cellRef(i, _row), value.numberValue, style)
            : _textCell(_cellRef(i, _row), value.textValue, style),
      );
    }
    _rows.write(
      '<row r="$_row" ht="$height" customHeight="1">${cells.join()}</row>',
    );
  }

  String _breaksXml() {
    if (_breaks.isEmpty) return '';
    final items = _breaks
        .map((row) => '<brk id="$row" max="16383" man="1"/>')
        .join();
    return '<rowBreaks count="${_breaks.length}" manualBreakCount="${_breaks.length}">$items</rowBreaks>';
  }
}

class _Cell {
  const _Cell.text(this.textValue) : numberValue = null;
  const _Cell.number(this.numberValue) : textValue = '';
  final String textValue;
  final double? numberValue;
  bool get isNumber => numberValue != null;
}

String _cellRef(int columnIndex, int row) => '${_columnName(columnIndex)}$row';
String _columnName(int index) {
  var n = index + 1;
  final chars = <String>[];
  while (n > 0) {
    final rem = (n - 1) % 26;
    chars.insert(0, String.fromCharCode(65 + rem));
    n = (n - rem - 1) ~/ 26;
  }
  return chars.join();
}

String _textCell(String ref, String value, int style) =>
    '<c r="$ref" t="inlineStr" s="$style"><is><t>${_xml(value)}</t></is></c>';
String _numberCell(String ref, double? value, int style) {
  final n = value ?? 0;
  final text = n == n.roundToDouble()
      ? n.toInt().toString()
      : n.toStringAsFixed(1);
  return '<c r="$ref" s="$style"><v>$text</v></c>';
}

String _dateWithDots(int ymd) {
  final s = ymd.toString().padLeft(8, '0');
  return '${s.substring(0, 4)}.${s.substring(4, 6)}.${s.substring(6, 8)}';
}

String _xml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

const _colsXml =
    '<col min="1" max="1" width="6" customWidth="1"/>'
    '<col min="2" max="2" width="12" customWidth="1"/>'
    '<col min="3" max="3" width="14" customWidth="1"/>'
    '<col min="4" max="4" width="10" customWidth="1"/>'
    '<col min="5" max="6" width="13" customWidth="1"/>'
    '<col min="7" max="7" width="15" customWidth="1"/>'
    '<col min="8" max="11" width="10" customWidth="1"/>'
    '<col min="12" max="14" width="11" customWidth="1"/>'
    '<col min="15" max="15" width="11" customWidth="1"/>'
    '<col min="16" max="16" width="15" customWidth="1"/>';
const _contentTypesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>';
const _rootRelsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>';
const _workbookRelsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>';
String _workbookXml(int lastRow) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="工时打卡汇总" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm.Print_Area" localSheetId="0">\'工时打卡汇总\'!\$A\$1:\$P\$$lastRow</definedName></definedNames></workbook>';
const _corePropsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>挖机工时打卡汇总</dc:title><dc:creator>FleetLedger</dc:creator><cp:lastModifiedBy>FleetLedger</cp:lastModifiedBy><dcterms:created xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:modified></cp:coreProperties>';
const _appPropsXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>FleetLedger</Application></Properties>';
const _stylesXml =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="1"><numFmt numFmtId="164" formatCode="0.#"/></numFmts><fonts count="4"><font><sz val="11"/><name val="Arial"/></font><font><b/><sz val="18"/><name val="Arial"/></font><font><b/><sz val="11"/><name val="Arial"/></font><font><sz val="11"/><name val="Arial"/></font></fonts><fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF2CC"/><bgColor indexed="64"/></patternFill></fill></fills><borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="6"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf><xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="164" fontId="3" fillId="2" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf><xf numFmtId="164" fontId="2" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf><xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" wrapText="1"/></xf></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';
