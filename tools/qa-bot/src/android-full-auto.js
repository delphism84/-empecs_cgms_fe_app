#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..", "..");
const { requestJson } = require("./http");
const { pickDevice, screenshotPng, screenshotPngViaPull } = require("./adb");
const { ensureDir } = require("./io");
const screenElements = require("./screen-elements");

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
  const outDir = path.join(ROOT, "docs", "manual_result", "full_auto");
  const shotDir = path.join(outDir, "screenshots");
  ensureDir(outDir);
  ensureDir(shotDir);

  console.log("[QA] full-auto started");
  console.log("[QA] emu base:", base);

  const health = await requestJson(`${base}/health`, { timeoutMs: 5000 });
  if (!health?.ok) throw new Error("emu health check failed");

  const deviceId = await pickDevice(a.device);
  console.log("[QA] device:", deviceId);

  const items = [
    { id: "LO_01_01", route: "/login", title: "로그인 선택", purpose: "앱 최초 진입 또는 로그아웃 후 인증 방식 선택. Google/Apple/Kakao SNS 로그인 또는 게스트(로컬) 모드 진입 제공.", ui: "SNS 로그인 버튼(Google/Apple/Kakao), 게스트 로그인 버튼, Easy Login 시트(QA용)", fn: "LoginChoiceScreen.build()", req: "인증·계정 관리" },
    { id: "LO_01_02", route: "/lo/01/02", title: "Google 로그인", purpose: "Google OAuth를 통한 회원 인증. Web 클라이언트 ID 기반 인증 후 토큰 저장 및 메인 화면 전환.", ui: "Google Sign-In 진행 상태, 결과 표시 영역", fn: "Lo0102GoogleLoginScreen", req: "인증·계정 관리" },
    { id: "LO_01_03", route: "/lo/01/03", title: "Apple 로그인", purpose: "Apple Sign-In을 통한 회원 인증. iOS/Android 지원.", ui: "Apple 인증 진행 상태, 결과 표시 영역", fn: "Lo0103AppleLoginScreen", req: "인증·계정 관리" },
    { id: "LO_01_04", route: "/lo/01/04", title: "Kakao 로그인", purpose: "Kakao OAuth를 통한 회원 인증. 네이티브 앱 키 기반.", ui: "Kakao 로그인 진행 상태, 결과 표시 영역", fn: "Lo0104KakaoLoginScreen", req: "인증·계정 관리" },
    { id: "LO_02_01", route: "/lo/02/01", title: "회원가입 시작", purpose: "신규 회원 가입 플로우 진입. 약관 동의→전화 인증→회원정보 입력→가입 완료 순서로 진행.", ui: "가입 단계 안내, 약관/전화인증/정보입력 선택", fn: "Lo0201SignUpIntroScreen", req: "인증·계정 관리" },
    { id: "LO_02_02", route: "/lo/02/02", title: "약관 동의", purpose: "가입 필수 약관 확인 및 동의. 동의 체크 후 다음 단계 진행.", ui: "약관 목록, 체크박스, 동의/다음 버튼", fn: "Lo0202TermsScreen", req: "인증·계정 관리" },
    { id: "LO_02_03", route: "/lo/02/03", title: "전화 인증", purpose: "전화번호 기반 본인 인증. 인증번호 발송·입력·검증.", ui: "전화번호 입력, 인증코드 입력, 인증 완료 표시", fn: "Lo0203PhoneVerifyScreen", req: "인증·계정 관리" },
    { id: "LO_02_04", route: "/lo/02/04", title: "회원정보 입력", purpose: "가입 필수 정보(이름, 생년월일 등) 입력. 서버 전송 후 가입 완료.", ui: "이름/생년월일/성별 등 입력 필드, 저장 버튼", fn: "Lo0204UserInfoWrapperScreen", req: "인증·계정 관리" },
    { id: "LO_02_05", route: "/lo/02/05", title: "가입 완료", purpose: "회원가입 완료 확인. 메인 또는 로그인 화면으로 진입.", ui: "완료 메시지, 다음 단계 버튼", fn: "Lo0205SignUpCompleteScreen", req: "인증·계정 관리" },
    { id: "GU_01_01", route: "/gu/01/01", title: "메인 대시보드", purpose: "현재 혈당 수치·추세·센서 잔여일수 표시. High(AR_01_03)/Low(AR_01_04) 설정값에 따른 차트 기준선 반영. glucoseUnit(mg/dL·mmol/L) 적용.", ui: "혈당 카드, 추세 화살표, 차트, 센서 잔여일, 하단 6탭(Home/Trend/Report/Sensor/Alarm/Settings)", fn: "MainDashboardPage.build()", req: "1. 블루투스 연결 / 4. 미구현(고·저 라인)" },
    { id: "TG_01_01", route: "/tg/01/01", title: "트렌드", purpose: "기간별 혈당 추세·통계 확인. Time in Range, 평균, GMI 등. glucoseUnit 반영.", ui: "기간 선택(1/7/30/90일), 통계 카드, 추세 차트", fn: "TrendTabPage.build()", req: "기간별 통계·추세" },
    { id: "TG_01_02", route: "/tg/01/02", title: "트렌드 가로", purpose: "가로 모드 확대 차트. 상세 혈당 추이 확인.", ui: "확대된 차트 뷰, Y축 단위 반영", fn: "Tg0102ChartLandscapeScreen", req: "기간별 통계·추세" },
    { id: "RP_01_01", route: "/rp/01/01", title: "리포트", purpose: "Glucose Report. 기간별(1/7/30/90일) 사용자 프로필·Key Metrics(Time in Range, Average, StdDev, Hypo/Hyper, GMI)·Range Distribution 차트. Share/Export 제공.", ui: "기간 탭, Profile 카드, Summary KPI, Range Distribution 파이차트, Share·Export 버튼", fn: "CgmsReportScreen.build()", req: "QA_검수 17번 Report 탭" },
    { id: "ME_01_01", route: "/me/01/01", title: "이벤트 편집", purpose: "식사·운동·인슐린 등 이벤트 기록 추가·편집. 메모·타입 선택.", ui: "이벤트 타입 선택, 메모 입력, 저장 버튼", fn: "Me0101EventEditorScreen", req: "이벤트 기록" },
    { id: "PD_01_01", route: "/pd/01/01", title: "이전 데이터", purpose: "eqsn별 과거 센서 데이터 조회. 기간·센서 선택.", ui: "eqsn별 리스트, 기간별 데이터 범위, 차트/통계", fn: "Pd0101PreviousDataScreen", req: "과거 데이터" },
    { id: "SC_01_01", route: "/sc/01/01", title: "권한/범위", purpose: "최초 센서 등록 전 권한 동의 및 혈당 범위(저·고) 임계값 설정. sc0101Consent, sc0101Low, sc0101High 저장.", ui: "권한 동의, Low/High 범위 입력, 다음 버튼", fn: "Sc0101PermissionRangeScreen", req: "블루투스 연결 흐름" },
    { id: "SC_01_03", route: "/sc/01/03", title: "NFC 스캔", purpose: "NFC 기반 센서 연결 가이드. NFC 태깅으로 기기 인식.", ui: "NFC 안내, 태깅 동작 상태", fn: "Sc0103NfcScanScreen", req: "블루투스 연결" },
    { id: "SC_01_04", route: "/sc/01/04", title: "QR 스캔", purpose: "QR 스캔 자동 접속. QR 형식 #1;#2;#3(ADV이름;ID+MAC;일련번호). MAC 기반 BLE 연결 후 워밍업 자동 이동. Register Device=SAVE&SYNC와 동일(최초 eqsn DB 저장).", ui: "카메라 뷰, Detected Result(Model, Manufactured, Serial), Register Device 버튼", fn: "SensorQrConnectPage", req: "1-2. QR 스캔 자동 접속 / Register Device=SC_04_01 SAVE&SYNC" },
    { id: "SC_01_05", route: "/sc/01/05", title: "수동 SN 입력", purpose: "수동 접속 시 시리얼번호(5자리) 입력. SN 미입력 시 MAC 대체 사용. 입력 시 기존 manual_sn 항목 덮어쓰기.", ui: "SN 입력 필드, 저장 버튼", fn: "Sc0105ManualSnScreen", req: "1-1. 수동 접속 / SC_04_01 시리얼 등록" },
    { id: "SC_01_06", route: "/sc/01/06", title: "워밍업", purpose: "최초 센서 연결 후 30분 워밍업 카운트다운. 연결 완료 시 자동 진입. 시작/종료 시각 표시.", ui: "Warming up 진행률, 남은 시간(MM:SS), Started at / Ends at", fn: "Sc0106WarmupScreen", req: "1-2. 연결 완료 시 워밍업 페이지 자동 이동" },
    { id: "SC_02_01", route: "/sc/02/01", title: "센서 관리", purpose: "Sensor 탭. Usage period, Remaining, Start Time. Scan & Connect(수동 BLE), Serial Number, Start Time, Share Data, How to remove 링크.", ui: "센서 카드, Status, Scan & Connect, Serial Number, Start Time, Share, Remove 링크", fn: "SensorPage.build()", req: "1. 블루투스 연결 / 2-1. Start Time 동기화" },
    { id: "SC_03_01", route: "/sc/03/01", title: "센서 상태", purpose: "BLE 연결 상태·패킷 수·배터리 등. BleService 연동.", ui: "연결 on/off, rxCount, deviceName, battery, rssi", fn: "SensorStatusPage", req: "QA_검수 15번 Status(SC_03_01)" },
    { id: "SC_04_01", route: "/sc/04/01", title: "시리얼 번호", purpose: "SC_04_01 Serial Number. SAVE & SYNC로 eqsn DB 저장. QR Register Device와 동일 기능.", ui: "시리얼 정보, SAVE & SYNC 버튼", fn: "SensorSerialPage", req: "Register Device=SAVE&SYNC 동일" },
    { id: "SC_05_01", route: "/sc/05/01", title: "Start Time", purpose: "센서 시작 시각 표시. 요구: BT 연결 시각으로 자동 동기화(사용자 저장 불필요).", ui: "시작일시 표시", fn: "SensorStartTimePage", req: "2-1. Start Time 자동 동기화" },
    { id: "SC_06_01", route: "/sc/06/01", title: "NFC 재연결", purpose: "NFC 재연결 절차 안내.", ui: "재연결 단계 안내", fn: "SensorReconnectNfcPage", req: "재연결 가이드" },
    { id: "SC_06_02", route: "/sc/06/02", title: "QR 재연결", purpose: "QR 재연결 절차 안내.", ui: "QR 재스캔 절차", fn: "Sc0602QrReconnectScreen", req: "재연결 가이드" },
    { id: "SC_07_01", route: "/sc/07/01", title: "데이터 공유", purpose: "혈당 데이터 공유 설정. 기간·포맷·대상 선택.", ui: "공유 기간, PDF/기타 포맷, 이메일/SMS 옵션", fn: "Sc0701DataShareScreen", req: "Share Data" },
    { id: "SC_08_01", route: "/sc/08/01", title: "센서 제거", purpose: "센서 해제·삭제. How to remove.", ui: "삭제 확인 다이얼로그, 완료", fn: "SensorRemovePageWrapper", req: "How to remove" },
    { id: "AR_ROOT", route: "/ar/root", title: "알람 루트", purpose: "Alerts(AR_01_01). Mute all, Very Low/High/Low/Rate/System 알람 타입 목록. Settings Alarms 카드와 동일 설정.", ui: "Mute all alarms, Very Low, High, Low, Rapid Change, Signal Loss, Lock Screen 행", fn: "AlertsRootPage", req: "3. Alarm / 3-1. AR_01_01 저장·화면 전환" },
    { id: "AR_01_01", route: "/ar/01/01", title: "전체 무음", purpose: "Mute all alarms. On/Off 저장·표시. alarmsMuteAll=true 시 소리·진동 비활성.", ui: "Mute all 설명, 토글", fn: "Ar0101MuteAllScreen", req: "3. Setting Mute all 저장 / 반영 완료 2초 이내" },
    { id: "AR_01_02", route: "/ar/01/02", title: "Very Low", purpose: "저혈당(54mg/dL 이하) 임계값·반복·소리·진동 설정. 로컬 캐시+서버 저장.", ui: "임계값, 반복 간격, sound/vibrate 토글", fn: "AlarmTypeDetailPage(very_low)", req: "AR_01_02 설정 범위 저장" },
    { id: "AR_01_03", route: "/ar/01/03", title: "High", purpose: "고혈당 임계값 설정. 메인 차트 고혈당 라인 반영.", ui: "임계값, 반복, sound/vibrate", fn: "AlarmTypeDetailPage(high)", req: "4. 미구현 High 라인 반영" },
    { id: "AR_01_04", route: "/ar/01/04", title: "Low", purpose: "저혈당 임계값 설정. 메인 차트 저혈당 라인 반영.", ui: "임계값, 반복, sound/vibrate", fn: "AlarmTypeDetailPage(low)", req: "4. 미구현 Low 라인 반영" },
    { id: "AR_01_05", route: "/ar/01/05", title: "Rapid Change", purpose: "급변동(rate) 알림. 변화율 임계값 설정.", ui: "변화율 임계값, 반복, sound/vibrate", fn: "AlarmTypeDetailPage(rate)", req: "Alarm" },
    { id: "AR_01_06", route: "/ar/01/06", title: "Signal Loss", purpose: "시그널 손실(system) 알림 설정.", ui: "시스템 알림 토글, sound/vibrate", fn: "AlarmTypeDetailPage(system)", req: "Alarm" },
    { id: "AR_01_08", route: "/ar/01/08", title: "Lock Screen", purpose: "잠금화면 혈당 표시. ar0108Enabled 설정.", ui: "잠금화면 표시 On/Off", fn: "Ar0108LockScreenScreen", req: "Alarm" },
    { id: "ST_01_01", route: "/settings", title: "설정", purpose: "General(Language, Region, Time format 24h/12h, Chart dot size, Notifications, Mute all). Units(Glucose mg/dL·mmol/L). Accessibility(High contrast, Larger font, Color blind). Alarms 목록. 사용자 카드(로그인 시 이름·이메일).", ui: "General·Units·Accessibility·Alarms 카드, 사용자 정보", fn: "SettingsPage.build()", req: "3. Setting 저장·반영" },
  ];

  // UI 요소별 상세 설명 병합
  for (const it of items) {
    it.elements = (screenElements[it.id] || []).join("\n");
  }

  // BLE QA 시뮬레이션 준비 (등록 데이터/세션 보강)
  await requestJson(`${base}/emu/app/sc0104/qrSuccess`, {
    method: "POST",
    body: { fullSn: "C21ZS00033", serial: "00033", model: "C21", year: "2025", sampleFlag: "S", mac: "AA:BB:CC:DD:EE:01" },
    timeoutMs: 15000,
  }).catch(() => null);
  await requestJson(`${base}/emu/app/gu0101`, { method: "POST", body: {}, timeoutMs: 12000 }).catch(() => null);

  const results = [];
  for (const it of items) {
    try {
      await requestJson(`${base}/emu/app/nav`, {
        method: "POST",
        body: { route: it.route, replaceStack: true },
        timeoutMs: 12000,
      });
      await new Promise((r) => setTimeout(r, 1400));

      let png;
      try {
        png = await screenshotPng({ deviceId, timeoutMs: 20000 });
      } catch (_) {
        png = await screenshotPngViaPull({ deviceId });
      }
      const file = `${it.id}.png`;
      fs.writeFileSync(path.join(shotDir, file), png);
      results.push({ ...it, shot: `screenshots/${file}`, status: "ok" });
      console.log(`[OK] ${it.id} ${it.route}`);
    } catch (e) {
      results.push({ ...it, shot: "", status: "fail", error: e?.message || String(e) });
      console.warn(`[FAIL] ${it.id} ${it.route}: ${e?.message || e}`);
    }
  }

  const okCount = results.filter((r) => r.status === "ok").length;
  const html = `<!doctype html>
<html lang="ko"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>CGMS QA Full Auto Report</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#111}
table{width:100%;border-collapse:collapse}th,td{border:1px solid #ddd;padding:8px;font-size:12px;vertical-align:top}
th{background:#f5f5f5} img{max-width:240px;border:1px solid #ccc;border-radius:6px}
.ok{color:#0a7f2e}.fail{color:#b00020}
</style></head><body>
<h1>CGMS QA Full Auto Report</h1>
<p>총 ${results.length}개 / 성공 ${okCount}개 / 실패 ${results.length - okCount}개</p>
<p>Emu API: ${base}</p>
<table><thead><tr><th>기능번호</th><th>목적·요구사항</th><th>화면구성</th><th>UI요소(버튼·입력·토글 등)</th><th>관련 함수</th><th>상태</th><th>스크린샷</th></tr></thead><tbody>
${results.map((r) => {
  const purposeReq = r.req ? `${r.purpose}<br/><small style="color:#666">[요구] ${r.req}</small>` : r.purpose;
  const elementsHtml = (r.elements || "").split("\n").filter(Boolean).map((s) => s.trim()).join("<br/>") || "-";
  return `<tr>
<td>${r.id}<br/><code>${r.route}</code></td>
<td style="max-width:320px;font-size:11px">${purposeReq}</td>
<td style="max-width:200px;font-size:11px">${r.ui}</td>
<td style="max-width:260px;font-size:10px;line-height:1.4">${elementsHtml}</td>
<td><code style="font-size:10px">${r.fn}</code></td>
<td class="${r.status === "ok" ? "ok" : "fail"}">${r.status}${r.error ? `<br/>${r.error}` : ""}</td>
<td>${r.shot ? `<img src="${r.shot}" alt="${r.id}"/>` : "-"}</td>
</tr>`;
}).join("\n")}
</tbody></table></body></html>`;

  fs.writeFileSync(path.join(outDir, "full_auto_report.html"), html, "utf8");
  fs.writeFileSync(path.join(outDir, "full_auto_result.json"), JSON.stringify({
    ok: okCount === results.length,
    total: results.length,
    success: okCount,
    failed: results.length - okCount,
    items: results,
  }, null, 2), "utf8");

  console.log("[QA] report:", path.join(outDir, "full_auto_report.html"));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

