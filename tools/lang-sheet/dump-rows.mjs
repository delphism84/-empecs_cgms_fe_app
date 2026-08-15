/**
 * lang.xlsx → lang.rows.json (2차원 배열, 편집·재빌드용)
 * 사용: node dump-rows.mjs [입력.xlsx] [출력.json]
 * 기본: ../../assets/lang/lang.xlsx → ./lang.rows.json
 *
 * 최종 xlsx 는 반드시 `dart run tool/build_lang_xlsx.dart` 로 만든다
 * (SheetJS 가 쓴 파일은 앱의 package:excel 파서가 읽지 못한다 — README 참고).
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import XLSX from 'xlsx';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../..');
const input = path.resolve(process.argv[2] || path.join(root, 'assets', 'lang', 'lang.xlsx'));
const output = path.resolve(process.argv[3] || path.join(__dirname, 'lang.rows.json'));

const wb = XLSX.readFile(input, { raw: false });
const name = wb.SheetNames.includes('lang') ? 'lang' : wb.SheetNames[0];
const rows = XLSX.utils.sheet_to_json(wb.Sheets[name], { header: 1, defval: '', raw: false });
fs.writeFileSync(output, JSON.stringify(rows), 'utf8');
console.log(`Wrote ${output} (sheet: ${name}, rows: ${rows.length})`);
