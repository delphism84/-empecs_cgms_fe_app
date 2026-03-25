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

async function main() {
  const input = process.argv[2];
  const sheetName = process.argv[3] || "Req";
  const row = Number(process.argv[4] || "8");
  if (!input) {
    console.log("usage: xlsx-dump-cells <xlsx> [sheetName=Req] [row=8]");
    process.exit(1);
  }
  const inputAbs = path.resolve(process.cwd(), input);
  const zip = await loadZip(inputAbs);
  const workbookXml = await readZipText(zip, "xl/workbook.xml");
  const workbookRelsXml = await readZipText(zip, "xl/_rels/workbook.xml.rels");
  const relMap = parseRelationshipsXml(workbookRelsXml);
  const sheets = parseWorkbookSheets(workbookXml);
  const ssXml = await readZipText(zip, "xl/sharedStrings.xml");
  const sharedStrings = parseSharedStrings(ssXml);

  const sh = sheets.find((s) => s.name === sheetName) || sheets[0];
  if (!sh) throw new Error("no_sheet");
  const target = relMap.get(sh.rid);
  const sheetPath = "xl/" + target.replace(/^\//, "");
  const sheetXml = await readZipText(zip, sheetPath);
  const cells = extractCells(sheetXml, sharedStrings);

  const cols = [];
  for (let c = 1; c <= 12; c++) {
    // A..L
    let x = c;
    let s = "";
    while (x > 0) {
      const r = (x - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      x = Math.floor((x - 1) / 26);
    }
    cols.push(s);
  }
  const out = {};
  for (const col of cols) {
    const addr = `${col}${row}`;
    out[addr] = cells.get(addr) || "";
  }
  console.log(JSON.stringify({ file: inputAbs, sheet: sh.name, row, cells: out }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

