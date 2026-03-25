#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

const { loadZip, readZipText } = require("./zip");
const { decodeXmlEntities, normalizeWhitespace } = require("./text");

function usage() {
  return [
    "extract-kcol-review <xlsx-file> [--header \"26.02.13 엠펙스 검토 사항\"] [--header-substr \"26.02.13\"] --out <md-path>",
    "",
    "Options:",
    "  --header         헤더 문자열(정확 일치, trim 후 비교)",
    "  --header-substr  헤더 부분문자열(포함 매칭). 기본: 26.02.13",
    "  --out      출력 md 경로 (기본: ./req260213.md)",
  ].join("\n");
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const out = { input: "", header: "", headerSubstr: "26.02.13", outPath: "req260213.md", debug: false };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (!out.input && a && !a.startsWith("--")) out.input = a;
    else if (a === "--header") out.header = args[++i] || out.header;
    else if (a === "--header-substr") out.headerSubstr = args[++i] || out.headerSubstr;
    else if (a === "--out") out.outPath = args[++i] || out.outPath;
    else if (a === "--debug") out.debug = true;
    else if (a === "--help" || a === "-h") out.help = true;
  }
  return out;
}

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
  // inline string
  if (t === "inlineStr") {
    const m = /<t\b[^>]*>([\s\S]*?)<\/t>/.exec(innerXml);
    return normalizeWhitespace(decodeXmlEntities(m?.[1] || ""));
  }
  // shared string
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
  // returns: Map("K12" -> value)
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
  for (const ch of String(col || "")) {
    n = n * 26 + (ch.charCodeAt(0) - 64);
  }
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

function inferIdColumn({ cells, headerRow, kCol = "K" }) {
  const idRe = /\b[A-Z]{2}_[0-9]{2}_[0-9]{2}\b/;
  const scores = new Map();
  // search first 80 rows below header
  for (let r = headerRow + 1; r <= headerRow + 80; r++) {
    for (let c = 1; c <= colToNum(kCol) - 1; c++) {
      const col = numToCol(c);
      const v = cells.get(`${col}${r}`) || "";
      if (idRe.test(v)) {
        scores.set(col, (scores.get(col) || 0) + 1);
      }
    }
  }
  let best = "";
  let bestScore = -1;
  for (const [col, sc] of scores.entries()) {
    if (sc > bestScore) {
      best = col;
      bestScore = sc;
    }
  }
  return best || "A";
}

function buildMarkdown({ sourcePath, headerHint, extracted }) {
  const lines = [];
  lines.push(`# 26.02.13 엠펙스 검토 사항 추출`);
  lines.push("");
  lines.push(`- 원본: \`${sourcePath}\``);
  lines.push(`- 기준 컬럼: **K열**`);
  lines.push(`- 헤더 탐색: ${headerHint}`);
  lines.push(`- 생성시각: ${new Date().toISOString()}`);
  lines.push("");

  if (!extracted.length) {
    lines.push("추출 결과가 없습니다. (헤더 문자열/시트 구조를 다시 확인 필요)");
    lines.push("");
    return lines.join("\n");
  }

  // group by id
  const groups = new Map();
  for (const it of extracted) {
    const key = it.id || "(기능번호 미확인)";
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(it);
  }
  const keys = Array.from(groups.keys()).sort((a, b) => a.localeCompare(b));

  for (const id of keys) {
    lines.push(`## ${id}`);
    lines.push("");
    const arr = groups.get(id) || [];
    for (const it of arr) {
      const loc = `${it.sheet} ${it.kAddr}${it.idAddr ? ` (id:${it.idAddr})` : ""}`;
      lines.push(`- **K열(26.02.13)**: ${it.note}`);
      if (it.prevNote) lines.push(`  - J열(25.12.30): ${it.prevNote}`);
      if (it.title) lines.push(`  - 화면명: ${it.title}`);
      if (it.summary) lines.push(`  - 주요 기능: ${it.summary}`);
      lines.push(`  - 위치: ${loc}`);
    }
    lines.push("");
  }
  return lines.join("\n");
}

function normalizeKey(s) {
  return normalizeWhitespace(s || "")
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .replace(/\s+/g, "")
    .trim();
}

async function main() {
  const a = parseArgs(process.argv);
  if (a.help || !a.input) {
    console.log(usage());
    process.exit(a.help ? 0 : 1);
  }

  const inputAbs = path.resolve(process.cwd(), a.input);
  if (!fs.existsSync(inputAbs)) {
    console.error(`Input not found: ${inputAbs}`);
    process.exit(2);
  }

  const headerExact = normalizeWhitespace(a.header || "");
  const headerExactKey = normalizeKey(headerExact);
  const headerSub = normalizeWhitespace(a.headerSubstr || "26.02.13");
  const headerSubKey = normalizeKey(headerSub);
  const useExact = !!headerExactKey;
  const zip = await loadZip(inputAbs);
  const workbookXml = await readZipText(zip, "xl/workbook.xml");
  const workbookRelsXml = await readZipText(zip, "xl/_rels/workbook.xml.rels");
  const relMap = parseRelationshipsXml(workbookRelsXml);
  const sheets = parseWorkbookSheets(workbookXml);

  const sharedStringsXml = await readZipText(zip, "xl/sharedStrings.xml");
  const sharedStrings = parseSharedStrings(sharedStringsXml);

  const extracted = [];
  for (const sheet of sheets) {
    const target = relMap.get(sheet.rid);
    if (!target) continue;
    const sheetPath = "xl/" + target.replace(/^\//, "");
    const sheetXml = await readZipText(zip, sheetPath);
    const cells = extractCells(sheetXml, sharedStrings);

    // find header row (merged cells may store the text not exactly in K)
    let headerRow = 0;
    let headerHitAddr = "";
    // collect candidate rows first (substring) then pick the row that also has 25.12.30 in the same row if possible
    const candidates = [];
    for (const [addr, v] of cells.entries()) {
      const p = splitAddr(addr);
      if (!p) continue;
      const key = normalizeKey(v);
      const hit = useExact ? (key === headerExactKey) : (headerSubKey && key.includes(headerSubKey));
      if (hit) candidates.push({ addr, row: p.row });
    }
    const rowHasToken = (row, token) => {
      const tk = normalizeKey(token);
      for (let c = 1; c <= 26; c++) {
        const col = numToCol(c);
        const v = cells.get(`${col}${row}`);
        if (!v) continue;
        if (normalizeKey(v).includes(tk)) return true;
      }
      return false;
    };
    const preferred = candidates.find((x) => rowHasToken(x.row, "25.12.30"));
    const pick = preferred || candidates[0];
    if (pick) {
      headerRow = pick.row;
      headerHitAddr = pick.addr;
    }
    if (!headerRow) {
      if (a.debug) {
        const partial = [];
        for (const [addr, v] of cells.entries()) {
          const vv = normalizeWhitespace(v);
          if (!vv) continue;
          if (vv.includes("26.02.13") || vv.includes("엠펙스") || vv.includes("검토")) {
            partial.push({ addr, v: vv.slice(0, 60) });
            if (partial.length >= 25) break;
          }
        }
        console.log(`[debug] sheet="${sheet.name}" header not found. sample hits=${partial.length}`);
        for (const h of partial) console.log(`  - ${h.addr}: ${h.v}`);
        try {
          const k4 = cells.get("K4");
          if (k4) {
            const keyCell = normalizeKey(k4);
            const keyHdr = useExact ? headerExactKey : headerSubKey;
            const codes = (s) => Array.from(String(s)).slice(0, 40).map((ch) => ch.charCodeAt(0));
            console.log(`[debug] headerKey="${keyHdr}" len=${keyHdr.length}`);
            console.log(`[debug] cell K4 key="${keyCell}" len=${keyCell.length}`);
            console.log(`[debug] headerKey codes=${JSON.stringify(codes(keyHdr))}`);
            console.log(`[debug] K4 key codes=${JSON.stringify(codes(keyCell))}`);
          }
        } catch (_) {}
      }
      continue;
    }

    const idCol = inferIdColumn({ cells, headerRow, kCol: "K" });

    // determine max row
    let maxRow = headerRow;
    for (const addr of cells.keys()) {
      const p = splitAddr(addr);
      if (p && p.row > maxRow) maxRow = p.row;
    }

    let lastId = "";
    let emptyRun = 0;
    for (let r = headerRow + 1; r <= maxRow; r++) {
      const kAddr = `K${r}`;
      const note = normalizeWhitespace(cells.get(kAddr) || "");
      if (!note) {
        emptyRun++;
        if (emptyRun >= 30 && extracted.length > 0) break; // sheet tail guard
        continue;
      }
      emptyRun = 0;
      const idAddr = `${idCol}${r}`;
      const idRaw = normalizeWhitespace(cells.get(idAddr) || "");
      const idMatch = /\b([A-Z]{2}_[0-9]{2}_[0-9]{2})\b/.exec(idRaw);
      const id = idMatch ? idMatch[1] : (idRaw || lastId);
      if (id) lastId = id;
      const title = normalizeWhitespace(cells.get(`D${r}`) || "");
      const summary = normalizeWhitespace(cells.get(`F${r}`) || "");
      const prevNote = normalizeWhitespace(cells.get(`J${r}`) || "");
      extracted.push({
        sheet: sheet.name,
        row: r,
        id: id || "",
        title,
        summary,
        prevNote,
        note,
        kAddr,
        idAddr: idRaw ? idAddr : "",
      });
    }
    if (a.debug) {
      console.log(`[debug] sheet="${sheet.name}" headerRow=${headerRow} hit=${headerHitAddr} idCol=${idCol} extractedSoFar=${extracted.length}`);
    }
  }

  const outAbs = path.resolve(process.cwd(), a.outPath || "req260213.md");
  const headerHint = useExact
    ? `exact("${headerExact}")`
    : `contains("${headerSub}") (+ same-row contains("25.12.30") 우선)`;
  const md = buildMarkdown({ sourcePath: inputAbs, headerHint, extracted });
  fs.writeFileSync(outAbs, md, "utf8");
  console.log(`OK: extracted ${extracted.length} item(s)`);
  console.log(`- out: ${outAbs}`);
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

