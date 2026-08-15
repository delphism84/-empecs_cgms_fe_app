import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';

/// `tools/lang-sheet/lang.rows.json`(2차원 배열) → `assets/lang/lang.xlsx`
///
/// **왜 Dart 로 쓰는가**: 앱은 `package:excel` 로 xlsx 를 읽는데, SheetJS(`xlsx` npm)가
/// 쓴 파일은 `styles.xml` 에 numFmtId 56 을 넣어 이 파서가
/// `custom numFmtId starts at 164 but found a value of 56` 로 **디코딩에 실패**한다.
/// 로더는 실패를 삼키고 빈 맵으로 폴백하므로, 화면에 `auth_login_title` 같은
/// 키 문자열이 그대로 노출된다. 따라서 최종 xlsx 는 반드시 이 스크립트로 만든다.
///
/// 사용:
///   node tools/lang-sheet/dump-rows.mjs      # 현재 xlsx → lang.rows.json (편집용)
///   dart run tool/build_lang_xlsx.dart       # lang.rows.json → assets/lang/lang.xlsx
void main(List<String> args) {
  final String src = args.isNotEmpty
      ? args[0]
      : 'tools/lang-sheet/lang.rows.json';
  final String out = args.length > 1 ? args[1] : 'assets/lang/lang.xlsx';

  final List<dynamic> raw = jsonDecode(File(src).readAsStringSync()) as List<dynamic>;
  if (raw.isEmpty) {
    stderr.writeln('$src: empty');
    exitCode = 1;
    return;
  }

  final Excel excel = Excel.createExcel();
  final String created = excel.getDefaultSheet()!;
  excel.rename(created, 'lang');
  final Sheet sheet = excel['lang'];

  int cells = 0;
  for (int r = 0; r < raw.length; r++) {
    final List<dynamic> row = (raw[r] as List<dynamic>);
    for (int c = 0; c < row.length; c++) {
      final String v = '${row[c] ?? ''}';
      if (v.isEmpty) continue;
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
          .value = TextCellValue(v);
      cells++;
    }
  }

  final List<int>? bytes = excel.save();
  if (bytes == null) {
    stderr.writeln('excel.save() returned null');
    exitCode = 1;
    return;
  }
  File(out).writeAsBytesSync(bytes);
  stdout.writeln('$out: ${raw.length - 1} keys, $cells cells written');

  // 자체 검증: 방금 쓴 파일이 앱과 동일한 파서로 다시 읽히는지 확인.
  final Excel back = Excel.decodeBytes(File(out).readAsBytesSync());
  final Sheet check = back.tables['lang']!;
  stdout.writeln('verify: sheet "lang" rows=${check.maxRows}');
}
