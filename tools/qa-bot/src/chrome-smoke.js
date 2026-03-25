#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Chrome(웹) 스모크 테스트: Puppeteer로 지정 URL 접속 → 스크린샷 저장.
 * Flutter 웹은 BleEmuServer가 없으므로 네비/API 호출 없이 페이지 로드 + 캡처만 수행.
 *
 * 사용: node src/chrome-smoke.js [--url http://localhost:8080] [--out-dir req/req260314/qa_captures] [--headless]
 */

const path = require("path");
const fs = require("fs");

const ROOT = path.resolve(__dirname, "..", "..", "..");

function parseArgs(argv) {
  const a = { url: "http://localhost:8080", outDir: path.join(ROOT, "req", "req260314", "qa_captures"), headless: true };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--url" && argv[i + 1]) { a.url = argv[++i]; continue; }
    if (x === "--out-dir" && argv[i + 1]) { a.outDir = path.isAbsolute(argv[i + 1]) ? argv[++i] : path.join(ROOT, argv[++i]); continue; }
    if (x === "--headless") { a.headless = true; continue; }
    if (x === "--no-headless") { a.headless = false; continue; }
  }
  return a;
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

async function main() {
  const a = parseArgs(process.argv);
  let puppeteer;
  try {
    puppeteer = require("puppeteer");
  } catch (e) {
    console.error("puppeteer not found. Run: cd tools/qa-bot && npm install puppeteer");
    process.exit(1);
  }

  ensureDir(a.outDir);
  const ts = new Date().toISOString().replace(/[:.]/g, "-");
  const outPath = path.join(a.outDir, `chrome_smoke_${ts}.png`);

  console.log("Launching browser (headless:", a.headless, ") ...");
  const browser = await puppeteer.launch({
    headless: a.headless ? "new" : false,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844 });
    console.log("Navigating to", a.url, "...");
    await page.goto(a.url, { waitUntil: "networkidle2", timeout: 30000 });
    await new Promise((r) => setTimeout(r, 1500));
    await page.screenshot({ path: outPath, fullPage: false });
    console.log("Screenshot saved:", outPath);
  } finally {
    await browser.close();
  }
  console.log(JSON.stringify({ ok: true, screenshot: outPath }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});
