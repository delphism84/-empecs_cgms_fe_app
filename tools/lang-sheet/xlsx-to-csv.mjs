/**
 * lang.xlsx → UTF-8 CSV (시트 `lang` 또는 첫 시트)
 * 사용: node xlsx-to-csv.mjs [입력.xlsx] [출력.csv]
 * 기본: ../../assets/lang/lang.xlsx → ./lang.import.csv
 * (이 CSV를 수정한 뒤 `npm run csv2xlsx`로 다시 xlsx 생성)
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import XLSX from 'xlsx';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../..');
const inDefault = path.join(root, 'assets', 'lang', 'lang.xlsx');
const outDefault = path.join(__dirname, 'lang.import.csv');

const input = path.resolve(process.argv[2] || inDefault);
const output = path.resolve(process.argv[3] || outDefault);

const wb = XLSX.readFile(input, { cellDates: true, raw: false });
const name = wb.SheetNames.includes('lang') ? 'lang' : wb.SheetNames[0];
const csv = XLSX.utils.sheet_to_csv(wb.Sheets[name], { FS: ',', RS: '\n' });
fs.writeFileSync(output, '\ufeff' + csv.replace(/^\ufeff/, ''), 'utf8');
console.log(`Wrote ${output} (sheet: ${name})`);
