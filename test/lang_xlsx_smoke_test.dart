import 'dart:io';

import 'package:excel/excel.dart' hide TextSpan;
import 'package:flutter_test/flutter_test.dart';

/// `assets/lang/lang.xlsx` 가 앱과 동일한 파서(`package:excel`)로 읽히는지 확인한다.
/// 시트가 깨지면 로더가 조용히 빈 맵으로 폴백해 UI에 키 문자열이 그대로 노출된다.
void main() {
  test('lang.xlsx decodes with key/en/ko header and required keys', () {
    final Excel excel =
        Excel.decodeBytes(File('assets/lang/lang.xlsx').readAsBytesSync());
    final String name =
        excel.tables.containsKey('lang') ? 'lang' : excel.tables.keys.first;
    final Sheet sheet = excel.tables[name]!;
    final List<List<Data?>> rows = sheet.rows;

    expect(rows.isNotEmpty, isTrue, reason: 'no rows in sheet $name');
    final List<String> header =
        rows.first.map((Data? d) => (d?.value?.toString() ?? '').trim()).toList();
    expect(header.first.toLowerCase(), 'key');
    expect(header.map((String h) => h.toLowerCase()).contains('en'), isTrue);
    expect(header.map((String h) => h.toLowerCase()).contains('ko'), isTrue);

    final int koIdx = header.map((String h) => h.toLowerCase()).toList().indexOf('ko');
    final Map<String, String> ko = <String, String>{};
    for (int r = 1; r < rows.length; r++) {
      final List<Data?> row = rows[r];
      if (row.isEmpty) continue;
      final String k = (row.first?.value?.toString() ?? '').trim();
      if (k.isEmpty) continue;
      final String v =
          koIdx < row.length ? (row[koIdx]?.value?.toString() ?? '').trim() : '';
      if (v.isNotEmpty) ko[k] = v;
    }

    // 기존 화면 키 + 이번에 추가한 만료 알림 키가 모두 살아 있어야 한다.
    for (final String k in <String>[
      'auth_login_title',
      'sensor_expiry_title',
      'sensor_expiry_remain',
      'sensor_expired_title',
      'sensor_connect_new',
    ]) {
      expect(ko[k], isNotNull, reason: 'missing ko value for "$k"');
    }
    expect(ko.length, greaterThan(600), reason: 'ko rows: ${ko.length}');
  });
}
