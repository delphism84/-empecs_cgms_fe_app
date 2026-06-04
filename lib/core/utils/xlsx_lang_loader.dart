import 'package:csv/csv.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:excel/excel.dart' hide TextSpan;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// [assets/lang/lang.xlsx] 로더 — 첫 시트(또는 이름이 `lang`인 시트) 1행: `key`, `en`, `ko`, …
///
/// 열 이름은 ISO 639-1 언어 코드(소문자). `notes` 열은 무시. 빈 셀은 `en` 폴백(기존 CSV 로더와 동일).
class XlsxLangAssetLoader extends AssetLoader {
  const XlsxLangAssetLoader();
  static const String _csvFallbackAsset = 'tools/lang-sheet/lang.import.csv';

  static Map<String, Map<String, String>>? _byLang;
  static String? _assetPath;

  static Future<void> preload(String assetPath) async {
    _assetPath = assetPath;
    try {
      _byLang = await _loadAll(assetPath);
    } catch (_) {
      try {
        _assetPath = _csvFallbackAsset;
        _byLang = await _loadAll(_csvFallbackAsset);
      } catch (_) {
        // 언어 리소스 파싱 실패로 앱 부팅이 중단되지 않게 최소 맵으로 계속 진행.
        _byLang = <String, Map<String, String>>{
          'en': <String, String>{},
          'ko': <String, String>{},
        };
      }
    }
  }

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final String file = _assetPath ??
        (path.toLowerCase().endsWith('.xlsx') ? path : '$path/lang.xlsx');
    if (_byLang == null) {
      try {
        _byLang = await _loadAll(file);
      } catch (_) {
        try {
          _assetPath = _csvFallbackAsset;
          _byLang = await _loadAll(_csvFallbackAsset);
        } catch (_) {
          _byLang = <String, Map<String, String>>{
            'en': <String, String>{},
            'ko': <String, String>{},
          };
        }
      }
    }
    final String code = locale.languageCode.toLowerCase();
    final Map<String, String>? map = _byLang![code] ?? _byLang!['en'];
    if (map == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(map);
  }

  static void clearCache() {
    _byLang = null;
  }

  static Future<Map<String, Map<String, String>>> _loadAll(String path) async {
    if (path.toLowerCase().endsWith('.csv')) {
      return _loadAllFromCsv(path);
    }
    final ByteData bd = await rootBundle.load(path);
    final Uint8List bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    final Excel excel = Excel.decodeBytes(bytes);

    String sheetName = 'lang';
    if (!excel.tables.containsKey(sheetName) && excel.tables.isNotEmpty) {
      sheetName = excel.tables.keys.first;
    }
    final Sheet? sheet = excel.tables[sheetName];
    if (sheet == null || sheet.maxRows == 0) {
      return {'en': <String, String>{}};
    }

    final List<List<Data?>> rows = sheet.rows;
    if (rows.isEmpty) return {'en': <String, String>{}};

    final List<String> header = rows.first.map(_dataToTrimmedString).toList();
    if (header.isEmpty || header[0].toLowerCase() != 'key') {
      throw FormatException('lang.xlsx: first column must be "key", got ${header.first}');
    }

    final Map<String, int> colIndex = <String, int>{};
    for (int i = 1; i < header.length; i++) {
      final String h = header[i].trim().toLowerCase();
      if (h.isNotEmpty && h != 'notes') colIndex[h] = i;
    }
    if (!colIndex.containsKey('en')) {
      throw FormatException('lang.xlsx: "en" column required');
    }

    final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
    for (final String lang in colIndex.keys) {
      out[lang] = <String, String>{};
    }

    const String enKey = 'en';
    for (int r = 1; r < rows.length; r++) {
      final List<Data?> row = rows[r];
      if (row.isEmpty) continue;
      final String key = _dataToTrimmedString(row.isNotEmpty ? row[0] : null);
      if (key.isEmpty || key.startsWith('#') || key.startsWith('//')) continue;

      for (final MapEntry<String, int> e in colIndex.entries) {
        final String lang = e.key;
        final int idx = e.value;
        String val = idx < row.length ? _dataToTrimmedString(row[idx]) : '';
        if (val.isEmpty && lang != enKey) {
          final int enIdx = colIndex[enKey]!;
          val = enIdx < row.length ? _dataToTrimmedString(row[enIdx]) : '';
        }
        if (val.isNotEmpty) {
          out[lang]![key] = val;
        }
      }
    }

    return out;
  }

  static Future<Map<String, Map<String, String>>> _loadAllFromCsv(String path) async {
    final String raw = await rootBundle.loadString(path);
    final List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(raw);
    if (rows.isEmpty) return {'en': <String, String>{}};

    final List<String> header = rows.first.map((e) => (e ?? '').toString().trim()).toList();
    if (header.isEmpty || header[0].toLowerCase() != 'key') {
      throw FormatException('lang csv: first column must be "key"');
    }

    final Map<String, int> colIndex = <String, int>{};
    for (int i = 1; i < header.length; i++) {
      final String h = header[i].trim().toLowerCase();
      if (h.isNotEmpty && h != 'notes') colIndex[h] = i;
    }
    if (!colIndex.containsKey('en')) {
      throw FormatException('lang csv: "en" column required');
    }

    final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
    for (final String lang in colIndex.keys) {
      out[lang] = <String, String>{};
    }

    const String enKey = 'en';
    for (int r = 1; r < rows.length; r++) {
      final List<dynamic> row = rows[r];
      if (row.isEmpty) continue;
      final String key = (row[0] ?? '').toString().trim();
      if (key.isEmpty || key.startsWith('#') || key.startsWith('//')) continue;

      for (final MapEntry<String, int> e in colIndex.entries) {
        final String lang = e.key;
        final int idx = e.value;
        String val = idx < row.length ? (row[idx] ?? '').toString().trim() : '';
        if (val.isEmpty && lang != enKey) {
          final int enIdx = colIndex[enKey]!;
          val = enIdx < row.length ? (row[enIdx] ?? '').toString().trim() : '';
        }
        if (val.isNotEmpty) {
          out[lang]![key] = _normalizeEscapes(val);
        }
      }
    }
    return out;
  }

  static String _dataToTrimmedString(Data? d) {
    if (d == null) return '';
    return _normalizeEscapes(_cellValueToString(d.value).trim());
  }

  /// 시트/CSV에 적힌 `\n` 등 이스케이프를 실제 제어문자로 변환 (UI에 `\n` 노출 방지).
  static String _normalizeEscapes(String s) {
    return s
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
  }

  static String _cellValueToString(CellValue? v) {
    if (v == null) return '';
    if (v is TextCellValue) {
      final dynamic raw = v.value;
      if (raw is InlineSpan) {
        return _textSpanToPlain(raw);
      }
      return raw.toString();
    }
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is BoolCellValue) return v.value.toString();
    if (v is FormulaCellValue) return v.formula;
    if (v is DateCellValue) return v.toString();
    if (v is DateTimeCellValue) return v.toString();
    if (v is TimeCellValue) return v.toString();
    return v.toString();
  }

  static String _textSpanToPlain(InlineSpan span) {
    if (span is TextSpan) {
      final StringBuffer b = StringBuffer();
      if (span.text != null) b.write(span.text);
      if (span.children != null) {
        for (final InlineSpan c in span.children!) {
          b.write(_textSpanToPlain(c));
        }
      }
      return b.toString();
    }
    return span.toString();
  }
}
