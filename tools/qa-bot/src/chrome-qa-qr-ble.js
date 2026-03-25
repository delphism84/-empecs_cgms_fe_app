#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Chrome QA: 자체 에뮬레이션(QR 스캔 성공) → BLE 스캔 화면까지 검수.
 * - URL #/qa/qr-scan-success 로 진입 → 스플래시 후 QR 성공 상태 적용 → SC_01_01(Scan & Connect) 화면으로 이동
 * - 해당 화면 노출 여부 확인 후 스크린샷 저장 및 결과 JSON 출력
 *
 * 사용: node src/chrome-qa-qr-ble.js [--url http://localhost:8080] [--out-dir req/req260314/qa_captures] [--headless]
 */

const path = require("path");
const fs = require("fs");

const ROOT = path.resolve(__dirname, "..", "..", "..");

function parseArgs(argv) {
  const a = {
    url: "http://localhost:8080",
    outDir: path.join(ROOT, "req", "req260314", "qa_captures"),
    headless: true,
  };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--url" && argv[i + 1]) { a.url = argv[++i].replace(/#.*$/, ""); continue; }
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
  const qaUrl = `${a.url}#/qa/qr-scan-success`;
  const outPath = path.join(a.outDir, `chrome_qa_qr_ble_${ts}.png`);
  const reportPath = path.join(a.outDir, `chrome_qa_qr_ble_${ts}.json`);

  console.log("Chrome QA: QR 스캔 성공 시뮬 → BLE 스캔 화면 검수");
  console.log("URL:", qaUrl);

  const browser = await puppeteer.launch({
    headless: a.headless ? "new" : false,
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });

  const report = { ok: false, qaUrl, screenshot: null, message: null, checks: {} };

  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 390, height: 844 });

    await page.goto(qaUrl, { waitUntil: "networkidle2", timeout: 30000 });
    report.checks.load = true;

    // 스플래시(3초) + QA 리다이렉트 + 스캔 페이지 로드 시간
    await new Promise((r) => setTimeout(r, 5500));

    // BLE 스캔 화면 표시 대기: 여러 가능 문구 순차 시도
    const scanPageSelectors = [
      { text: "QR 스캔 후 연결", timeout: 15000 },
      { text: "Scan & Connect", timeout: 10000 },
      { text: "SC_01_01", timeout: 10000 },
      { text: "Ready", timeout: 8000 },
      { text: "BLE만 스캔", timeout: 8000 },
      { text: "No devices", timeout: 6000 },
      { text: "등록 기기만", timeout: 6000 },
    ];
    let found = false;
    for (const { text, timeout } of scanPageSelectors) {
      try {
        await page.waitForFunction(
          (t) => document.body?.innerText?.includes(t) ?? false,
          { timeout },
          text
        );
        report.checks.scanPageVisible = true;
        report.checks.scanPageMatch = text;
        found = true;
        break;
      } catch (_) {}
    }
    if (!found) {
      report.message = "BLE 스캔 화면(SC_01_01) 미노출 또는 타임아웃";
    }

    await new Promise((r) => setTimeout(r, 800));
    await page.screenshot({ path: outPath, fullPage: false });
    report.screenshot = outPath;
    report.ok = report.checks.scanPageVisible === true;
    if (report.ok) report.message = "QR 성공 시뮬 후 BLE 스캔 화면 노출 확인";
  } finally {
    await browser.close();
  }

  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2), "utf8");
  console.log("Screenshot:", report.screenshot);
  console.log("Report:", reportPath);
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.ok ? 0 : 1);
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});
