const { spawn } = require("child_process");

function runCapture(cmd, args, { timeoutMs = 15000 } = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    const chunks = [];
    const errs = [];
    const t = setTimeout(() => {
      try { p.kill("SIGKILL"); } catch {}
      reject(new Error(`timeout: ${cmd} ${args.join(" ")}`));
    }, timeoutMs);
    p.stdout.on("data", (d) => chunks.push(d));
    p.stderr.on("data", (d) => errs.push(d));
    p.on("error", (e) => {
      clearTimeout(t);
      reject(e);
    });
    p.on("close", (code) => {
      clearTimeout(t);
      const out = Buffer.concat(chunks);
      const err = Buffer.concat(errs).toString("utf8").trim();
      if (code !== 0) return reject(new Error(err || `exit ${code}`));
      resolve({ out, err });
    });
  });
}

async function listDevices() {
  // NOTE: 일부 무선 디버깅 디바이스 ID는 공백을 포함할 수 있어(`... (2)._adb-tls-connect._tcp`)
  // `adb devices -l`의 whitespace split 파싱이 깨진다.
  // 표준 출력(`adb devices`)은 "<serial>\t<state>" 포맷이므로 탭 기준으로 안전하게 파싱한다.
  const { out } = await runCapture("adb", ["devices"], { timeoutMs: 8000 });
  const lines = out.toString("utf8").split(/\r?\n/).map((s) => s.trimEnd()).filter(Boolean);
  const devices = [];
  for (const ln of lines) {
    if (ln.toLowerCase().startsWith("list of devices")) continue;
    // expect: "<serial>\t<state>"
    const parts = ln.split(/\t+/);
    const id = (parts[0] || "").trim();
    const state = (parts[1] || "").trim();
    if (!id || !state) continue;
    devices.push({ id, state, raw: ln });
  }
  return devices.filter((d) => d.state === "device");
}

async function pickDevice(preferredId) {
  if (preferredId) return preferredId;
  const list = await listDevices();
  if (!list.length) throw new Error("no_adb_device");
  return list[0].id;
}

async function screenshotPng({ deviceId, timeoutMs = 25000 }) {
  // stdout is PNG bytes (일부 기기에서 screencap 지연 가능)
  const { out } = await runCapture("adb", ["-s", deviceId, "exec-out", "screencap", "-p"], { timeoutMs });
  // 일부 환경에서는 stdout 앞부분에 경고 문자열이 섞여 나올 수 있어 PNG 시그니처부터 잘라낸다.
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const idx = out.indexOf(sig);
  if (idx > 0) return out.slice(idx);
  return out;
}

/** exec-out이 느린 기기용: 기기 내 파일로 저장 후 pull */
async function screenshotPngViaPull({ deviceId, timeoutMs = 45000 }) {
  const fs = require("fs");
  const path = require("path");
  const remotePath = "/sdcard/qa_screencap.png";
  await runCapture("adb", ["-s", deviceId, "shell", "screencap", "-p", remotePath], { timeoutMs });
  const tmp = path.join(require("os").tmpdir(), `qa_screen_${Date.now()}.png`);
  await runCapture("adb", ["-s", deviceId, "pull", remotePath, tmp], { timeoutMs: 15000 });
  const buf = fs.readFileSync(tmp);
  try { fs.unlinkSync(tmp); } catch (_) {}
  return buf;
}

async function keyevent({ deviceId, code }) {
  await runCapture("adb", ["-s", deviceId, "shell", "input", "keyevent", String(code)], { timeoutMs: 8000 });
  return true;
}

async function lockscreenScreenshotPng({ deviceId }) {
  // 1) 화면 끄기(잠금 유도) → 2) 화면 켜기(잠금화면 표시) → 3) 캡처
  // 일부 기기에서는 1회만 누르면 just 화면 off일 수 있으므로 2회 토글을 사용한다.
  try { await keyevent({ deviceId, code: 26 }); } catch (_) {}
  await new Promise((r) => setTimeout(r, 450));
  try { await keyevent({ deviceId, code: 26 }); } catch (_) {}
  await new Promise((r) => setTimeout(r, 1100));
  return await screenshotPng({ deviceId });
}

async function expandNotifications({ deviceId }) {
  // best-effort: modern command first
  try {
    await runCapture("adb", ["-s", deviceId, "shell", "cmd", "statusbar", "expand-notifications"], { timeoutMs: 8000 });
    return true;
  } catch (_) {}
  // fallback: legacy service call (may vary by Android)
  try {
    await runCapture("adb", ["-s", deviceId, "shell", "service", "call", "statusbar", "1"], { timeoutMs: 8000 });
    return true;
  } catch (_) {}
  return false;
}

async function collapseStatusBar({ deviceId }) {
  try {
    await runCapture("adb", ["-s", deviceId, "shell", "cmd", "statusbar", "collapse"], { timeoutMs: 8000 });
    return true;
  } catch (_) {}
  // fallback: back key
  try {
    await keyevent({ deviceId, code: 4 });
    return true;
  } catch (_) {}
  return false;
}

module.exports = { listDevices, pickDevice, screenshotPng, screenshotPngViaPull, keyevent, lockscreenScreenshotPng, expandNotifications, collapseStatusBar };

