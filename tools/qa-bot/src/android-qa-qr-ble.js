#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * Android 자체 검수 QA: 에뮬 API로 QR 스캔 성공 시뮬 → BLE 스캔 화면으로 이동 후 캡처.
 * - 기기 연결: adb devices
 * - 앱 실행 중 + adb forward tcp:18789 tcp:8788 필요
 *
 * 사용: node src/android-qa-qr-ble.js [--port 18789] [--device <adbId>]
 */

const path = require("path");
const fs = require("fs");

const ROOT = path.resolve(__dirname, "..", "..", "..");
const { requestJson } = require("./http");
const { pickDevice, screenshotPng, screenshotPngViaPull } = require("./adb");
const { ensureDir } = require("./io");

const QA_DIR = path.join(ROOT, "req", "req260314", "qa_captures");
const REPORT_JSON = path.join(QA_DIR, "android_qa_qr_ble_result.json");

function parseArgs(argv) {
  const a = { port: 18789 };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--port" && argv[i + 1]) { a.port = Number(argv[++i]); continue; }
    if (x === "--device" && argv[i + 1]) { a.device = argv[++i]; continue; }
  }
  return a;
}

async function main() {
  const a = parseArgs(process.argv);
  const base = `http://127.0.0.1:${a.port}`;
  const report = { ok: false, steps: {}, screenshot: null, error: null };

  console.log("Android QA: QR 스캔 성공 시뮬 → BLE 스캔 화면 검수");
  console.log("Emu base:", base);

  let emuOk = false;
  try {
    // 1) QR 스캔 성공 시뮬레이션
    console.log("1) POST /emu/app/sc0104/qrSuccess ...");
    const qrRes = await requestJson(`${base}/emu/app/sc0104/qrSuccess`, {
      method: "POST",
      body: { fullSn: "C21ZS00033", serial: "00033", model: "C21", year: "2025", sampleFlag: "S" },
      timeoutMs: 15000,
    });
    report.steps.qrSuccess = qrRes?.ok === true ? "ok" : qrRes;
    if (!qrRes?.ok) throw new Error("qrSuccess failed: " + JSON.stringify(qrRes));
    console.log("   ->", qrRes);

    // 2) BLE 스캔 화면으로 이동
    console.log("2) POST /emu/app/nav -> /sc/01/01/scan ...");
    const navRes = await requestJson(`${base}/emu/app/nav`, {
      method: "POST",
      body: { route: "/sc/01/01/scan", replaceStack: true },
      timeoutMs: 10000,
    });
    report.steps.nav = navRes?.ok === true ? "ok" : navRes;
    console.log("   ->", navRes);
    emuOk = true;
    await new Promise((r) => setTimeout(r, 1500));
  } catch (e) {
    report.steps.emuError = e?.message || String(e);
    console.warn("Emu not reachable (앱을 디버그 모드로 실행 후 adb forward tcp:18789 tcp:8788):", e?.message);
  }

  try {
    // 3) ADB 스크린샷 (에뮬 실패해도 현재 화면 캡처). exec-out 타임아웃 시 pull 방식 시도
    console.log("3) ADB screenshot ...");
    const deviceId = await pickDevice(a.device);
    ensureDir(QA_DIR);
    const ts = new Date().toISOString().replace(/[:.]/g, "-");
    const sharp = require("sharp");
    let png;
    try {
      png = await screenshotPng({ deviceId, timeoutMs: 20000 });
    } catch (err) {
      console.warn("exec-out timeout, trying pull method...");
      png = await screenshotPngViaPull({ deviceId });
    }
    const outPath = path.join(QA_DIR, `android_qa_qr_ble_${ts}.jpg`);
    await sharp(png).jpeg({ quality: 85 }).toFile(outPath);
    report.screenshot = outPath;
    report.steps.screenshot = "ok";
    console.log("   ->", outPath);
    report.ok = emuOk; // 전체 성공은 에뮬까지 성공했을 때만
  } catch (e) {
    report.error = e?.message || String(e);
    console.error("Screenshot error:", report.error);
  }

  ensureDir(QA_DIR);
  fs.writeFileSync(REPORT_JSON, JSON.stringify(report, null, 2), "utf8");
  console.log("Report:", REPORT_JSON);
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.ok ? 0 : 1);
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});
