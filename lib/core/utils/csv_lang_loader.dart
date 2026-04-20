import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';

/// [assets/lang/lang.csv] 로더 — 헤더 `key,en,ko,...` 형식. 열을 추가하면 해당 언어 코드로 자동 매핑.
class CsvLangAssetLoader extends AssetLoader {
  const CsvLangAssetLoader();

  static Map<String, Map<String, String>>? _byLang;
  static String? _assetPath;

  static Future<void> preload(String assetPath) async {
    _assetPath = assetPath;
    _byLang = await _loadAll(assetPath);
  }

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final String file = _assetPath ??
        (path.endsWith('.csv') ? path : '$path/lang.csv');
    _byLang ??= await _loadAll(file);
    final String code = locale.languageCode.toLowerCase();
    final Map<String, String>? map = _byLang![code] ?? _byLang!['en'];
    if (map == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(map);
  }

  /// 핫 리로드·테스트용
  static void clearCache() {
    _byLang = null;
  }

  static Future<Map<String, Map<String, String>>> _loadAll(String path) async {
    final String raw = await rootBundle.loadString(path);
    final List<List<String>> rows = _parseCsv(raw);
    if (rows.isEmpty) return {'en': <String, String>{}};

    final List<String> header = rows.first.map((e) => e.trim()).toList();
    if (header.isEmpty || header[0].toLowerCase() != 'key') {
      throw FormatException('lang.csv: first column must be "key", got ${header.first}');
    }

    final Map<String, int> colIndex = <String, int>{};
    for (int i = 1; i < header.length; i++) {
      final String h = header[i].trim().toLowerCase();
      if (h.isNotEmpty && h != 'notes') colIndex[h] = i;
    }
    if (!colIndex.containsKey('en')) {
      throw FormatException('lang.csv: "en" column required');
    }

    final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
    for (final String lang in colIndex.keys) {
      out[lang] = <String, String>{};
    }

    final String enKey = 'en';
    for (int r = 1; r < rows.length; r++) {
      final List<String> row = rows[r];
      if (row.isEmpty) continue;
      final String key = row[0].trim();
      if (key.isEmpty || key.startsWith('#') || key.startsWith('//')) continue;

      for (final MapEntry<String, int> e in colIndex.entries) {
        final String lang = e.key;
        final int idx = e.value;
        String val = idx < row.length ? row[idx].trim() : '';
        if (val.isEmpty && lang != enKey) {
          final int enIdx = colIndex[enKey]!;
          val = enIdx < row.length ? row[enIdx].trim() : '';
        }
        if (val.isNotEmpty) {
          out[lang]![key] = val;
        }
      }
    }

    return out;
  }

  static List<List<String>> _parseCsv(String input) {
    final List<List<String>> result = <List<String>>[];
    List<String> row = <String>[];
    final StringBuffer sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < input.length; i++) {
      final String c = input[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          sb.write(c);
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (c == ',') {
          row.add(sb.toString());
          sb.clear();
        } else if (c == '\n' || c == '\r') {
          if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
            i++;
          }
          row.add(sb.toString());
          sb.clear();
          if (row.any((String e) => e.trim().isNotEmpty)) {
            result.add(List<String>.from(row));
          }
          row = <String>[];
        } else {
          sb.write(c);
        }
      }
    }
    row.add(sb.toString());
    if (row.any((String e) => e.trim().isNotEmpty)) {
      result.add(row);
    }
    return result;
  }
}
