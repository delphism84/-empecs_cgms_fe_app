# lang.xlsx ↔ CSV (Node)

앱 번들 문자열은 **`assets/lang/lang.xlsx`** 만 사용합니다.

## XLSX → CSV (편집용)

```bash
cd tools/lang-sheet
npm install
npm run xlsx2csv
```

기본: `assets/lang/lang.xlsx` → `tools/lang-sheet/lang.import.csv` (UTF-8 BOM)

## ⚠ 최종 xlsx 는 Dart 로 쓴다

앱은 `package:excel` 로 xlsx 를 읽는다. SheetJS(`xlsx` npm)가 쓴 파일은
`styles.xml` 에 `numFmtId="56"` 을 넣어 이 파서가
`custom numFmtId starts at 164 but found a value of 56` 로 **디코딩에 실패**한다.
로더(`XlsxLangAssetLoader`)는 실패를 삼키고 빈 맵으로 폴백하므로,
화면에 `auth_login_title` 같은 **키 문자열이 그대로 노출**된다.

따라서 편집은 Node 로 하더라도 **최종 산출은 반드시 Dart 스크립트**로 한다:

```bash
node tools/lang-sheet/dump-rows.mjs     # xlsx → lang.rows.json (편집용)
# lang.rows.json 수정 또는 node add-keys.mjs keys.json
dart run tool/build_lang_xlsx.dart      # lang.rows.json → assets/lang/lang.xlsx
flutter test test/lang_xlsx_smoke_test.dart   # 파서 호환 검증
```

## CSV → XLSX (앱에 반영)

`lang.import.csv`를 수정한 뒤:

```bash
npm run csv2xlsx
```

기본: `tools/lang-sheet/lang.import.csv` → `assets/lang/lang.xlsx`

다른 경로를 쓰려면:

```bash
node csv-to-xlsx.mjs /path/to/strings.csv /path/to/out.xlsx
node xlsx-to-csv.mjs /path/to/strings.xlsx /path/to/out.csv
```

## 의존성

- `xlsx` (SheetJS), `csv-parse` — `package.json` 참고.
