#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
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

function splitAddr(addr) {
  const m = /^([A-Z]+)(\d+)$/.exec(String(addr || "").toUpperCase());
  if (!m) return null;
  return { col: m[1], row: Number(m[2]) };
}

function colToNum(col) {
  let n = 0;
  for (const ch of String(col || "")) n = n * 26 + (ch.charCodeAt(0) - 64);
  return n;
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

function normalizeKey(s) {
  return normalizeWhitespace(s || "")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\s+/g, "")
    .trim();
}

function findMaxRow(cells) {
  let maxRow = 1;
  for (const addr of cells.keys()) {
    const p = splitAddr(addr);
    if (p && p.row > maxRow) maxRow = p.row;
  }
  return maxRow;
}

function findHeaderRowByTokens({ cells, tokens, maxScanRow = 80 }) {
  const want = tokens.map(normalizeKey).filter(Boolean);
  for (let r = 1; r <= maxScanRow; r++) {
    let hit = 0;
    for (let c = 1; c <= 26; c++) {
      const v = cells.get(`${numToCol(c)}${r}`) || "";
      const k = normalizeKey(v);
      if (!k) continue;
      for (const t of want) if (k === t) hit++;
    }
    if (hit >= want.length) return r;
  }
  return 0;
}

function findColumnByHeader({ cells, headerRow, headerIncludes }) {
  const want = headerIncludes.map(normalizeKey).filter(Boolean);
  for (let c = 1; c <= 60; c++) {
    const col = numToCol(c);
    const v = cells.get(`${col}${headerRow}`) || "";
    const k = normalizeKey(v);
    if (!k) continue;
    const ok = want.every((t) => k.includes(t));
    if (ok) return col;
  }
  return "";
}

function groupBy(items, keyFn) {
  const m = new Map();
  for (const it of items) {
    const k = keyFn(it);
    if (!m.has(k)) m.set(k, []);
    m.get(k).push(it);
  }
  return m;
}

function buildMarkdown({ sourceAbs, reqKItems, implErrItems }) {
  const lines = [];
  lines.push(`# 26.02.13 요구사항/점검사항 재추출`);
  lines.push("");
  lines.push(`- 원본: \`${sourceAbs}\``);
  lines.push(`- 생성시각: ${new Date().toISOString()}`);
  lines.push("");

  lines.push(`## Req 시트 · "26.02.13 엠펙스 검토 사항" (K열)`);
  lines.push("");
  if (!reqKItems.length) {
    lines.push("- (추출 없음)");
    lines.push("");
  } else {
    const byId = groupBy(reqKItems, (x) => x.id || "(기능번호 미확인)");
    const ids = Array.from(byId.keys()).sort((a, b) => a.localeCompare(b));
    for (const id of ids) {
      lines.push(`### ${id}`);
      lines.push("");
      for (const it of byId.get(id)) {
        lines.push(`- **K열(26.02.13)**: ${it.kNote}`);
        if (it.jPrev) lines.push(`  - J열(25.12.30): ${it.jPrev}`);
        if (it.screenName) lines.push(`  - 화면명: ${it.screenName}`);
        if (it.main) lines.push(`  - 주요 기능: ${it.main}`);
        if (it.detail) lines.push(`  - 상세 설명: ${it.detail}`);
        lines.push(`  - 위치: Req ${it.kAddr} (id:${it.idAddr})`);
      }
      lines.push("");
    }
  }

  lines.push(`## 동작 구현 오류 내용 시트 · 구현 요청/재확인 목록`);
  lines.push("");
  if (!implErrItems.length) {
    lines.push("- (추출 없음)");
    lines.push("");
  } else {
    const bySection = groupBy(implErrItems, (x) => x.section || "(미분류)");
    const sections = Array.from(bySection.keys()).sort((a, b) => a.localeCompare(b));
    for (const sec of sections) {
      lines.push(`### ${sec}`);
      lines.push("");
      const byId = groupBy(bySection.get(sec), (x) => x.id || "(기능번호 미확인)");
      const ids = Array.from(byId.keys()).sort((a, b) => a.localeCompare(b));
      for (const id of ids) {
        lines.push(`- **${id}**`);
        for (const it of byId.get(id)) {
          if (it.request) lines.push(`  - 구현 요청: ${it.request}`);
          if (it.recheck) lines.push(`  - 재확인: ${it.recheck}`);
          if (it.etc) lines.push(`  - 기타: ${it.etc}`);
          lines.push(`  - 위치: 동작 구현 오류 내용 ${it.idAddr}`);
        }
      }
      lines.push("");
    }
  }

  lines.push(`## 참고: "26.02.13 확인 사항" 시트들`);
  lines.push("");
  lines.push(`- AR_01_01 / LO_02_01 / SC_07_01 / Setting / SC_01_01 시트는 이 파일 기준으로 "26.02.13 확인 사항" + 번호(429~433)만 포함되어 있습니다.`);
  lines.push(`- 상세 텍스트는 "Req" 또는 "동작 구현 오류 내용" 시트에서 추출됩니다.`);
  lines.push("");

  return lines.join("\n");
}

async function analyzeReqSheet({ cells }) {
  // header row (row 4 in this file)
  const headerRow = findHeaderRowByTokens({ cells, tokens: ["페이지ID", "화면명", "주요기능", "상세설명"] }) || 0;
  if (!headerRow) return [];

  const idCol = findColumnByHeader({ cells, headerRow, headerIncludes: ["페이지ID"] }) || "C";
  const screenCol = findColumnByHeader({ cells, headerRow, headerIncludes: ["화면명"] }) || "D";
  const mainCol = findColumnByHeader({ cells, headerRow, headerIncludes: ["주요기능"] }) || "E";
  const detailCol = findColumnByHeader({ cells, headerRow, headerIncludes: ["상세설명"] }) || "F";
  const prevCol = findColumnByHeader({ cells, headerRow, headerIncludes: ["25.12.30"] }) || "J";
  const kCol = findColumnByHeader({ cells, headerRow, headerIncludes: ["26.02.13"] }) || "K";

  const maxRow = findMaxRow(cells);
  const idRe = /\b[A-Z]{2}_[0-9]{2}_[0-9]{2}\b/;
  const out = [];
  let lastId = "";
  for (let r = headerRow + 1; r <= maxRow; r++) {
    const kAddr = `${kCol}${r}`;
    const kNote = normalizeWhitespace(cells.get(kAddr) || "");
    if (!kNote) continue;

    const idAddr = `${idCol}${r}`;
    const rawId = normalizeWhitespace(cells.get(idAddr) || "");
    const idMatch = idRe.exec(rawId);
    const id = idMatch ? idMatch[0] : (rawId || lastId);
    if (id) lastId = id;

    out.push({
      id: id || "",
      kNote,
      jPrev: normalizeWhitespace(cells.get(`${prevCol}${r}`) || ""),
      screenName: normalizeWhitespace(cells.get(`${screenCol}${r}`) || ""),
      main: normalizeWhitespace(cells.get(`${mainCol}${r}`) || ""),
      detail: normalizeWhitespace(cells.get(`${detailCol}${r}`) || ""),
      kAddr,
      idAddr,
    });
  }
  return out;
}

async function analyzeImplErrSheet({ cells }) {
  const maxRow = findMaxRow(cells);
  const idRe = /\b[A-Z]{2}_[0-9]{2}_[0-9]{2}\b/;
  const out = [];
  let section = "";

  // find header rows dynamically: any row with "페이지 ID" and "구현 요청내용"
  const headerKey1 = normalizeKey("페이지 ID");
  const headerKey2 = normalizeKey("구현 요청내용");
  const headerKey3 = normalizeKey("재 확인 요청 내용");

  // cache row -> map col->value
  const rowCache = new Map();
  function getRow(r) {
    if (rowCache.has(r)) return rowCache.get(r);
    const m = new Map();
    for (let c = 1; c <= 60; c++) {
      const col = numToCol(c);
      const v = cells.get(`${col}${r}`);
      if (v) m.set(col, normalizeWhitespace(v));
    }
    rowCache.set(r, m);
    return m;
  }

  for (let r = 1; r <= maxRow; r++) {
    const row = getRow(r);
    const b = row.get("B") || "";
    const cVal = row.get("C") || "";
    // section markers look like: B="Report" and C="0" (or "Alarm")
    if (b && /^\d+$/.test(cVal) && cVal === "0") section = b;

    // header row?
    const cKey = normalizeKey(row.get("C") || "");
    const dKey = normalizeKey(row.get("D") || "");
    const eKey = normalizeKey(row.get("E") || "");
    if (cKey === headerKey1 && dKey === headerKey2 && eKey === headerKey3) {
      // parse subsequent rows until next header/section boundary
      for (let rr = r + 1; rr <= maxRow; rr++) {
        const row2 = getRow(rr);
        const c2 = normalizeWhitespace(row2.get("C") || "");
        const d2 = normalizeWhitespace(row2.get("D") || "");
        const e2 = normalizeWhitespace(row2.get("E") || "");
        const f2 = normalizeWhitespace(row2.get("F") || "");
        const b2 = normalizeWhitespace(row2.get("B") || "");

        // next header/table/section starts
        const ck = normalizeKey(c2);
        const dk = normalizeKey(d2);
        const ek = normalizeKey(e2);
        if (ck === headerKey1 && dk === headerKey2 && ek === headerKey3) break;
        if (b2 && /^\d+$/.test(c2) && c2 === "0") break; // section marker

        const m = idRe.exec(c2);
        if (!m) continue;
        const id = m[0];
        out.push({
          section: section || "",
          id,
          request: d2,
          recheck: e2,
          etc: f2,
          idAddr: `C${rr}`,
        });
      }
    }
  }
  return out;
}

function parseArgs(argv) {
  const a = { input: "", out: "req260213.md", jsonOut: "req260213.extracted.json" };
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const x = args[i];
    if (!a.input && x && !x.startsWith("--")) a.input = x;
    else if (x === "--out") a.out = args[++i] || a.out;
    else if (x === "--json") a.jsonOut = args[++i] || a.jsonOut;
  }
  return a;
}

async function main() {
  const a = parseArgs(process.argv);
  if (!a.input) {
    console.log("usage: extract-260213 <xlsx> [--out req260213.md] [--json req260213.extracted.json]");
    process.exit(1);
  }
  const inputAbs = path.resolve(process.cwd(), a.input);
  if (!fs.existsSync(inputAbs)) {
    console.error(`not_found: ${inputAbs}`);
    process.exit(2);
  }

  const zip = await loadZip(inputAbs);
  const workbookXml = await readZipText(zip, "xl/workbook.xml");
  const workbookRelsXml = await readZipText(zip, "xl/_rels/workbook.xml.rels");
  const relMap = parseRelationshipsXml(workbookRelsXml);
  const sheets = parseWorkbookSheets(workbookXml);
  const sharedStringsXml = await readZipText(zip, "xl/sharedStrings.xml");
  const sharedStrings = parseSharedStrings(sharedStringsXml);

  function loadSheetCellsByName(name) {
    const sh = sheets.find((s) => s.name === name);
    if (!sh) return null;
    const target = relMap.get(sh.rid);
    if (!target) return null;
    const sheetPath = "xl/" + target.replace(/^\//, "");
    return readZipText(zip, sheetPath).then((xml) => extractCells(xml, sharedStrings));
  }

  const reqCells = await loadSheetCellsByName("Req");
  const implCells = await loadSheetCellsByName("동작 구현 오류 내용");
  const reqKItems = reqCells ? await analyzeReqSheet({ cells: reqCells }) : [];
  const implErrItems = implCells ? await analyzeImplErrSheet({ cells: implCells }) : [];

  const md = buildMarkdown({ sourceAbs: inputAbs, reqKItems, implErrItems });
  const outAbs = path.resolve(process.cwd(), a.out);
  fs.writeFileSync(outAbs, md, "utf8");

  const jsonAbs = path.resolve(process.cwd(), a.jsonOut);
  fs.writeFileSync(
    jsonAbs,
    JSON.stringify({ generatedAt: new Date().toISOString(), source: inputAbs, reqKItems, implErrItems }, null, 2),
    "utf8"
  );

  console.log(JSON.stringify({ ok: true, out: outAbs, json: jsonAbs, counts: { reqK: reqKItems.length, implErr: implErrItems.length } }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

