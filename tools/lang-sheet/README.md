# lang.xlsx ↔ CSV (Node)

앱 번들 문자열은 **`assets/lang/lang.xlsx`** 만 사용합니다.

## XLSX → CSV (편집용)

```bash
cd tools/lang-sheet
npm install
npm run xlsx2csv
```

기본: `assets/lang/lang.xlsx` → `tools/lang-sheet/lang.import.csv` (UTF-8 BOM)

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
