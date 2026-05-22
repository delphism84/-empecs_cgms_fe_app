/**
 * UTF-8 CSV → lang.xlsx (시트명 `lang`, 1행 헤더 유지)
 * 사용: node csv-to-xlsx.mjs [입력.csv] [출력.xlsx]
 * 기본: ./lang.import.csv → ../../assets/lang/lang.xlsx
 * (CSV는 저장소에 두지 않고, xlsx-to-csv로 뽑은 뒤 수정해 이 경로에 두고 변환하는 흐름을 권장)
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { parse } from 'csv-parse/sync';
import XLSX from 'xlsx';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../..');
const inDefault = path.join(__dirname, 'lang.import.csv');
const outDefault = path.join(root, 'assets', 'lang', 'lang.xlsx');

const input = path.resolve(process.argv[2] || inDefault);
const output = path.resolve(process.argv[3] || outDefault);

if (!fs.existsSync(input)) {
  console.error(`Missing CSV: ${input}`);
  console.error('예: npm run xlsx2csv 로보낸 뒤 수정하거나, node csv-to-xlsx.mjs path/to/file.csv');
  process.exit(1);
}
const raw = fs.readFileSync(input, 'utf8');
const rows = parse(raw, {
  columns: false,
  relax_column_count: true,
  relax_quotes: true,
  skip_empty_lines: false,
  bom: true,
});

const ws = XLSX.utils.aoa_to_sheet(rows);
const wb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb, ws, 'lang');
XLSX.writeFile(wb, output);
console.log(`Wrote ${output} (${rows.length} rows)`);
