#!/usr/bin/env node
/* eslint-disable no-console */

const path = require("path");
const { readJsonIfExists, writeText, ensureDir } = require("./io");
const { renderHtml } = require("./report");

const ROOT = path.resolve(__dirname, "..", "..", ".."); // empecs_cgms
const QA_DIR = path.join(ROOT, "req", "req1", "_qa");
const DB_PATH = path.join(QA_DIR, "qa-results.json");
const OUT_HTML = path.join(ROOT, "req260306-qa.html");

function parseArgs(argv) {
  const a = { ids: [] };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--ids") {
      const v = (argv[++i] || "").trim();
      if (v) a.ids = v.split(",").map((s) => s.trim()).filter(Boolean);
    }
  }
  return a;
}

function uniq(arr) {
  return Array.from(new Set((arr || []).map((x) => String(x || "").trim()).filter(Boolean)));
}

function defaultIds260306() {
  // req260306.md(PPTX)에서 반복적으로 언급된 핵심 화면/기능 ID 중심
  return uniq([
    "SC_01_06", // warm-up (알람 발생 금지)
    "SC_01_01", // scan & connect
    "SC_03_01", // connection status
    "SC_02_01", // sensor usage period
    "SC_07_01", // data share
    "AR_01_01", // alerts root
    "AR_01_02", "AR_01_03", "AR_01_04", "AR_01_05", "AR_01_06", "AR_01_08",
    "LO_02_02", "LO_02_03", // create account agreements / phone verify
  ]);
}

function fixRelPaths(items) {
  return (items || []).map((it) => {
    const rel = it?.screenshot?.relPath;
    if (!rel) return it;
    const fixed = rel.startsWith("./screenshots/")
      ? `req/req1/_qa/${rel.replace(/^\.\//, "")}`
      : rel;
    return { ...it, screenshot: { ...(it.screenshot || {}), relPath: fixed } };
  });
}

async function main() {
  const a = parseArgs(process.argv);
  ensureDir(path.dirname(OUT_HTML));
  const ids = a.ids.length ? a.ids : defaultIds260306();
  const db = readJsonIfExists(DB_PATH, { items: [] });
  const picked = (db.items || []).filter((x) => ids.includes(String(x.id)));
  const html = renderHtml({
    title: "CGMS 26.03.06 PPTX 기반 QA 리포트 (req260306.md 기준)",
    items: fixRelPaths(picked),
  });
  writeText(OUT_HTML, html);
  console.log(JSON.stringify({ ok: true, out: OUT_HTML, count: picked.length, ids }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

