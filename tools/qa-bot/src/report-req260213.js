#!/usr/bin/env node
/* eslint-disable no-console */

const path = require("path");
const { readJsonIfExists, writeText, ensureDir } = require("./io");
const { renderHtml } = require("./report");

const ROOT = path.resolve(__dirname, "..", "..", ".."); // empecs_cgms
const QA_DIR = path.join(ROOT, "req", "req1", "_qa");
const DB_PATH = path.join(QA_DIR, "qa-results.json");
const OUT_HTML = path.join(ROOT, "req260213-qa.html");
const EXTRACTED_JSON = path.join(ROOT, "req260213.extracted.json");

function parseArgs(argv) {
  const a = { ids: [], extractedJson: EXTRACTED_JSON };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--ids") {
      const v = (argv[++i] || "").trim();
      if (v) a.ids = v.split(",").map((s) => s.trim()).filter(Boolean);
    }
    else if (x === "--extracted") {
      a.extractedJson = argv[++i] || a.extractedJson;
    }
  }
  return a;
}

function uniq(arr) {
  return Array.from(new Set((arr || []).map((x) => String(x || "").trim()).filter(Boolean)));
}

function loadIdsFromExtractedJson(extractedPath) {
  const j = readJsonIfExists(extractedPath, null);
  if (!j) return [];
  const a = [];
  for (const it of (j.reqKItems || [])) a.push(it?.id);
  for (const it of (j.implErrItems || [])) a.push(it?.id);
  // ST_01_01은 Req 시트 K열에만 존재(기본 설정 화면)이고, QA에서는 settings/unit/dotsize 등과 묶여 보이는 항목이라 포함한다.
  if (a.includes("ST_01_02") || a.includes("ST_01_03") || a.includes("ST_01_04") || a.includes("ST_02_01")) a.push("ST_01_01");
  // 26.02.13 이슈 메모에서 반복적으로 언급된 항목(웜업/알림센터/잠금배너)은 QA에서 같이 본다.
  a.push("SC_01_06");     // warm-up
  a.push("AR_01_08");     // lockscreen banner
  a.push("AR_01_08_NC");  // notification center
  return uniq(a);
}

function fixRelPaths(items) {
  // renderHtml expects relPath to be usable from OUT_HTML location(root).
  // 기존 qa-results.json의 relPath는 QA_DIR 기준("./screenshots/...")이라 root에서 깨진다.
  // root 기준 경로("req/req1/_qa/screenshots/...")로 보정.
  return (items || []).map((it) => {
    const rel = it?.screenshot?.relPath;
    if (!rel) return it;
    const fixed = rel.startsWith("./screenshots/")
      ? `req/req1/_qa/${rel.replace(/^\.\//, "")}` // -> req/req1/_qa/screenshots/...
      : rel;
    return { ...it, screenshot: { ...(it.screenshot || {}), relPath: fixed } };
  });
}

async function main() {
  const a = parseArgs(process.argv);
  ensureDir(path.dirname(OUT_HTML));
  const ids = a.ids.length ? a.ids : loadIdsFromExtractedJson(a.extractedJson);
  const db = readJsonIfExists(DB_PATH, { items: [] });
  const picked = (db.items || []).filter((x) => ids.includes(String(x.id)));
  const html = renderHtml({
    title: "CGMS 26.02.13 변경분 QA 리포트 (req260213.md 기준)",
    items: fixRelPaths(picked),
  });
  writeText(OUT_HTML, html);
  console.log(JSON.stringify({ ok: true, out: OUT_HTML, count: picked.length, ids }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

