#!/usr/bin/env node
/* eslint-disable no-console */
const path = require("path");

const { loadZip, readZipText } = require("./zip");
const { decodeXmlEntities, normalizeWhitespace } = require("./text");

function parseRelationshipsXml(relsXml) {
  const map = new Map();
  if (!relsXml) return map;
  const re = /<Relationship\b[^>]*\bId="([^"]+)"[^>]*\bTarget="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(relsXml))) map.set(m[1], m[2]);
  return map;
}
function parseWorkbookSheets(workbookXml) {
  const sheets = [];
  if (!workbookXml) return sheets;
  const re = /<sheet\b[^>]*\bname="([^"]+)"[^>]*\br:id="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(workbookXml))) sheets.push({ name: decodeXmlEntities(m[1]), rid: m[2] });
  return sheets;
}
function parseSharedStrings(sharedStringsXml) {
  const out = [];
  if (!sharedStringsXml) return out;
  const siRe = /<si\b[\s\S]*?<\/si>/g;
  const tRe = /<t\b[^>]*>([\s\S]*?)<\/t>/g;
  const sis = sharedStringsXml.match(siRe) || [];
  for (const si of sis) {
    const parts = [];
    let m;
    while ((m = tRe.exec(si))) parts.push(decodeXmlEntities(m[1]));
    out.push(normalizeWhitespace(parts.join("")));
  }
  return out;
}
function parseCellValue({ t, innerXml, sharedStrings }) {
  if (t === "inlineStr") {
    const m = /<t\b[^>]*>([\s\S]*?)<\/t>/.exec(innerXml);
    return normalizeWhitespace(decodeXmlEntities(m?.[1] || ""));
  }
  const vMatch = /<v\b[^>]*>([\s\S]*?)<\/v>/.exec(innerXml);
  const rawV = decodeXmlEntities(vMatch?.[1] || "");
  if (!rawV) return "";
  if (t === "s") {
    const idx = Number(rawV);
    return normalizeWhitespace(sharedStrings[idx] || "");
  }
  return normalizeWhitespace(rawV);
}
function extractCells(sheetXml, sharedStrings) {
  const cells = new Map();
  if (!sheetXml) return cells;
  const cellRe = /<c\b([^>]*)>([\s\S]*?)<\/c>/g;
  let m;
  while ((m = cellRe.exec(sheetXml))) {
    const attrs = m[1] || "";
    const inner = m[2] || "";
    const r = /\br="([^"]+)"/.exec(attrs)?.[1] || "";
    if (!r) continue;
    const t = /\bt="([^"]+)"/.exec(attrs)?.[1] || "";
    const v = parseCellValue({ t, innerXml: inner, sharedStrings });
    if (v) cells.set(r, v);
  }
  return cells;
}
function numToCol(n) {
  let x = n;
  let s = "";
  while (x > 0) {
    const r = (x - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    x = Math.floor((x - 1) / 26);
  }
  return s || "A";
}

function parseArgs(argv) {
  const a = {
    input: "",
    sheet: "",
    sheetIndex: null,
    from: 1,
    to: 30,
    cols: 14, // A..N
  };
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const x = args[i];
    if (!a.input && x && !x.startsWith("--")) a.input = x;
    else if (x === "--sheet") a.sheet = args[++i] || a.sheet;
    else if (x === "--sheet-index") a.sheetIndex = Number(args[++i]);
    else if (x === "--from") a.from = Number(args[++i] || a.from);
    else if (x === "--to") a.to = Number(args[++i] || a.to);
    else if (x === "--cols") a.cols = Number(args[++i] || a.cols);
  }
  return a;
}

async function main() {
  const a = parseArgs(process.argv);
  if (!a.input) {
    console.log("usage: xlsx-dump-rows <xlsx> --sheet \"동작 구현 오류 내용\" --from 1 --to 40 --cols 14");
    process.exit(1);
  }
  const inputAbs = path.resolve(process.cwd(), a.input);
  const zip = await loadZip(inputAbs);
  const workbookXml = await readZipText(zip, "xl/workbook.xml");
  const workbookRelsXml = await readZipText(zip, "xl/_rels/workbook.xml.rels");
  const relMap = parseRelationshipsXml(workbookRelsXml);
  const sheets = parseWorkbookSheets(workbookXml);
  const ssXml = await readZipText(zip, "xl/sharedStrings.xml");
  const sharedStrings = parseSharedStrings(ssXml);

  const want = (a.sheet || "").trim();
  const wantNorm = normalizeWhitespace(want);
  // debug: if sheet lookup fails, print available sheets
  const debugSheets = () => {
    try {
      const codes = (s) => Array.from(String(s)).slice(0, 60).map((ch) => ch.charCodeAt(0));
      console.error(`[debug] want="${want}" wantNorm="${wantNorm}" sheetIndex=${String(a.sheetIndex)} codes=${JSON.stringify(codes(wantNorm))}`);
      console.error("[debug] sheets:");
      for (const s of sheets) console.error(`- "${s.name}"`);
    } catch (_) {}
  };
  const shByIndex =
    (typeof a.sheetIndex === "number" && Number.isFinite(a.sheetIndex) && a.sheetIndex >= 0)
      ? (sheets[a.sheetIndex] || null)
      : null;
  const sh = shByIndex || (wantNorm
    ? (sheets.find((s) => normalizeWhitespace(s.name) === wantNorm) ||
        sheets.find((s) => normalizeWhitespace(s.name).includes(wantNorm)) ||
        sheets.find((s) => wantNorm.includes(normalizeWhitespace(s.name))) ||
        null)
    : (sheets[0] || null));
  if (!sh) { debugSheets(); throw new Error("no_sheet"); }
  const target = relMap.get(sh.rid);
  if (!target) throw new Error("no_sheet_target");
  const sheetPath = "xl/" + target.replace(/^\//, "");
  const sheetXml = await readZipText(zip, sheetPath);
  const cells = extractCells(sheetXml, sharedStrings);

  const out = [];
  const from = Math.max(1, a.from | 0);
  const to = Math.max(from, a.to | 0);
  const cols = Math.max(1, Math.min(60, a.cols | 0));
  for (let r = from; r <= to; r++) {
    const row = { r };
    let any = false;
    for (let c = 1; c <= cols; c++) {
      const col = numToCol(c);
      const addr = `${col}${r}`;
      const v = cells.get(addr) || "";
      if (v) any = true;
      row[col] = v;
    }
    if (any) out.push(row);
  }

  console.log(JSON.stringify({ file: inputAbs, sheet: sh.name, from, to, cols, rows: out }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

