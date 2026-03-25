#!/usr/bin/env node
/* eslint-disable no-console */

const path = require("path");
const sharp = require("sharp");

const { ensureDir, readJsonIfExists, writeJson, writeText } = require("./io");
const { requestJson } = require("./http");
const { pickDevice, screenshotPng, lockscreenScreenshotPng, expandNotifications, collapseStatusBar } = require("./adb");
const { renderHtml, makeRel } = require("./report");

const ROOT = path.resolve(__dirname, "..", "..", ".."); // empecs_cgms
const QA_DIR = path.join(ROOT, "req", "req1", "_qa");
const DB_PATH = path.join(QA_DIR, "qa-results.json");
const OUT_HTML = path.join(QA_DIR, "index.html");
const SHOT_DIR = path.join(QA_DIR, "screenshots");

function usage() {
  return [
    "qa-bot usage:",
    "  qa-bot record --id AR_01_02 --title \"...\" --result pass --verify \"cmd...\" [--port 18789] [--nav /settings] [--expect-route /settings] [--screenshot] [--settle-ms 450] [--wait-stat-key <key>] [--wait-stat-timeout-ms 5000] [--notifications] [--server-check] [--device <adbId>]",
    "  qa-bot seed:current --id AR_01_02 [--port 18789] [--nav /settings] [--expect-route /settings] [--screenshot] [--settle-ms 450] [--wait-stat-key <key>] [--wait-stat-timeout-ms 5000] [--device <adbId>]",
    "  qa-bot report",
  ].join("\n");
}

function parseArgs(argv) {
  const a = { _: [] };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x.startsWith("--")) {
      const k = x.slice(2);
      const v = (i + 1 < argv.length && !argv[i + 1].startsWith("--")) ? argv[++i] : true;
      if (a[k] === undefined) a[k] = v;
      else if (Array.isArray(a[k])) a[k].push(v);
      else a[k] = [a[k], v];
    } else {
      a._.push(x);
    }
  }
  a.cmd = a._[0] || "";
  return a;
}

function loadDb() {
  return readJsonIfExists(DB_PATH, { items: [] });
}

function upsertItem(db, item) {
  const idx = db.items.findIndex((x) => String(x.id) === String(item.id));
  if (idx >= 0) db.items[idx] = { ...db.items[idx], ...item };
  else db.items.push(item);
}

async function captureJpg({ deviceId, id }) {
  ensureDir(SHOT_DIR);
  const ts = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
  const base = `${id}_${ts}`;
  const abs = path.join(SHOT_DIR, `${base}.jpg`);

  const png = await screenshotPng({ deviceId });
  await sharp(png).jpeg({ quality: 85 }).toFile(abs);

  return abs;
}

async function captureLockscreenJpg({ deviceId, id }) {
  ensureDir(SHOT_DIR);
  const ts = new Date().toISOString().replaceAll(":", "-").replaceAll(".", "-");
  const base = `${id}_${ts}`;
  const abs = path.join(SHOT_DIR, `${base}.jpg`);

  const png = await lockscreenScreenshotPng({ deviceId });
  await sharp(png).jpeg({ quality: 85 }).toFile(abs);

  return abs;
}

async function navToRoute({ port, nav, expectRoute }) {
  if (!port || !nav) return { ok: false, skipped: true };
  const base = `http://127.0.0.1:${Number(port)}`;
  try {
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: nav, replaceStack: true } });
  } catch (_) {
    // ignore
  }
  if (!expectRoute) return { ok: true };
  for (let i = 0; i < 20; i++) {
    try {
      const s = await requestJson(`${base}/emu/app/nav`, { method: "GET" });
      if (s && s.route === expectRoute) return { ok: true, route: s.route };
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 250));
  }
  return { ok: false, error: "route_not_reached", expected: expectRoute };
}

async function readAppStats({ port }) {
  if (!port) return null;
  const url = `http://127.0.0.1:${Number(port)}/emu/app/stats`;
  try {
    return await requestJson(url, { method: "GET" });
  } catch (_) {
    return null;
  }
}

async function serverCheck({ port }) {
  if (!port) return { ok: false, skipped: true };
  const base = `http://127.0.0.1:${Number(port)}`;
  const out = { ok: true, checkedAt: new Date().toISOString(), checks: {} };

  async function one(name, fn) {
    try {
      const r = await fn();
      out.checks[name] = { ok: true, result: r };
      return true;
    } catch (e) {
      out.ok = false;
      out.checks[name] = { ok: false, error: String(e?.message || e), status: e?.status, body: e?.body };
      return false;
    }
  }

  // 1) health
  await one("health", async () => await requestJson(`${base}/health`, { method: "GET", timeoutMs: 5000 }));
  // 2) sensors list (server-backed)
  await one("sensors", async () => {
    const r = await requestJson(`${base}/emu/app/sensors`, { method: "GET", timeoutMs: 8000 });
    return { ok: !!r?.ok, count: r?.count ?? null };
  });
  // 3) alarms list (server-backed)
  await one("alarms", async () => {
    const r = await requestJson(`${base}/emu/app/alarms`, { method: "GET", timeoutMs: 8000 });
    return { ok: !!r?.ok, count: r?.count ?? null };
  });
  // 4) logTx upload (server-backed)
  await one("logTx", async () => {
    const r = await requestJson(`${base}/emu/app/logTx`, { method: "POST", timeoutMs: 12000, body: { maxLines: 40 } });
    return { ok: !!r?.ok, uploaded: r?.uploaded === true, at: r?.at ?? null };
  });

  return out;
}

async function cmdRecord(a) {
  const id = String(a.id || "").trim();
  if (!id) throw new Error("missing --id");

  const title = String(a.title || "").trim();
  const result = String(a.result || "").trim().toLowerCase(); // pass/fail/na
  const verify = a.verify;
  const steps = Array.isArray(verify) ? verify : (verify ? [String(verify)] : []);
  const port = a.port ? Number(a.port) : null;
  const nav = a.nav ? String(a.nav) : "/settings";
  const expectRoute = a["expect-route"] ? String(a["expect-route"]) : nav;
  const settleMsRaw = a["settle-ms"] !== undefined ? Number(a["settle-ms"]) : 450;
  const settleMs = Number.isFinite(settleMsRaw) ? Math.max(0, Math.min(5000, settleMsRaw)) : 450;
  const waitStatKey = a["wait-stat-key"] ? String(a["wait-stat-key"]).trim() : "";
  const waitTimeoutRaw = a["wait-stat-timeout-ms"] !== undefined ? Number(a["wait-stat-timeout-ms"]) : 5000;
  const waitTimeoutMs = Number.isFinite(waitTimeoutRaw) ? Math.max(0, Math.min(30000, waitTimeoutRaw)) : 5000;
  const doServerCheck = a["server-check"] === true;

  const db = loadDb();

  let deviceId = null;
  let shotAbs = null;
  if (a.screenshot) {
    deviceId = await pickDevice(a.device && String(a.device));
    if (a.lockscreen) {
      // 잠금화면 캡처는 앱 네비게이션과 무관
      shotAbs = await captureLockscreenJpg({ deviceId, id });
      a.__navRes = { ok: true, lockscreen: true };
    } else {
      const navRes = await navToRoute({ port, nav, expectRoute });
      // 화면 전환이 완료될 시간을 약간 준다(애니메이션/빌드)
      await new Promise((r) => setTimeout(r, settleMs));
      if (waitStatKey && port) {
        const t0 = Date.now();
        while (Date.now() - t0 < waitTimeoutMs) {
          const st = await readAppStats({ port });
          const v = st ? st[waitStatKey] : null;
          const ok = (typeof v === "string" ? v.trim().length > 0 : (v !== null && v !== undefined && v !== false));
          if (ok) break;
          await new Promise((r) => setTimeout(r, 250));
        }
      }
      // Notification center capture (shade expanded)
      if (a.notifications) {
        const ok = await expandNotifications({ deviceId });
        await new Promise((r) => setTimeout(r, 900));
        shotAbs = await captureJpg({ deviceId, id });
        await new Promise((r) => setTimeout(r, 350));
        await collapseStatusBar({ deviceId });
        a.__notifRes = { ok: !!ok };
      } else {
        shotAbs = await captureJpg({ deviceId, id });
      }
      // 증거로 남길 수 있도록 nav 결과를 보관
      a.__navRes = navRes;
    }
  }

  const appStats = await readAppStats({ port });
  const server = doServerCheck ? await serverCheck({ port }) : null;

  const item = {
    id,
    title,
    result: result || "na",
    verificationSteps: steps,
    verifiedAt: new Date().toISOString(),
    screenshot: shotAbs ? { absPath: shotAbs, relPath: makeRel(QA_DIR, shotAbs) } : null,
    evidence: {
      ...(appStats ? { appStats } : {}),
      ...(server ? { serverCheck: server } : {}),
      ...(a.__navRes ? { screenshotNav: a.__navRes } : {}),
      ...(a.__notifRes ? { notifications: a.__notifRes } : {}),
    },
  };

  upsertItem(db, item);
  writeJson(DB_PATH, db);
  await cmdReport();
  console.log(JSON.stringify({ ok: true, id, out: OUT_HTML }, null, 2));
}

async function cmdSeedCurrent(a) {
  const id = String(a.id || "").trim() || "AR_01_02";
  const port = a.port ? Number(a.port) : 18789;
  const nav = a.nav ? String(a.nav) : "/settings";
  const expectRoute = a["expect-route"] ? String(a["expect-route"]) : nav;
  const settleMsRaw = a["settle-ms"] !== undefined ? Number(a["settle-ms"]) : 450;
  const settleMs = Number.isFinite(settleMsRaw) ? Math.max(0, Math.min(5000, settleMsRaw)) : 450;
  const waitStatKey = a["wait-stat-key"] ? String(a["wait-stat-key"]).trim() : "";
  const waitTimeoutRaw = a["wait-stat-timeout-ms"] !== undefined ? Number(a["wait-stat-timeout-ms"]) : 5000;
  const waitTimeoutMs = Number.isFinite(waitTimeoutRaw) ? Math.max(0, Math.min(30000, waitTimeoutRaw)) : 5000;
  const db = loadDb();

  let deviceId = null;
  let shotAbs = null;
  if (a.screenshot) {
    deviceId = await pickDevice(a.device && String(a.device));
    const navRes = await navToRoute({ port, nav, expectRoute });
    await new Promise((r) => setTimeout(r, settleMs));
    if (waitStatKey && port) {
      const t0 = Date.now();
      while (Date.now() - t0 < waitTimeoutMs) {
        const st = await readAppStats({ port });
        const v = st ? st[waitStatKey] : null;
        const ok = (typeof v === "string" ? v.trim().length > 0 : (v !== null && v !== undefined && v !== false));
        if (ok) break;
        await new Promise((r) => setTimeout(r, 250));
      }
    }
    shotAbs = await captureJpg({ deviceId, id });
    a.__navRes = navRes;
  }
  const appStats = await readAppStats({ port });

  upsertItem(db, {
    id,
    title: "매우 낮음 알람(방해금지 무시/사운드·진동 모드) + 자동 검수",
    result: "pass",
    verificationSteps: [
      "node tools/ble-emu/src/cli.js bot:smoke --backend http://<BE>:58002 --port 18789 --eqsn LOCAL",
      "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)",
    ],
    verifiedAt: new Date().toISOString(),
    screenshot: shotAbs ? { absPath: shotAbs, relPath: makeRel(QA_DIR, shotAbs) } : null,
    evidence: { ...(appStats ? { appStats } : {}), ...(a.__navRes ? { screenshotNav: a.__navRes } : {}) },
  });

  writeJson(DB_PATH, db);
  await cmdReport();
  console.log(JSON.stringify({ ok: true, seeded: id, out: OUT_HTML }, null, 2));
}

async function cmdReport() {
  const db = loadDb();
  ensureDir(QA_DIR);
  const html = renderHtml({
    title: "CGMS req1 QA 리포트 (검수 완료 항목)",
    items: db.items || [],
  });
  writeText(OUT_HTML, html);
  return OUT_HTML;
}

async function main() {
  const a = parseArgs(process.argv);
  if (!a.cmd || a.cmd === "help" || a.cmd === "-h" || a.cmd === "--help") {
    console.log(usage());
    process.exit(0);
  }
  if (a.cmd === "report") return await cmdReport();
  if (a.cmd === "seed:current") return await cmdSeedCurrent(a);
  if (a.cmd === "record") return await cmdRecord(a);
  console.log(usage());
  process.exit(1);
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

