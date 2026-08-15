/**
 * lang.xlsx 에 키를 추가/갱신한다 (CSV 왕복 없이 워크북을 직접 수정).
 * 사용: node add-keys.mjs keys.json [lang.xlsx]
 * keys.json 형식: [{ "key": "...", "en": "...", "ko": "..." }, ...]
 * 이미 있는 key 는 값을 덮어쓴다.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import XLSX from 'xlsx';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '../..');
const target = path.resolve(process.argv[3] || path.join(root, 'assets', 'lang', 'lang.xlsx'));
const entries = JSON.parse(fs.readFileSync(path.resolve(process.argv[2]), 'utf8'));

const wb = XLSX.readFile(target, { raw: false });
const name = wb.SheetNames.includes('lang') ? 'lang' : wb.SheetNames[0];
const sheet = wb.Sheets[name];
const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '', raw: false });

const header = rows[0].map((h) => String(h || '').trim());
const col = {};
header.forEach((h, i) => { col[h.toLowerCase()] = i; });
if (col.key !== 0) throw new Error(`first column must be "key", got ${header[0]}`);

const indexByKey = new Map();
for (let r = 1; r < rows.length; r++) {
  const k = String(rows[r][0] || '').trim();
  if (k) indexByKey.set(k, r);
}

let added = 0;
let updated = 0;
for (const e of entries) {
  const key = String(e.key).trim();
  let r = indexByKey.get(key);
  if (r === undefined) {
    r = rows.length;
    rows.push(new Array(header.length).fill(''));
    rows[r][0] = key;
    indexByKey.set(key, r);
    added++;
  } else {
    updated++;
  }
  for (const [lang, val] of Object.entries(e)) {
    if (lang === 'key') continue;
    const c = col[lang.toLowerCase()];
    if (c === undefined) throw new Error(`no column for language "${lang}" (header: ${header.join(',')})`);
    while (rows[r].length <= c) rows[r].push('');
    rows[r][c] = val;
  }
}

const out = XLSX.utils.aoa_to_sheet(rows);
wb.Sheets[name] = out;
XLSX.writeFile(wb, target);
console.log(`${target}: +${added} added, ${updated} updated, total ${rows.length - 1} keys`);
