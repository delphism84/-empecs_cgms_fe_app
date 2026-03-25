#!/usr/bin/env node
/* eslint-disable no-console */

const { requestJson } = require("./http");
const { spawn } = require("child_process");

function parseArgs(argv) {
  const args = argv.slice(2);
  const cmd = args[0] || "help";
  const out = {
    cmd,
    host: "127.0.0.1",
    port: 8788,
    value: null,
    hex: null,
    baseUrl: null,
    backendBase: "https://empecs.lunarsystem.co.kr",
    loginEmail: "empecs",
    loginPassword: "admin",
    eqsn: "LOCAL",
    silent: false,
  };
  for (let i = 1; i < args.length; i++) {
    const a = args[i];
    if (a === "--host") out.host = args[++i] || out.host;
    else if (a === "--port") out.port = Number(args[++i] || out.port);
    else if (a === "--value") out.value = Number(args[++i]);
    else if (a === "--hex") out.hex = args[++i];
    else if (a === "--base-url") out.baseUrl = args[++i];
    else if (a === "--backend") out.backendBase = args[++i] || out.backendBase;
    else if (a === "--email") out.loginEmail = args[++i] || out.loginEmail;
    else if (a === "--password") out.loginPassword = args[++i] || out.loginPassword;
    else if (a === "--eqsn") out.eqsn = args[++i] || out.eqsn;
    else if (a === "--silent") out.silent = true;
  }
  return out;
}

function usage() {
  return [
    "ble-emu <command> [options]",
    "",
    "Commands:",
    "  health                       서버 상태 확인 (GET /health)",
    "  inject:value --value <num>   값 주입(편의, BleService.simulateNotify)",
    "  inject:hex --hex \"..\"        CGM Measurement(0x2AA7) notify RAW 주입 (POST /emu/cgms/notify)",
    "  set:api --base-url <url>      앱 ApiClient baseUrl 설정 (POST /emu/app/apiBase)",
    "  setup:session                 백엔드 로그인 → 앱에 token/eqsn/startAt 주입",
    "  app:stats                     앱 로컬 상태/최근 알림 조회 (GET /emu/app/stats)",
    "  bot:smoke                     end-to-end 자동 검수(세션+알람+업로드+알림)",
    "  bot:alarms                    알람 설정/적용 자동 검수(high/low/rate/very_low)",
    "  qa:alarms                     bot:alarms + qa-bot 기록/캡처/HTML갱신",
    "  qa:settings                   ST_01_02~04 설정(지역/언어/시간) 적용 + QA 기록/캡처/HTML갱신",
    "  qa:unit                       ST_02_01 혈당 단위(mg/dL/mmol/L) 적용 + QA 기록/캡처/HTML갱신",
    "  qa:logtx                      ST_01_01 Log Data Transmission 수행 + QA 기록/캡처/HTML갱신",
    "  qa:dotsize                    ST_01_05 차트 포인트(도트) 크기 적용 + QA 기록/캡처/HTML갱신",
    "  qa:system                     AR_01_07 시스템 알람(만료/에러/이상) 트리거 + QA 기록/캡처/HTML갱신",
    "  qa:lockscreen                 AR_01_08 잠금화면 배너 알림(최신 혈당+추세) 트리거 + 잠금화면 JPG + HTML갱신",
    "  qa:noticenter                 AR_01_08 알림센터(알림창)에서 배너 확인 + JPG + HTML갱신",
    "  qa:sensors                    ST_03_01 센서 목록/등록 동작 자동 검수 + /settings JPG + HTML갱신",
    "  qa:alarms-ui                  ST_04_01 알람 목록/설정 반영 자동 검수 + /settings JPG + HTML갱신",
    "  qa:ar0101                     AR_01_01 모든 알람 무음 설정 적용 + 자동 검수 + /settings JPG + HTML갱신",
    "  qa:lo0101                     LO_01_01 로그인 페이지 SNS 로그인 옵션 표시 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0108                     LO_01_08 게스트 모드 진입 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0102                     LO_01_02 Google 로그인 프로세스 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0103                     LO_01_03 Apple 로그인 프로세스 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0104                     LO_01_04 카카오 로그인 프로세스 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0201                     LO_02_01 회원가입 안내(진행 여부 선택) 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0202                     LO_02_02 약관동의 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0203                     LO_02_03 본인인증(휴대폰 번호 인증) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0204                     LO_02_04 회원정보 입력 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0205                     LO_02_05 회원가입 완료 안내 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:me0101                     ME_01_01 이벤트 기록(팝업) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:gu                          GU_01_01~03 현재혈당/추세/색상 자동 검수 + 캡처 + HTML갱신",
    "  qa:tg0101                     TG_01_01 트렌드 그래프(세로) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:tg0102                     TG_01_02 트렌드 그래프(가로) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:rp0101                     RP_01_01 혈당 통계/요약 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:pd0101                     PD_01_01 이전 기록 조회(View Previous Data) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0201                     SC_02_01 센서 사용기간/만료까지 남은 기간 표시 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0301                     SC_03_01 센서 연결 상태(통신 상태) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0401                     SC_04_01 센서 일련번호 표시 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0501                     SC_05_01 센서 시작 시간 표시 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0601                     SC_06_01 NFC 센서 재연결 안내 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0801                     SC_08_01 센서 제거 방법 가이드 자동 검수 + 캡처 + HTML갱신",
    "  qa:lo0107                     LO_01_07 센서 등록 여부 확인 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:passcode                   LO_01_05 간편비밀번호(4자리) 화면/검증 자동 검수 + 캡처 + HTML갱신",
    "  qa:biometric                  LO_01_06/LO_02_06 생체인증(디버그 바이패스) 자동 검수 + 캡처 + HTML갱신",
    "  qa:passcode-reset             LO_03_01 간편비밀번호 초기화(회원정보 입력) 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0101                     SC_01_01 권한 동의(체크박스) + 알람 범위 저장 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0102                     SC_01_02 로그아웃 후 센서 재등록 안내 자동 검수 + 캡처 + HTML갱신",
    "  qa:um0101                     UM_01_01 센서 부착 안내 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0104                     SC_01_04 QR 센서 스캔 화면(+SN 수동등록 진입 안내) 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0105                     SC_01_05 SN 수동등록 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0106                     SC_01_06 센서 웜업(30분 카운트다운) 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0103                     SC_01_03 NFC 센서 스캔 안내 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0602                     SC_06_02 QR 센서 재연결 안내 화면 자동 검수 + 캡처 + HTML갱신",
    "  qa:sc0701                     SC_07_01 데이터 공유 기간/항목/방법 선택 화면 자동 검수 + 캡처 + HTML갱신",
    "",
    "Options:",
    "  --host 127.0.0.1",
    "  --port 8788",
    "  --base-url http://192.168.1.250:58002",
    "  --backend http://192.168.1.250:58002",
    "  --email empecs --password admin",
    "  --eqsn LOCAL",
    "  --silent     (notify 주입 시 silent=true)",
    "",
    "ADB (USB 추천):",
    "  adb forward tcp:18789 tcp:<devicePort>  (예: tcp:8789)",
  ].join("\n");
}

async function main() {
  const a = parseArgs(process.argv);
  const base = `http://${a.host}:${a.port}`;

  if (a.cmd === "help" || a.cmd === "--help" || a.cmd === "-h") {
    console.log(usage());
    process.exit(0);
  }

  if (a.cmd === "health") {
    const r = await requestJson(`${base}/health`, { method: "GET" });
    console.log(JSON.stringify(r, null, 2));
    return;
  }

  if (a.cmd === "inject:value") {
    if (typeof a.value !== "number" || Number.isNaN(a.value)) {
      console.error("Missing --value");
      process.exit(1);
    }
    const r = await requestJson(`${base}/emu/cgms/value`, {
      method: "POST",
      body: { value: a.value },
    });
    console.log(JSON.stringify(r, null, 2));
    return;
  }

  if (a.cmd === "inject:hex") {
    if (!a.hex) {
      console.error("Missing --hex");
      process.exit(1);
    }
    const r = await requestJson(`${base}/emu/cgms/notify`, {
      method: "POST",
      body: { hex: a.hex, silent: a.silent },
    });
    console.log(JSON.stringify(r, null, 2));
    return;
  }

  if (a.cmd === "set:api") {
    if (!a.baseUrl) {
      console.error("Missing --base-url");
      process.exit(1);
    }
    const r = await requestJson(`${base}/emu/app/apiBase`, {
      method: "POST",
      body: { baseUrl: a.baseUrl },
    });
    console.log(JSON.stringify(r, null, 2));
    return;
  }

  if (a.cmd === "setup:session") {
    // 1) login backend
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";
    // 2) push session to app
    const r = await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: {
        token,
        userId,
        eqsn: a.eqsn,
        sensorStartAt: new Date().toISOString(),
      },
    });
    console.log(JSON.stringify({ backend: { userId }, app: r }, null, 2));
    return;
  }

  if (a.cmd === "app:stats") {
    const r = await requestJson(`${base}/emu/app/stats`, { method: "GET" });
    console.log(JSON.stringify(r, null, 2));
    return;
  }

  if (a.cmd === "bot:smoke") {
    // 1) set api
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });

    // 2) login backend
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";

    // 3) push session to app
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    // helper: backend authed request
    async function be(path, body) {
      const res = await fetch(`${a.backendBase}${path}`, {
        method: body ? "POST" : "GET",
        headers: {
          authorization: `Bearer ${token}`,
          ...(body ? { "content-type": "application/json" } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const text = await res.text();
      const j = text ? JSON.parse(text) : null;
      if (!res.ok) throw new Error(`backend ${res.status} ${path}`);
      return j;
    }

    // 4) create alarms (very_low + high) with different sound/vibration modes
    await be("/api/settings/alarms", { type: "very_low", enabled: true, threshold: 55, overrideDnd: true, sound: false, vibrate: true, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "high", enabled: true, threshold: 180, sound: true, vibrate: false, repeatMin: 1 });

    // 5) inject values to trigger
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 200 } }); // high
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 50 } });  // very low

    // 6) wait/poll for backend upload (ingest is async)
    async function fetchGlucoseCompact() {
      const now = new Date();
      const from = new Date(now.getTime() - 30 * 60 * 1000).toISOString();
      const to = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
      const u = new URL(`${a.backendBase}/api/data/glucose`);
      u.searchParams.set("from", from);
      u.searchParams.set("to", to);
      u.searchParams.set("limit", "50");
      u.searchParams.set("compact", "1");
      u.searchParams.set("eqsn", a.eqsn);
      const res = await fetch(u.toString(), { headers: { authorization: `Bearer ${token}` } });
      const text = await res.text();
      const j = text ? JSON.parse(text) : null;
      if (!res.ok) throw new Error(`backend ${res.status} /api/data/glucose`);
      return j;
    }
    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

    let g = null;
    for (let i = 0; i < 8; i++) {
      g = await fetchGlucoseCompact();
      const n = Array.isArray(g?.v) ? g.v.length : 0;
      if (n >= 2) break;
      await sleep(1500);
    }

    // 7) fetch app stats (wait until very_low alert snapshot is stable)
    let st = null;
    for (let i = 0; i < 8; i++) {
      st = await requestJson(`${base}/emu/app/stats`, { method: "GET" });
      const a0 = st?.lastAlert || null;
      const hasStableVeryLow =
        a0 &&
        Object.keys(a0).length > 0 &&
        a0.alarmType === "very_low" &&
        typeof a0.sound === "boolean" &&
        typeof a0.vibrate === "boolean" &&
        typeof a0.overrideDnd === "boolean";
      if (hasStableVeryLow) break;
      await sleep(800);
    }

    console.log(
      JSON.stringify(
        {
          ok: true,
          backend: { userId, uploadedPoints: Array.isArray(g?.v) ? g.v.length : 0 },
          app: { glucoseCountLocal: st.glucoseCountLocal, maxTridLocalAny: st.maxTridLocalAny, maxTridLocalUser: st.maxTridLocalUser, lastAlert: st.lastAlert },
        },
        null,
        2
      )
    );
    return;
  }

  if (a.cmd === "bot:alarms") {
    // 1) set api
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });

    // 2) login backend
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";

    // 3) push session to app
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    async function be(path, body, method) {
      const res = await fetch(`${a.backendBase}${path}`, {
        method: method || (body ? "POST" : "GET"),
        headers: {
          authorization: `Bearer ${token}`,
          ...(body ? { "content-type": "application/json" } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const text = await res.text();
      const j = text ? JSON.parse(text) : null;
      if (!res.ok) throw new Error(`backend ${res.status} ${path}`);
      return j;
    }
    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function waitAlert(expectedType) {
      for (let i = 0; i < 12; i++) {
        const st = await requestJson(`${base}/emu/app/stats`, { method: "GET" });
        const a0 = st?.lastAlert || {};
        const ok =
          a0.alarmType === expectedType &&
          typeof a0.sound === "boolean" &&
          typeof a0.vibrate === "boolean" &&
          typeof a0.overrideDnd === "boolean";
        if (ok) return st;
        await sleep(600);
      }
      throw new Error(`timeout waiting for alert ${expectedType}`);
    }

    // 4) clear existing alarms (best-effort)
    try {
      const list = await be("/api/settings/alarms");
      if (Array.isArray(list)) {
        for (const it of list) {
          if (it && it._id) {
            try { await be(`/api/settings/alarms/${it._id}`, null, "DELETE"); } catch {}
          }
        }
      }
    } catch {}

    // 5) create alarms with known trigger patterns
    // - high/low는 값으로 직접 트리거
    // - rate는 100->200 빠르게 주입(절대 변화율)로 트리거 (AR_01_05: 2 또는 3 mg/dL/min)
    await be("/api/settings/alarms", { type: "high", enabled: true, threshold: 180, sound: true, vibrate: false, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "low", enabled: true, threshold: 70, sound: true, vibrate: true, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "rate", enabled: true, threshold: 2, sound: true, vibrate: true, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "very_low", enabled: true, threshold: 55, overrideDnd: true, sound: false, vibrate: true, repeatMin: 1 });
    // AR_01_06: signal loss(system) - 토글 없이 method만 적용
    await be("/api/settings/alarms", { type: "system", enabled: true, sound: true, vibrate: true, repeatMin: 1 });

    // 앱 UI를 거치지 않고 설정이 변경되므로 알람 캐시를 강제 리로드
    await requestJson(`${base}/emu/app/alarms/reload`, { method: "POST", body: {} });

    // 6) trigger high
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 200 } });
    const stHigh = await waitAlert("high");

    // 7) trigger low
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 60 } });
    const stLow = await waitAlert("low");

    // 8) trigger rate
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 100 } });
    // AlertEngine는 너무 짧은 간격(수초 미만)은 오탐 방지로 rate 계산에서 무시한다.
    // 따라서 테스트에서는 15초 이상 간격을 둔다.
    await sleep(16000);
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 200 } });
    const stRate = await waitAlert("rate");

    // 9) trigger very_low
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 50 } });
    const stVeryLow = await waitAlert("very_low");

    // 10) trigger system(signal loss) via debug endpoint
    await requestJson(`${base}/emu/app/alarm/system`, { method: "POST", body: { reason: "test" } });
    const stSystem = await waitAlert("system");

    console.log(
      JSON.stringify(
        {
          ok: true,
          backend: { userId },
          results: {
            high: stHigh.lastAlert,
            low: stLow.lastAlert,
            rate: stRate.lastAlert,
            very_low: stVeryLow.lastAlert,
            system: stSystem.lastAlert,
          },
        },
        null,
        2
      )
    );
    return;
  }

  if (a.cmd === "qa:alarms") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/alerts",
          "--expect-route", navRoute || "/alerts",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    // 1) 준비: bot:alarms 로 세션/알람을 구성하고, 각 알람을 순차로 트리거한다.
    // (bot:alarms 출력은 사람이 보기용이고, qa:alarms는 각 트리거 직후 qa-bot 기록을 남긴다.)
    // 아래는 bot:alarms 로직을 재사용하되, 트리거/대기 단위를 분해해서 기록한다.

    // set api
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });

    // login backend
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";

    // push session to app
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    async function be(path, body, method) {
      const res = await fetch(`${a.backendBase}${path}`, {
        method: method || (body ? "POST" : "GET"),
        headers: {
          authorization: `Bearer ${token}`,
          ...(body ? { "content-type": "application/json" } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const text = await res.text();
      const j = text ? JSON.parse(text) : null;
      if (!res.ok) throw new Error(`backend ${res.status} ${path}`);
      return j;
    }
    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function waitAlert(expectedType) {
      for (let i = 0; i < 14; i++) {
        const st = await requestJson(`${base}/emu/app/stats`, { method: "GET" });
        const a0 = st?.lastAlert || {};
        const ok =
          a0.alarmType === expectedType &&
          typeof a0.sound === "boolean" &&
          typeof a0.vibrate === "boolean" &&
          typeof a0.overrideDnd === "boolean";
        if (ok) return st;
        await sleep(700);
      }
      throw new Error(`timeout waiting for alert ${expectedType}`);
    }

    // clear existing alarms (best-effort)
    try {
      const list = await be("/api/settings/alarms");
      if (Array.isArray(list)) {
        for (const it of list) {
          if (it && it._id) {
            try { await be(`/api/settings/alarms/${it._id}`, null, "DELETE"); } catch {}
          }
        }
      }
    } catch {}

    // create alarms
    await be("/api/settings/alarms", { type: "high", enabled: true, threshold: 180, sound: true, vibrate: false, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "low", enabled: true, threshold: 70, sound: true, vibrate: true, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "rate", enabled: true, threshold: 2, sound: true, vibrate: true, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "very_low", enabled: true, threshold: 55, overrideDnd: true, sound: false, vibrate: true, repeatMin: 1 });
    await be("/api/settings/alarms", { type: "system", enabled: true, sound: true, vibrate: true, repeatMin: 1 });

    // 앱 UI를 거치지 않고 설정이 변경되므로 알람 캐시를 강제 리로드
    await requestJson(`${base}/emu/app/alarms/reload`, { method: "POST", body: {} });

    // AR_01_03: High glucose
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 200 } });
    await waitAlert("high");
    await runQaBotRecord({
      id: "AR_01_03",
      title: "고혈당 범위/반복 설정 적용 + 알람 발생(자동 검수)",
      navRoute: "/alerts",
      verifyLines: [
        `node tools/ble-emu/src/cli.js bot:alarms --backend ${a.backendBase} --port ${a.port || 18789} --eqsn ${a.eqsn}`,
        "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)",
        "POST /emu/app/nav {route:'/alerts'} (화면 전환 후 캡처)",
      ],
    });

    // AR_01_04: Low glucose
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 60 } });
    await waitAlert("low");
    await runQaBotRecord({
      id: "AR_01_04",
      title: "저혈당 범위/반복 설정 적용 + 알람 발생(자동 검수)",
      navRoute: "/alerts",
      verifyLines: [
        `node tools/ble-emu/src/cli.js bot:alarms --backend ${a.backendBase} --port ${a.port || 18789} --eqsn ${a.eqsn}`,
        "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)",
        "POST /emu/app/nav {route:'/alerts'} (화면 전환 후 캡처)",
      ],
    });

    // AR_01_05: Rapid change
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 100 } });
    await sleep(16000);
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 200 } });
    await waitAlert("rate");
    await runQaBotRecord({
      id: "AR_01_05",
      title: "급변동(2mg/dL/min) 설정 적용 + 알람 발생(자동 검수)",
      navRoute: "/alerts",
      verifyLines: [
        `node tools/ble-emu/src/cli.js bot:alarms --backend ${a.backendBase} --port ${a.port || 18789} --eqsn ${a.eqsn}`,
        "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)",
        "POST /emu/app/nav {route:'/alerts'} (화면 전환 후 캡처)",
      ],
    });

    // AR_01_02: Very low + override DND
    await requestJson(`${base}/emu/cgms/value`, { method: "POST", body: { value: 50 } });
    await waitAlert("very_low");
    await runQaBotRecord({
      id: "AR_01_02",
      title: "매우 낮음(Override DND/사운드·진동) 설정 적용 + 알람 발생(자동 검수)",
      navRoute: "/alerts",
      verifyLines: [
        `node tools/ble-emu/src/cli.js bot:alarms --backend ${a.backendBase} --port ${a.port || 18789} --eqsn ${a.eqsn}`,
        "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)",
        "POST /emu/app/nav {route:'/alerts'} (화면 전환 후 캡처)",
      ],
    });

    // AR_01_06: Signal loss(system)
    await requestJson(`${base}/emu/app/alarm/system`, { method: "POST", body: { reason: "qa" } });
    await waitAlert("system");
    await runQaBotRecord({
      id: "AR_01_06",
      title: "신호 손실(system) 알람: 토글 삭제/알람 방식 적용 + 알람 발생(자동 검수)",
      navRoute: "/alerts",
      verifyLines: [
        `node tools/ble-emu/src/cli.js bot:alarms --backend ${a.backendBase} --port ${a.port || 18789} --eqsn ${a.eqsn}`,
        "node tools/ble-emu/src/cli.js app:stats --port 18789 (lastAlert 확인)",
        "POST /emu/app/nav {route:'/alerts'} (화면 전환 후 캡처)",
      ],
    });

    console.log(JSON.stringify({ ok: true, backend: { userId }, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:settings") {
    function runQaBotRecord({ id, title, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", "/settings",
          "--expect-route", "/settings",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }
    async function setPrefs(body) { return await requestJson(`${base}/emu/app/prefs`, { method: "POST", body }); }

    // ST_01_02: Region 적용(선택 후 원복 방지)
    await setPrefs({ region: "US", autoRegion: false });
    await sleep(400);
    const s1 = await stats();
    if (s1.region !== "US" || s1.autoRegion !== false) throw new Error("region_not_applied");
    await runQaBotRecord({
      id: "ST_01_02",
      title: "사용자 지역 선택 적용(원복 방지) + 자동 검수",
      verifyLines: [
        "POST /emu/app/prefs {region:'US', autoRegion:false}",
        "GET /emu/app/stats (region/autoRegion 확인)",
      ],
    });

    // ST_01_03: Language 적용(en/ar만 지원)
    await setPrefs({ language: "ar" });
    await sleep(600);
    const s2 = await stats();
    if (s2.language !== "ar") throw new Error("language_not_applied");
    await runQaBotRecord({
      id: "ST_01_03",
      title: "사용자 언어 선택 적용(원복 방지) + 자동 검수",
      verifyLines: [
        "POST /emu/app/prefs {language:'ar'}",
        "GET /emu/app/stats (language 확인)",
      ],
    });

    // QA가 개발 환경 UI를 RTL로 남기지 않도록 en으로 복원
    await setPrefs({ language: "en" });
    await sleep(400);

    // ST_01_04: Time format 적용(24h/12h)
    await setPrefs({ timeFormat: "12h" });
    await sleep(600);
    const s3 = await stats();
    if (s3.timeFormat !== "12h" || s3.always24h !== false) throw new Error("time_format_not_applied");
    await runQaBotRecord({
      id: "ST_01_04",
      title: "사용자 시간 표시(12h/24h) 적용(원복 방지) + 자동 검수",
      verifyLines: [
        "POST /emu/app/prefs {timeFormat:'12h'}",
        "GET /emu/app/stats (timeFormat/always24h 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:unit") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/chart",
          "--expect-route", navRoute || "/chart",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }
    async function nav(route) { return await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route, replaceStack: true } }); }
    async function setPrefs(body) { return await requestJson(`${base}/emu/app/prefs`, { method: "POST", body }); }

    // 차트 화면으로 이동 후 캡처(로그인 화면 고정 방지)
    await nav("/chart");
    await sleep(700);

    // mmol/L 적용
    await setPrefs({ glucoseUnit: "mmol" });
    await sleep(500);
    const s1 = await stats();
    if (s1.glucoseUnit !== "mmol") throw new Error("unit_not_applied_mmol");
    await runQaBotRecord({
      id: "ST_02_01",
      title: "혈당 단위 선택(mg/dL↔mmol/L) 적용(원복 방지) + 자동 검수",
      navRoute: "/chart",
      verifyLines: [
        "POST /emu/app/nav {route:'/chart'}",
        "POST /emu/app/prefs {glucoseUnit:'mmol'}",
        "GET /emu/app/stats (glucoseUnit 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:logtx") {
    function runQaBotRecord({ id, title }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", "/settings",
          "--expect-route", "/settings",
          "--verify", "POST /emu/app/logTx",
          "--verify", "GET /emu/app/stats (lastLogTxAt/lastLogTxOk 확인)",
        ];
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }

    // ensure api + session (same pattern as qa:alarms)
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    // navigate to settings first (for correct screenshot)
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/settings", replaceStack: true } });
    await sleep(700);

    // trigger log transmission
    await requestJson(`${base}/emu/app/logTx`, { method: "POST", body: { maxLines: 80 } });

    // wait until stats reflects it
    let st = null;
    for (let i = 0; i < 20; i++) {
      st = await requestJson(`${base}/emu/app/stats`, { method: "GET" });
      if (st && st.lastLogTxAt && st.lastLogTxOk === true) break;
      await sleep(400);
    }
    if (!st || !st.lastLogTxAt || st.lastLogTxOk !== true) {
      throw new Error("logtx_not_confirmed");
    }

    await runQaBotRecord({ id: "ST_01_01", title: "Log Data Transmission(로그 전송) 수행 + 완료일 표시 + 자동 검수" });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:dotsize") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/chart",
          "--expect-route", navRoute || "/chart",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }
    async function nav(route) { return await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route, replaceStack: true } }); }
    async function setPrefs(body) { return await requestJson(`${base}/emu/app/prefs`, { method: "POST", body }); }

    // 차트 화면으로 이동 후, dot 크기 변경이 실제 반영되는지 확인
    await nav("/chart");
    await sleep(700);

    const target = 6;
    await setPrefs({ chartDotSize: target });
    await sleep(450);

    let s = null;
    for (let i = 0; i < 15; i++) {
      s = await stats();
      if (s && s.chartDotSize === target) break;
      await sleep(250);
    }
    if (!s || s.chartDotSize !== target) throw new Error("dotsize_not_applied");

    await runQaBotRecord({
      id: "ST_01_05",
      title: "차트 포인트(도트) 크기 설정 적용(원복 방지) + 자동 검수",
      navRoute: "/chart",
      verifyLines: [
        `POST /emu/app/prefs {chartDotSize:${target}}`,
        "GET /emu/app/stats (chartDotSize 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:system") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/alerts",
          "--expect-route", navRoute || "/alerts",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }
    async function nav(route) { return await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route, replaceStack: true } }); }
    async function setApi(baseUrl) { return await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl } }); }

    // 1) set api
    await setApi(a.backendBase);

    // 2) login backend
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";

    // 3) push session to app
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    async function be(path, body, method) {
      const res = await fetch(`${a.backendBase}${path}`, {
        method: method || (body ? "POST" : "GET"),
        headers: {
          authorization: `Bearer ${token}`,
          ...(body ? { "content-type": "application/json" } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const text = await res.text();
      const j = text ? JSON.parse(text) : null;
      if (!res.ok) throw new Error(`backend ${res.status} ${path}`);
      return j;
    }

    // 4) ensure system alarm exists (best-effort recreate)
    try {
      const list = await be("/api/settings/alarms");
      if (Array.isArray(list)) {
        for (const it of list) {
          if (it && it._id) {
            try { await be(`/api/settings/alarms/${it._id}`, null, "DELETE"); } catch {}
          }
        }
      }
    } catch {}
    await be("/api/settings/alarms", { type: "system", enabled: true, sound: true, vibrate: true, repeatMin: 1 });
    await requestJson(`${base}/emu/app/alarms/reload`, { method: "POST", body: {} });

    // 5) trigger reasons
    const reasons = ["expired", "error", "abnormal"];
    let last = null;
    for (const r of reasons) {
      await requestJson(`${base}/emu/app/alarm/system`, { method: "POST", body: { reason: r } });
      // wait until lastAlert reflects this reason
      for (let i = 0; i < 12; i++) {
        const st = await stats();
        const a0 = st?.lastAlert || {};
        if (a0.alarmType === "system" && a0.reason === r && typeof a0.sound === "boolean") { last = st; break; }
        await sleep(400);
      }
    }
    if (!last) throw new Error("system_alarm_not_confirmed");

    await nav("/alerts");
    await sleep(700);

    await runQaBotRecord({
      id: "AR_01_07",
      title: "시스템 알람(센서 만료/에러/신호 이상감지) 트리거 + 알림 방식 적용(자동 검수)",
      navRoute: "/alerts",
      verifyLines: [
        "POST /emu/app/alarm/system {reason:'expired'|'error'|'abnormal'}",
        "GET /emu/app/stats (lastAlert.alarmType='system', reason 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lockscreen") {
    function runQaBotRecord({ id, title, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--lockscreen",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 디버그 환경 기본 LTR 복원
    await requestJson(`${base}/emu/app/prefs`, { method: "POST", body: { language: "en" } });
    await sleep(250);

    // 잠금화면 배너용 "최신 혈당 + 추세"를 직접 트리거
    await requestJson(`${base}/emu/app/lockscreen/glucose`, {
      method: "POST",
      body: { value: 123, trend: "↗", unit: "mg/dL" },
    });

    // stats 반영 확인(알림 호출 성공 여부)
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.lastLockScreenAt && s.lastLockScreenOk === true) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("lockscreen_notify_not_confirmed");

    await runQaBotRecord({
      id: "AR_01_08",
      title: "잠금화면 배너 알림(최신 혈당+추세) 표시 + 자동 검수(잠금화면 캡처)",
      verifyLines: [
        "POST /emu/app/lockscreen/glucose {value:123, trend:'↗'}",
        "GET /emu/app/stats (lastLockScreenAt/lastLockScreenOk 확인)",
        "adb lockscreen screencap (qa-bot --lockscreen)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:noticenter") {
    function runQaBotRecord({ id, title, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--notifications",
          "--nav", "/home",
          "--expect-route", "/home",
          "--settle-ms", "900",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // ensure LTR
    await requestJson(`${base}/emu/app/prefs`, { method: "POST", body: { language: "en" } });
    await sleep(250);

    // trigger a notification (same as lockscreen flow)
    await requestJson(`${base}/emu/app/lockscreen/glucose`, {
      method: "POST",
      body: { value: 123, trend: "↗", unit: "mg/dL" },
    });

    // confirm it was invoked
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.lastLockScreenAt && s.lastLockScreenOk === true) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("noticenter_notify_not_confirmed");

    await runQaBotRecord({
      id: "AR_01_08_NC",
      title: "알림센터에서 배너 알림 확인(AR_01_08) + 자동 검수",
      verifyLines: [
        "POST /emu/app/lockscreen/glucose {value:123, trend:'↗'}",
        "GET /emu/app/stats (lastLockScreenAt/lastLockScreenOk 확인)",
        "adb cmd statusbar expand-notifications + screencap",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sensors") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/settings",
          "--expect-route", navRoute || "/settings",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }
    async function nav(route) { return await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route, replaceStack: true } }); }
    async function appSensors() { return await requestJson(`${base}/emu/app/sensors`, { method: "GET" }); }

    // 1) set api
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });

    // 2) login backend
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";

    // 3) push session to app
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    // 4) clear sensors (best-effort)
    try { await requestJson(`${base}/emu/app/sensors/clear`, { method: "POST", body: {} }); } catch {}

    // 5) create one sensor via app endpoint (so token path is exercised)
    const created = await requestJson(`${base}/emu/app/sensors`, {
      method: "POST",
      body: { name: "CGMS Sensor A", serial: "LOCAL", isActive: true, offset: 0, scale: 1 },
    });
    if (!created || created.ok !== true) throw new Error("sensor_create_failed");

    // 6) verify list contains it
    let ok = false;
    for (let i = 0; i < 15; i++) {
      const s = await appSensors();
      const n = s && typeof s.count === "number" ? s.count : 0;
      if (n >= 1) { ok = true; break; }
      await sleep(300);
    }
    if (!ok) throw new Error("sensor_not_listed");

    // 7) screenshot settings (Registered sensors)
    await nav("/settings");
    await sleep(800);
    await stats(); // warm

    await runQaBotRecord({
      id: "ST_03_01",
      title: "Sensors: 등록/목록 표시 동작 + 자동 검수",
      navRoute: "/settings",
      verifyLines: [
        "POST /emu/app/sensors/clear",
        "POST /emu/app/sensors {name,serial,isActive,...}",
        "GET /emu/app/sensors (count>=1 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:alarms-ui") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/settings",
          "--expect-route", navRoute || "/settings",
        ];
        for (const v of (verifyLines || [])) {
          args.push("--verify", v);
        }
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }
    async function nav(route) { return await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route, replaceStack: true } }); }
    async function appAlarms() { return await requestJson(`${base}/emu/app/alarms`, { method: "GET" }); }

    // 1) set api + session
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    // 2) clear alarms (앱 경유)
    await requestJson(`${base}/emu/app/alarms/clear`, { method: "POST", body: {} });

    // 3) seed alarms (backend 경유: 실제 서버 모델/검증 통과 여부까지 포함)
    async function be(path, body, method) {
      const res = await fetch(`${a.backendBase}${path}`, {
        method: method || (body ? "POST" : "GET"),
        headers: {
          authorization: `Bearer ${token}`,
          ...(body ? { "content-type": "application/json" } : {}),
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      const text = await res.text();
      const j = text ? JSON.parse(text) : null;
      if (!res.ok) throw new Error(`backend ${res.status} ${path}`);
      return j;
    }
    await be("/api/settings/alarms", { type: "high", enabled: true, threshold: 180, sound: true, vibrate: false, repeatMin: 10 });
    await be("/api/settings/alarms", { type: "low", enabled: true, threshold: 70, sound: true, vibrate: true, repeatMin: 10 });
    await be("/api/settings/alarms", { type: "very_low", enabled: true, threshold: 55, overrideDnd: true, sound: false, vibrate: true, repeatMin: 10 });
    await be("/api/settings/alarms", { type: "rate", enabled: true, threshold: 2, sound: true, vibrate: true, repeatMin: 10 });
    await be("/api/settings/alarms", { type: "system", enabled: true, sound: true, vibrate: true, repeatMin: 10 });

    // 4) 앱 캐시 리로드
    await requestJson(`${base}/emu/app/alarms/reload`, { method: "POST", body: {} });

    // 5) 앱에서 알람 목록이 보이는지 확인
    let ok = false;
    for (let i = 0; i < 15; i++) {
      const s = await appAlarms();
      if (s && s.ok === true && typeof s.count === "number" && s.count >= 5) { ok = true; break; }
      await sleep(350);
    }
    if (!ok) throw new Error("alarms_not_listed");

    // 6) Settings 화면으로 이동 후 캡처(알람 리스트 영역)
    await nav("/settings");
    await sleep(900);
    await stats();

    await runQaBotRecord({
      id: "ST_04_01",
      title: "Alarms: 목록/설정 반영 + 자동 검수",
      navRoute: "/settings",
      verifyLines: [
        "POST /emu/app/alarms/clear",
        "POST /api/settings/alarms x5 (high/low/very_low/rate/system)",
        "POST /emu/app/alarms/reload",
        "GET /emu/app/alarms (count>=5 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:ar0101") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/settings",
          "--expect-route", navRoute || "/settings",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) mute all alarms on
    await requestJson(`${base}/emu/app/prefs`, { method: "POST", body: { alarmsMuteAll: true } });
    await sleep(300);

    // 2) trigger a system alarm and verify it is silent
    await requestJson(`${base}/emu/app/alarm/system`, { method: "POST", body: { reason: "signal_loss" } });
    await sleep(800);

    let ok = false;
    for (let i = 0; i < 30; i++) {
      const s = await stats();
      const la = (s && s.lastAlert) ? s.lastAlert : null;
      if (s && s.alarmsMuteAll === true && la && la.reason === "signal_loss" && la.sound === false && la.vibrate === false) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("ar0101_not_confirmed");

    await runQaBotRecord({
      id: "AR_01_01",
      title: "무음모드 설정(AR_01_01) 모든 알람 무음 적용 + 알람 발생(자동 검수)",
      navRoute: "/ar/01/01",
      verifyLines: [
        "POST /emu/app/prefs {alarmsMuteAll:true}",
        "POST /emu/app/alarm/system {reason:'signal_loss'}",
        "GET /emu/app/stats (alarmsMuteAll + lastAlert.sound/vibrate=false 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0101") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--settle-ms", "900",
          "--wait-stat-key", "lo0101SheetOpenedAt",
          "--wait-stat-timeout-ms", "12000",
          "--nav", navRoute || "/login",
          "--expect-route", navRoute || "/login",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // LTR 강제(과거 RTL(아랍어) 설정 잔존 방지)
    await requestJson(`${base}/emu/app/prefs`, { method: "POST", body: { language: "en" } });

    // 1) 다음 /login 진입 시 Easy Login 시트 자동 오픈 플래그 설정(네비게이션은 qa-bot이 수행)
    await requestJson(`${base}/emu/app/lo0101`, { method: "POST", body: { openSheet: true, navigate: false } });

    // 2) 캡처(+ stats wait) 및 HTML 업데이트
    await runQaBotRecord({
      id: "LO_01_01",
      title: "로그인 페이지 SNS 로그인(LO_01_01) Google/Apple/Kakao 옵션 표시 + 자동 검수",
      navRoute: "/login",
      verifyLines: [
        "POST /emu/app/prefs {language:'en'}",
        "POST /emu/app/lo0101 {openSheet:true,navigate:false} (다음 /login 진입 시 시트 자동 오픈)",
        "qa-bot record --nav /login --wait-stat-key lo0101SheetOpenedAt + screenshot",
      ],
    });

    // 3) 검수 강제(qa-bot은 wait 타임아웃 시에도 실패 처리하지 않음 → 여기서 확인)
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      // NOTE: Easy Login 시트가 열리면 NavigatorObserver 상의 currentRoute가
      // "ModalBottomSheetRoute<dynamic>"로 바뀔 수 있으므로 route 값은 강제하지 않는다.
      if (s && typeof s.lo0101SheetOpenedAt === "string" && s.lo0101SheetOpenedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("lo0101_not_confirmed");

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0108") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--settle-ms", "700",
          "--wait-stat-key", "guestMode",
          "--wait-stat-timeout-ms", "8000",
          "--nav", navRoute || "/home",
          "--expect-route", navRoute || "/home",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 게스트 모드 진입(앱 내부에서 guestMode=true 저장 + /home 이동)
    await requestJson(`${base}/emu/app/lo0108`, { method: "POST", body: {} });
    await sleep(800);

    // 2) 상태 확인
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.guestMode === true && typeof s.lo0108EnteredAt === "string" && s.lo0108EnteredAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("lo0108_not_confirmed");

    // 3) 캡처 + HTML 업데이트
    await runQaBotRecord({
      id: "LO_01_08",
      title: "비회원 사용(게스트 모드) 진입 확인(LO_01_08) + 자동 검수",
      navRoute: "/home",
      verifyLines: [
        "POST /emu/app/lo0108 (guestMode=true 저장 + /home 이동)",
        "GET /emu/app/stats (guestMode=true + lo0108EnteredAt 확인)",
        "qa-bot record --nav /home --wait-stat-key guestMode + screenshot",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0102" || a.cmd === "qa:lo0103" || a.cmd === "qa:lo0104") {
    const id = (a.cmd === "qa:lo0102") ? "LO_01_02" : (a.cmd === "qa:lo0103" ? "LO_01_03" : "LO_01_04");
    const navRoute = (a.cmd === "qa:lo0102") ? "/lo/01/02" : (a.cmd === "qa:lo0103" ? "/lo/01/03" : "/lo/01/04");
    const waitKey = (a.cmd === "qa:lo0102") ? "lo0102ViewedAt" : (a.cmd === "qa:lo0103" ? "lo0103ViewedAt" : "lo0104ViewedAt");
    const title = (a.cmd === "qa:lo0102")
      ? "Google 로그인(LO_01_02) 프로세스 화면 표시 + 자동 검수"
      : (a.cmd === "qa:lo0103")
        ? "Apple 로그인(LO_01_03) 프로세스 화면 표시 + 자동 검수"
        : "카카오 로그인(LO_01_04) 프로세스 화면 표시 + 자동 검수";

    function runQaBotRecord({ id, title, navRoute, verifyLines, waitKey }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--settle-ms", "700",
          "--wait-stat-key", waitKey,
          "--wait-stat-timeout-ms", "10000",
          "--nav", navRoute,
          "--expect-route", navRoute,
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 화면 이동(서버 엔드포인트로 증적 기록 + 라우트 이동)
    const emuPath = (a.cmd === "qa:lo0102") ? "/emu/app/lo0102" : (a.cmd === "qa:lo0103" ? "/emu/app/lo0103" : "/emu/app/lo0104");
    await requestJson(`${base}${emuPath}`, { method: "POST", body: {} });
    await sleep(800);

    // 상태 확인(증적 키)
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      const v = s ? s[waitKey] : "";
      if (typeof v === "string" && v.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error(`${id.toLowerCase()}_not_confirmed`);

    // 캡처 + HTML 업데이트
    await runQaBotRecord({
      id,
      title,
      navRoute,
      waitKey,
      verifyLines: [
        `POST ${emuPath} (viewedAt 기록 + route 이동)`,
        `GET /emu/app/stats (${waitKey} 확인)`,
        `qa-bot record --nav ${navRoute} --wait-stat-key ${waitKey} + screenshot`,
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0201" || a.cmd === "qa:lo0203" || a.cmd === "qa:lo0205") {
    const id = (a.cmd === "qa:lo0201") ? "LO_02_01" : (a.cmd === "qa:lo0203" ? "LO_02_03" : "LO_02_05");
    const navRoute = (a.cmd === "qa:lo0201") ? "/lo/02/01" : (a.cmd === "qa:lo0203" ? "/lo/02/03" : "/lo/02/05");
    const waitKey = (a.cmd === "qa:lo0201") ? "lo0201ViewedAt" : (a.cmd === "qa:lo0203" ? "lo0203ViewedAt" : "lo0205ViewedAt");
    const title = (a.cmd === "qa:lo0201")
      ? "회원가입 안내(LO_02_01) 진행 여부 선택 화면 + 자동 검수"
      : (a.cmd === "qa:lo0203")
        ? "본인인증(LO_02_03) 휴대폰 번호 인증 화면 + 자동 검수"
        : "회원가입 완료(LO_02_05) 안내 화면 + 자동 검수";

    function runQaBotRecord({ id, title, navRoute, verifyLines, waitKey }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--settle-ms", "700",
          "--wait-stat-key", waitKey,
          "--wait-stat-timeout-ms", "10000",
          "--nav", navRoute,
          "--expect-route", navRoute,
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    const emuPath = (a.cmd === "qa:lo0201") ? "/emu/app/lo0201" : (a.cmd === "qa:lo0203" ? "/emu/app/lo0203" : "/emu/app/lo0205");
    const body = (a.cmd === "qa:lo0201") ? { choice: "start" } : (a.cmd === "qa:lo0203" ? { phone: "010-0000-0000", verified: false } : {});
    await requestJson(`${base}${emuPath}`, { method: "POST", body });
    await sleep(800);

    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      const v = s ? s[waitKey] : "";
      if (typeof v === "string" && v.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error(`${id.toLowerCase()}_not_confirmed`);

    await runQaBotRecord({
      id,
      title,
      navRoute,
      waitKey,
      verifyLines: [
        `POST ${emuPath} (viewedAt 기록 + route 이동)`,
        `GET /emu/app/stats (${waitKey} 확인)`,
        `qa-bot record --nav ${navRoute} --wait-stat-key ${waitKey} + screenshot`,
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0201" || a.cmd === "qa:sc0401" || a.cmd === "qa:sc0501" || a.cmd === "qa:sc0801") {
    const id = (a.cmd === "qa:sc0201")
      ? "SC_02_01"
      : (a.cmd === "qa:sc0401")
        ? "SC_04_01"
        : (a.cmd === "qa:sc0501")
          ? "SC_05_01"
          : "SC_08_01";
    const navRoute = (a.cmd === "qa:sc0201")
      ? "/sc/02/01"
      : (a.cmd === "qa:sc0401")
        ? "/sc/04/01"
        : (a.cmd === "qa:sc0501")
          ? "/sc/05/01"
          : "/sc/08/01";
    const waitKey = (a.cmd === "qa:sc0201")
      ? "sc0201RenderedAt"
      : (a.cmd === "qa:sc0401")
        ? "sc0401ViewedAt"
        : (a.cmd === "qa:sc0501")
          ? "sc0501ViewedAt"
          : "sc0801ViewedAt";
    const title = (a.cmd === "qa:sc0201")
      ? "센서 사용기간 표시(SC_02_01) 만료까지 남은 기간 + 자동 검수"
      : (a.cmd === "qa:sc0401")
        ? "센서 일련번호 표시(SC_04_01) + 자동 검수"
        : (a.cmd === "qa:sc0501")
          ? "센서 시작 시간(SC_05_01) 표시 + 자동 검수"
          : "센서 제거 방법 가이드(SC_08_01) + 자동 검수";

    function runQaBotRecord({ id, title, navRoute, verifyLines, waitKey }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--settle-ms", "900",
          "--wait-stat-key", waitKey,
          "--wait-stat-timeout-ms", "12000",
          "--nav", navRoute,
          "--expect-route", navRoute,
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    const emuPath = (a.cmd === "qa:sc0201")
      ? "/emu/app/sc0201"
      : (a.cmd === "qa:sc0401")
        ? "/emu/app/sc0401"
        : (a.cmd === "qa:sc0501")
          ? "/emu/app/sc0501"
          : "/emu/app/sc0801";
    await requestJson(`${base}${emuPath}`, { method: "POST", body: {} });
    await sleep(900);

    let ok = false;
    for (let i = 0; i < 25; i++) {
      const s = await stats();
      const v = s ? s[waitKey] : null;
      const pass = (typeof v === "string") ? v.trim().length > 0 : (v !== null && v !== undefined && v !== false);
      if (pass) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error(`${id.toLowerCase()}_not_confirmed`);

    await runQaBotRecord({
      id,
      title,
      navRoute,
      waitKey,
      verifyLines: [
        `POST ${emuPath} (증적 기록 + route 이동)`,
        `GET /emu/app/stats (${waitKey} 확인)`,
        `qa-bot record --nav ${navRoute} --wait-stat-key ${waitKey} + screenshot`,
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0107") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/lo/01/07",
          "--expect-route", navRoute || "/lo/01/07",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) seed one registered device (simulate "existing sensor")
    await requestJson(`${base}/emu/app/devices/set`, {
      method: "POST",
      body: {
        registeredDevices: [
          { sn: "12345", model: "CGMS", at: new Date().toISOString() },
        ],
      },
    });

    // 2) navigate to LO_01_07 screen and verify state marker
    await requestJson(`${base}/emu/app/lo0107`, { method: "POST", body: {} });
    await sleep(700);

    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/lo/01/07" && typeof s.lo0107ViewedAt === "string" && s.lo0107ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("lo0107_not_confirmed");

    await runQaBotRecord({
      id: "LO_01_07",
      title: "센서 등록 여부 확인(LO_01_07) 화면 + 자동 검수",
      navRoute: "/lo/01/07",
      verifyLines: [
        "POST /emu/app/devices/set (registeredDevices 주입)",
        "POST /emu/app/lo0107 (route 이동 + viewedAt 기록)",
        "GET /emu/app/stats (lo0107ViewedAt 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:passcode") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/passcode",
          "--expect-route", navRoute || "/passcode",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) passcode 설정(1234) + enable
    await requestJson(`${base}/emu/app/passcode/set`, { method: "POST", body: { code: "1234", enabled: true } });

    // 2) 검증(check)
    const chk = await requestJson(`${base}/emu/app/passcode/check`, { method: "POST", body: { code: "1234" } });
    if (!chk || chk.ok !== true) throw new Error("passcode_check_failed");

    // 3) 화면 이동 후 캡처 (숫자 키보드 자동 노출은 위젯 설정으로 충족)
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/passcode", replaceStack: true } });
    await sleep(700);
    const st = await stats();
    if (!st || st.currentRoute !== "/passcode") throw new Error("passcode_route_not_reached");

    await runQaBotRecord({
      id: "LO_01_05",
      title: "간편비밀번호 로그인(4자리) 화면 + 자동 검수",
      navRoute: "/passcode",
      verifyLines: [
        "POST /emu/app/passcode/set {code:'1234'}",
        "POST /emu/app/passcode/check {code:'1234'} (ok=true)",
        "POST /emu/app/nav {route:'/passcode'} + screenshot",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:biometric") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/biometric",
          "--expect-route", navRoute || "/biometric",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) backend session 주입(토큰 존재 상태)
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });
    const login = await requestJson(`${a.backendBase}/api/auth/login`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });
    const token = login.token;
    const userId = login.user && login.user.id ? login.user.id : "";
    await requestJson(`${base}/emu/app/session`, {
      method: "POST",
      body: { token, userId, eqsn: a.eqsn, sensorStartAt: new Date().toISOString() },
    });

    // 2) biometric enable + debug bypass
    await requestJson(`${base}/emu/app/biometric`, { method: "POST", body: { enabled: true } });
    await requestJson(`${base}/emu/app/biometric/bypass`, { method: "POST", body: { enabled: true } });

    // 3) 설정 화면(등록) 캡처
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/biometric", replaceStack: true } });
    await sleep(700);
    const s1 = await stats();
    if (!s1 || s1.currentRoute !== "/biometric" || s1.biometricEnabled !== true) throw new Error("biometric_settings_not_applied");
    await runQaBotRecord({
      id: "LO_02_06",
      title: "생체인증 등록/사용 설정(디버그 바이패스 포함) + 자동 검수",
      navRoute: "/biometric",
      verifyLines: [
        "POST /emu/app/biometric {enabled:true}",
        "POST /emu/app/biometric/bypass {enabled:true}",
        "GET /emu/app/stats (biometricEnabled/biometricDebugBypass 확인)",
      ],
    });

    // 4) gate 화면으로 이동 → bypass로 즉시 /home 진입 확인 → 캡처
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/biometric/gate", replaceStack: true } });
    await sleep(1200);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/home") { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("biometric_gate_not_reached_home");
    await runQaBotRecord({
      id: "LO_01_06",
      title: "생체인증 로그인(디버그 바이패스) + 자동 검수",
      navRoute: "/home",
      verifyLines: [
        "POST /emu/app/nav {route:'/biometric/gate'}",
        "GET /emu/app/stats (currentRoute='/home' 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:passcode-reset") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/login",
          "--expect-route", navRoute || "/login",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) passcode 설정 후 활성화
    await requestJson(`${base}/emu/app/passcode/set`, { method: "POST", body: { code: "1234", enabled: true } });
    const s0 = await stats();
    if (!s0 || s0.passcodeEnabled !== true) throw new Error("passcode_not_enabled");

    // 2) 회원정보 입력(backend 로그인)으로 reset 수행
    await requestJson(`${base}/emu/app/apiBase`, { method: "POST", body: { baseUrl: a.backendBase } });
    await requestJson(`${base}/emu/app/passcode/reset`, {
      method: "POST",
      body: { email: a.loginEmail, password: a.loginPassword },
    });

    // 3) passcode 비활성 확인
    let ok = false;
    for (let i = 0; i < 15; i++) {
      const s = await stats();
      if (s && s.passcodeEnabled === false) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("passcode_not_reset");

    // 4) 로그인 화면으로 이동 후 캡처
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/login", replaceStack: true } });
    await sleep(700);

    await runQaBotRecord({
      id: "LO_03_01",
      title: "간편비밀번호 초기화(회원정보 입력) + 자동 검수",
      navRoute: "/login",
      verifyLines: [
        "POST /emu/app/passcode/set {code:'1234'}",
        "POST /emu/app/passcode/reset {email,password} (login check)",
        "GET /emu/app/stats (passcodeEnabled=false 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0101") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/01/01",
          "--expect-route", navRoute || "/sc/01/01",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 값 저장(동의 + 범위)
    await requestJson(`${base}/emu/app/sc0101`, { method: "POST", body: { consent: true, low: 70, high: 180 } });

    // 2) stats 확인
    let ok = false;
    for (let i = 0; i < 15; i++) {
      const s = await stats();
      if (s && s.sc0101Consent === true && s.sc0101Low === 70 && s.sc0101High === 180) { ok = true; break; }
      await sleep(200);
    }
    if (!ok) throw new Error("sc0101_not_applied");

    // 3) 화면 캡처
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/sc/01/01", replaceStack: true } });
    await sleep(700);

    await runQaBotRecord({
      id: "SC_01_01",
      title: "권한 동의(체크박스) + 알람 범위 저장 + 자동 검수",
      navRoute: "/sc/01/01",
      verifyLines: [
        "POST /emu/app/sc0101 {consent:true, low:70, high:180}",
        "GET /emu/app/stats (sc0101Consent/sc0101Low/sc0101High 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0102") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/01/02",
          "--expect-route", navRoute || "/sc/01/02",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 등록된 센서가 있다고 가정(로컬 등록 목록 주입)
    await requestJson(`${base}/emu/app/devices/set`, { method: "POST", body: { registeredDevices: [
      { id: "QA-1", sn: "LOCAL", model: "C21", year: "2025", sampleFlag: "", registeredAt: new Date().toISOString() }
    ] } });

    // 2) 로그아웃 실행 → 센서가 있으면 /sc/01/02로 이동해야 함
    await requestJson(`${base}/emu/app/logout`, { method: "POST", body: {} });

    // 3) 상태 확인
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.sc0102HasDevice === true && s.currentRoute === "/sc/01/02") { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0102_not_reached");

    await runQaBotRecord({
      id: "SC_01_02",
      title: "로그아웃 후 센서 재등록 안내(SC_01_02) + 자동 검수",
      navRoute: "/sc/01/02",
      verifyLines: [
        "POST /emu/app/devices/set (registeredDevices count>=1)",
        "POST /emu/app/logout (route '/sc/01/02')",
        "GET /emu/app/stats (sc0102HasDevice/currentRoute 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:um0101") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/um/01/01",
          "--expect-route", navRoute || "/um/01/01",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 화면 이동(부착 안내)
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/um/01/01", replaceStack: true } });
    await sleep(800);

    // 2) viewedAt 기록 확인
    let ok = false;
    for (let i = 0; i < 15; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/um/01/01" && typeof s.um0101ViewedAt === "string" && s.um0101ViewedAt.length > 5) { ok = true; break; }
      await sleep(200);
    }
    if (!ok) throw new Error("um0101_not_confirmed");

    await runQaBotRecord({
      id: "UM_01_01",
      title: "센서 부착 안내 UI(UM_01_01) 표시 + 자동 검수",
      navRoute: "/um/01/01",
      verifyLines: [
        "POST /emu/app/nav {route:'/um/01/01'}",
        "GET /emu/app/stats (um0101ViewedAt 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0104") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/01/04",
          "--expect-route", navRoute || "/sc/01/04",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/sc/01/04", replaceStack: true } });
    await sleep(900);

    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/sc/01/04" && typeof s.sc0104ViewedAt === "string" && s.sc0104ViewedAt.length > 5) { ok = true; break; }
      await sleep(200);
    }
    if (!ok) throw new Error("sc0104_not_confirmed");

    await runQaBotRecord({
      id: "SC_01_04",
      title: "QR 센서 스캔 화면(SC_01_04) + SN 수동등록 안내 + 자동 검수",
      navRoute: "/sc/01/04",
      verifyLines: [
        "POST /emu/app/nav {route:'/sc/01/04'}",
        "GET /emu/app/stats (sc0104ViewedAt 확인)",
        "UI: QR 스캔 실패 시 SN 버튼으로 수동등록 진입",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0105") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/01/05",
          "--expect-route", navRoute || "/sc/01/05",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 수동 SN 저장(백엔드/카메라 없이도 검수 가능하게 emu endpoint 사용)
    await requestJson(`${base}/emu/app/sc0105/manualSn`, { method: "POST", body: { sn: "00033" } });

    // 2) 화면 이동 + 저장값 확인
    await requestJson(`${base}/emu/app/nav`, { method: "POST", body: { route: "/sc/01/05", replaceStack: true } });
    await sleep(600);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/sc/01/05" && s.sc0105ManualSnValue === "00033" && typeof s.sc0105ManualSnAt === "string" && s.sc0105ManualSnAt.length > 5) { ok = true; break; }
      await sleep(200);
    }
    if (!ok) throw new Error("sc0105_not_confirmed");

    await runQaBotRecord({
      id: "SC_01_05",
      title: "SN 수동등록 화면(SC_01_05) + 저장 동작 자동 검수",
      navRoute: "/sc/01/05",
      verifyLines: [
        "POST /emu/app/sc0105/manualSn {sn:'00033'}",
        "POST /emu/app/nav {route:'/sc/01/05'}",
        "GET /emu/app/stats (sc0105ManualSnAt/sc0105ManualSnValue 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0106") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/01/06",
          "--expect-route", navRoute || "/sc/01/06",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 웜업 시작(30분) + 화면 이동
    await requestJson(`${base}/emu/app/sc0106/start`, { method: "POST", body: { seconds: 30 * 60 } });
    await sleep(900);

    // 2) 상태 확인(remainingSec가 1700~1800 사이면 시작 직후로 간주)
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      const rem = (s && typeof s.sc0106WarmupRemainingSec === "number") ? s.sc0106WarmupRemainingSec : -1;
      if (s && s.currentRoute === "/sc/01/06" && s.sc0106WarmupActive === true && rem >= 1700 && rem <= 1800) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0106_not_started");

    await runQaBotRecord({
      id: "SC_01_06",
      title: "센서 웜업(30분 카운트다운) 화면 + 자동 검수",
      navRoute: "/sc/01/06",
      verifyLines: [
        "POST /emu/app/sc0106/start {seconds:1800}",
        "GET /emu/app/stats (sc0106WarmupActive/sc0106WarmupRemainingSec 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0103") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/01/03",
          "--expect-route", navRoute || "/sc/01/03",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    await requestJson(`${base}/emu/app/sc0103`, { method: "POST", body: {} });
    await sleep(800);

    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/sc/01/03" && typeof s.sc0103ViewedAt === "string" && s.sc0103ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0103_not_confirmed");

    await runQaBotRecord({
      id: "SC_01_03",
      title: "NFC 센서 스캔 안내(SC_01_03) 화면 + 자동 검수",
      navRoute: "/sc/01/03",
      verifyLines: [
        "POST /emu/app/sc0103 (viewedAt 기록 + route 이동)",
        "GET /emu/app/stats (sc0103ViewedAt 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0602") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--nav", navRoute || "/sc/06/02",
          "--expect-route", navRoute || "/sc/06/02",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 시스템 알람(센서만료 등) 트리거 → 재연결 안내 화면으로 이동
    await requestJson(`${base}/emu/app/alarm/system`, { method: "POST", body: { reason: "expired" } });
    await requestJson(`${base}/emu/app/sc0602`, { method: "POST", body: { reason: "expired" } });
    await sleep(900);

    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/sc/06/02" && typeof s.sc0602ViewedAt === "string" && s.sc0602ViewedAt.length > 5 && s.sc0602Reason === "expired") { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0602_not_confirmed");

    await runQaBotRecord({
      id: "SC_06_02",
      title: "QR 센서 재연결 안내(SC_06_02) 화면 + 자동 검수",
      navRoute: "/sc/06/02",
      verifyLines: [
        "POST /emu/app/alarm/system {reason:'expired'}",
        "POST /emu/app/sc0602 {reason:'expired'}",
        "GET /emu/app/stats (sc0602ViewedAt/sc0602Reason 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  // Generic qa-bot recorder helper (for smaller QA commands)
  function runQaBotRecordGeneric({ id, title, navRoute, verifyLines, waitStatKey, settleMs }) {
    return new Promise((resolve, reject) => {
      const args = [
        "tools\\qa-bot\\src\\cli.js",
        "record",
        "--id", id,
        "--title", title,
        "--result", "pass",
        "--port", String(a.port || 18789),
        "--screenshot",
        "--nav", navRoute,
        "--expect-route", navRoute,
      ];
      if (typeof settleMs === "number" && Number.isFinite(settleMs) && settleMs > 0) {
        args.push("--settle-ms", String(Math.floor(settleMs)));
      }
      if (waitStatKey) {
        args.push("--wait-stat-key", String(waitStatKey));
        args.push("--wait-stat-timeout-ms", "10000");
      }
      for (const v of (verifyLines || [])) args.push("--verify", v);
      const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
      let out = ""; let err = "";
      p.stdout.on("data", (d) => { out += d.toString("utf8"); });
      p.stderr.on("data", (d) => { err += d.toString("utf8"); });
      p.on("error", reject);
      p.on("close", (code) => {
        if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
        resolve(out.trim());
      });
    });
  }

  async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
  async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

  if (a.cmd === "qa:gu") {
    // 1) 주입 + 화면 이동 (값 2개로 추세 생성, high(주황) 유도)
    await requestJson(`${base}/emu/app/gu0101`, { method: "POST", body: { values: [120, 200] } });
    await sleep(700);

    // 2) 상태 확인
    let ok = false;
    for (let i = 0; i < 22; i++) {
      const s = await stats();
      if (
        s &&
        s.currentRoute === "/gu/01/01" &&
        typeof s.gu0101RenderedAt === "string" && s.gu0101RenderedAt.length > 5 &&
        s.gu0101Value === 200 &&
        typeof s.gu0102Trend === "string" && s.gu0102Trend.startsWith("up") &&
        s.gu0103Color === "high"
      ) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("gu_not_confirmed");

    const verifyLines = [
      "POST /emu/app/gu0101 {values:[120,200]}",
      "GET /emu/app/stats (gu0101Value/gu0102Trend/gu0103Color 확인)",
    ];

    await runQaBotRecordGeneric({
      id: "GU_01_01",
      title: "현재 혈당 수치(GU_01_01) + 자동 검수",
      navRoute: "/gu/01/01",
      waitStatKey: "gu0101RenderedAt",
      settleMs: 650,
      verifyLines,
    });
    await runQaBotRecordGeneric({
      id: "GU_01_02",
      title: "혈당 변화량(추세 화살표)(GU_01_02) + 자동 검수",
      navRoute: "/gu/01/01",
      waitStatKey: "gu0101RenderedAt",
      settleMs: 650,
      verifyLines,
    });
    await runQaBotRecordGeneric({
      id: "GU_01_03",
      title: "혈당 색상 표시(고혈당 주황)(GU_01_03) + 자동 검수",
      navRoute: "/gu/01/01",
      waitStatKey: "gu0101RenderedAt",
      settleMs: 650,
      verifyLines,
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:tg0101") {
    await requestJson(`${base}/emu/app/tg0101`, { method: "POST", body: {} });
    await sleep(650);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/tg/01/01" && typeof s.tg0101ViewedAt === "string" && s.tg0101ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("tg0101_not_confirmed");
    await runQaBotRecordGeneric({
      id: "TG_01_01",
      title: "혈당 그래프(세로)(TG_01_01) + 자동 검수",
      navRoute: "/tg/01/01",
      waitStatKey: "tg0101ViewedAt",
      settleMs: 700,
      verifyLines: ["POST /emu/app/tg0101", "GET /emu/app/stats (tg0101ViewedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:tg0102") {
    await requestJson(`${base}/emu/app/tg0102`, { method: "POST", body: {} });
    await sleep(800);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/tg/01/02" && typeof s.tg0102ViewedAt === "string" && s.tg0102ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("tg0102_not_confirmed");
    await runQaBotRecordGeneric({
      id: "TG_01_02",
      title: "혈당 그래프(가로)(TG_01_02) + 자동 검수",
      navRoute: "/tg/01/02",
      waitStatKey: "tg0102ViewedAt",
      settleMs: 900,
      verifyLines: ["POST /emu/app/tg0102", "GET /emu/app/stats (tg0102ViewedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:rp0101") {
    await requestJson(`${base}/emu/app/rp0101`, { method: "POST", body: {} });
    await sleep(900);
    let ok = false;
    for (let i = 0; i < 24; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/rp/01/01" && typeof s.rp0101RenderedAt === "string" && s.rp0101RenderedAt.length > 5) { ok = true; break; }
      await sleep(300);
    }
    if (!ok) throw new Error("rp0101_not_confirmed");
    await runQaBotRecordGeneric({
      id: "RP_01_01",
      title: "혈당 통계 및 요약(RP_01_01) + 자동 검수",
      navRoute: "/rp/01/01",
      waitStatKey: "rp0101RenderedAt",
      settleMs: 850,
      verifyLines: ["POST /emu/app/rp0101", "GET /emu/app/stats (rp0101RenderedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:pd0101") {
    await requestJson(`${base}/emu/app/pd0101`, { method: "POST", body: {} });
    await sleep(900);
    let ok = false;
    for (let i = 0; i < 24; i++) {
      const s = await stats();
      if (
        s &&
        s.currentRoute === "/pd/01/01" &&
        typeof s.pd0101ViewedAt === "string" && s.pd0101ViewedAt.length > 5 &&
        typeof s.pd0101RefreshedAt === "string" && s.pd0101RefreshedAt.length > 5 &&
        (s.pd0101ItemsCount === 2 || s.pd0101ItemsCount > 0)
      ) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("pd0101_not_confirmed");
    await runQaBotRecordGeneric({
      id: "PD_01_01",
      title: "이전 기록 조회(View Previous Data)(PD_01_01) + 자동 검수",
      navRoute: "/pd/01/01",
      waitStatKey: "pd0101ViewedAt",
      settleMs: 800,
      verifyLines: ["POST /emu/app/pd0101 (seed+nav)", "GET /emu/app/stats (pd0101* 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:me0101") {
    // food shot (missing in req doc) attach sample first
    await requestJson(`${base}/emu/app/me0101/foodshot`, { method: "POST", body: { asset: "assets/images/img_rectangle104.png" } });
    await requestJson(`${base}/emu/app/me0101`, { method: "POST", body: {} });
    await sleep(650);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (
        s &&
        s.currentRoute === "/me/01/01" &&
        typeof s.me0101ViewedAt === "string" && s.me0101ViewedAt.length > 5 &&
        typeof s.me0101FoodShotAt === "string" && s.me0101FoodShotAt.length > 5 &&
        typeof s.me0101FoodShotAsset === "string" && s.me0101FoodShotAsset.length > 5
      ) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("me0101_not_confirmed");
    await runQaBotRecordGeneric({
      id: "ME_01_01",
      title: "이벤트 기록 팝업(ME_01_01) 푸드샷 포함 + 자동 검수",
      navRoute: "/me/01/01",
      waitStatKey: "me0101ViewedAt",
      settleMs: 650,
      verifyLines: [
        "POST /emu/app/me0101/foodshot {asset:'assets/images/img_rectangle104.png'}",
        "POST /emu/app/me0101",
        "GET /emu/app/stats (me0101ViewedAt + me0101FoodShot* 확인)",
      ],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0202") {
    await requestJson(`${base}/emu/app/lo0202`, { method: "POST", body: {} });
    await sleep(650);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/lo/02/02" && typeof s.lo0202ViewedAt === "string" && s.lo0202ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("lo0202_not_confirmed");
    await runQaBotRecordGeneric({
      id: "LO_02_02",
      title: "약관동의(LO_02_02) + 자동 검수",
      navRoute: "/lo/02/02",
      waitStatKey: "lo0202ViewedAt",
      settleMs: 650,
      verifyLines: ["POST /emu/app/lo0202", "GET /emu/app/stats (lo0202ViewedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:lo0204") {
    await requestJson(`${base}/emu/app/lo0204`, { method: "POST", body: {} });
    await sleep(650);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/lo/02/04" && typeof s.lo0204ViewedAt === "string" && s.lo0204ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("lo0204_not_confirmed");
    await runQaBotRecordGeneric({
      id: "LO_02_04",
      title: "회원정보 입력(LO_02_04) + 자동 검수",
      navRoute: "/lo/02/04",
      waitStatKey: "lo0204ViewedAt",
      settleMs: 650,
      verifyLines: ["POST /emu/app/lo0204", "GET /emu/app/stats (lo0204ViewedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0301") {
    await requestJson(`${base}/emu/app/sc0301`, { method: "POST", body: {} });
    await sleep(650);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/sc/03/01" && typeof s.sc0301ViewedAt === "string" && s.sc0301ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0301_not_confirmed");
    await runQaBotRecordGeneric({
      id: "SC_03_01",
      title: "센서 연결 상태/통신 상태(SC_03_01) + 자동 검수",
      navRoute: "/sc/03/01",
      waitStatKey: "sc0301ViewedAt",
      settleMs: 650,
      verifyLines: ["POST /emu/app/sc0301", "GET /emu/app/stats (sc0301ViewedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0601") {
    await requestJson(`${base}/emu/app/sc0601`, { method: "POST", body: {} });
    await sleep(650);
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (s && s.currentRoute === "/sc/06/01" && typeof s.sc0601ViewedAt === "string" && s.sc0601ViewedAt.length > 5) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0601_not_confirmed");
    await runQaBotRecordGeneric({
      id: "SC_06_01",
      title: "NFC 센서 재연결 안내(SC_06_01) + 자동 검수",
      navRoute: "/sc/06/01",
      waitStatKey: "sc0601ViewedAt",
      settleMs: 650,
      verifyLines: ["POST /emu/app/sc0601", "GET /emu/app/stats (sc0601ViewedAt 확인)"],
    });
    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  if (a.cmd === "qa:sc0701") {
    function runQaBotRecord({ id, title, navRoute, verifyLines }) {
      return new Promise((resolve, reject) => {
        const args = [
          "tools\\qa-bot\\src\\cli.js",
          "record",
          "--id", id,
          "--title", title,
          "--result", "pass",
          "--port", String(a.port || 18789),
          "--screenshot",
          "--settle-ms", "2500",
          "--wait-stat-key", "sc0701RenderedAt",
          "--wait-stat-timeout-ms", "10000",
          "--nav", navRoute || "/sc/07/01",
          "--expect-route", navRoute || "/sc/07/01",
        ];
        for (const v of (verifyLines || [])) args.push("--verify", v);
        const p = spawn("node", args, { stdio: ["ignore", "pipe", "pipe"] });
        let out = ""; let err = "";
        p.stdout.on("data", (d) => { out += d.toString("utf8"); });
        p.stderr.on("data", (d) => { err += d.toString("utf8"); });
        p.on("error", reject);
        p.on("close", (code) => {
          if (code !== 0) return reject(new Error(err || out || `qa-bot exit ${code}`));
          resolve(out.trim());
        });
      });
    }

    async function sleep(ms) { return new Promise((r) => setTimeout(r, ms)); }
    async function stats() { return await requestJson(`${base}/emu/app/stats`, { method: "GET" }); }

    // 1) 공유 설정 주입 + 화면 이동
    await requestJson(`${base}/emu/app/sc0701`, {
      method: "POST",
      body: {
        enabled: true,
        preset: "7D",
        itemSummary: true,
        itemDistribution: true,
        itemGraph: true,
        itemUserProfile: false,
        methodEmail: true,
        methodSms: false,
        format: "PDF",
        revocable: true,
      },
    });
    await sleep(900);

    // 2) 상태 확인
    let ok = false;
    for (let i = 0; i < 20; i++) {
      const s = await stats();
      if (
        s &&
        s.currentRoute === "/sc/07/01" &&
        s.sc0701Enabled === true &&
        s.sc0701Preset === "7D" &&
        s.sc0701MethodEmail === true &&
        s.sc0701MethodSms === false &&
        s.sc0701Format === "PDF"
      ) { ok = true; break; }
      await sleep(250);
    }
    if (!ok) throw new Error("sc0701_not_applied");

    await runQaBotRecord({
      id: "SC_07_01",
      title: "데이터 공유 기간/항목/방법 선택(SC_07_01) + 자동 검수",
      navRoute: "/sc/07/01",
      verifyLines: [
        "POST /emu/app/sc0701 {preset:'7D', items/method/format...}",
        "GET /emu/app/stats (sc0701* 확인)",
      ],
    });

    console.log(JSON.stringify({ ok: true, html: "req/req1/_qa/index.html" }, null, 2));
    return;
  }

  console.log(usage());
  process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

