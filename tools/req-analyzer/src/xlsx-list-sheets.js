#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

const { loadZip, readZipText } = require("./zip");
const { decodeXmlEntities } = require("./text");

function parseWorkbookSheets(workbookXml) {
  const sheets = [];
  if (!workbookXml) return sheets;
  const re = /<sheet\b[^>]*\bname="([^"]+)"[^>]*\br:id="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(workbookXml))) sheets.push({ name: decodeXmlEntities(m[1]), rid: m[2] });
  return sheets;
}

async function main() {
  const input = process.argv[2];
  if (!input) {
    console.log("usage: xlsx-list-sheets <xlsx>");
    process.exit(1);
  }
  const inputAbs = path.resolve(process.cwd(), input);
  if (!fs.existsSync(inputAbs)) {
    console.error(`not_found: ${inputAbs}`);
    process.exit(2);
  }
  const zip = await loadZip(inputAbs);
  const workbookXml = await readZipText(zip, "xl/workbook.xml");
  const sheets = parseWorkbookSheets(workbookXml);
  for (const s of sheets) console.log(s.name);
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

