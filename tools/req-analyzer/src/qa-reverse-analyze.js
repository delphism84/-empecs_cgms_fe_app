#!/usr/bin/env node
/* eslint-disable no-console */

const fs = require("fs");
const path = require("path");
const { sha256, describeImage, createAiCache } = require("./ai");

function parseArgs(argv) {
  const a = { ids: [] };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--ids") {
      const v = (argv[++i] || "").trim();
      if (v) a.ids = v.split(",").map((s) => s.trim()).filter(Boolean);
      continue;
    }
    if (x.startsWith("--")) {
      const k = x.slice(2);
      const v = (i + 1 < argv.length && !argv[i + 1].startsWith("--")) ? argv[++i] : true;
      a[k] = v;
      continue;
    }
  }
  return a;
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

function writeText(p, s) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, s, "utf8");
}

function writeJson(p, o) {
  writeText(p, JSON.stringify(o, null, 2));
}

function esc(s) {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function defaultIds260306() {
  return [
    "SC_01_06",
    "SC_01_01",
    "SC_03_01",
    "SC_02_01",
    "SC_07_01",
    "AR_01_01",
    "AR_01_02",
    "AR_01_03",
    "AR_01_04",
    "AR_01_05",
    "AR_01_06",
    "AR_01_08",
    "LO_02_02",
    "LO_02_03",
  ];
}

function normalizeKey(s) {
  return String(s || "").trim();
}

function pickQaItems(qaDb, ids) {
  const map = new Map();
  for (const it of (qaDb.items || [])) {
    const id = normalizeKey(it.id);
    if (!id) continue;
    if (!ids.includes(id)) continue;
    // keep latest by verifiedAt
    const prev = map.get(id);
    if (!prev) map.set(id, it);
    else {
      const ta = Date.parse(prev.verifiedAt || "") || 0;
      const tb = Date.parse(it.verifiedAt || "") || 0;
      if (tb >= ta) map.set(id, it);
    }
  }
  return ids.map((id) => map.get(id)).filter(Boolean);
}

function extractMdContextById(mdText, id) {
  const lines = String(mdText || "").split(/\r?\n/);
  const out = [];
  let curSlide = "";
  let curCandidates = [];
  let inPickedSection = false;
  for (const ln of lines) {
    if (ln.startsWith("## ")) {
      curSlide = ln.replace(/^##\s+/, "").trim();
      curCandidates = [];
      inPickedSection = false;
      continue;
    }
    if (ln.includes("화면ID 후보:")) {
      const m = ln.match(/`([^`]+)`/g) || [];
      curCandidates = m.map((x) => x.replaceAll("`", "").trim()).filter(Boolean);
    }
    if (ln.startsWith("### ")) {
      // 이슈/요구 + 결정/조치 섹션을 함께 컨텍스트로 제공
      inPickedSection = ln.includes("이슈/요구") || ln.includes("결정/조치");
      continue;
    }
    const hit = (curCandidates.includes(id)) || ln.includes(id);
    if (hit && inPickedSection && ln.trim().startsWith("- ")) {
      out.push(`[${curSlide}] ${ln.trim().replace(/^- /, "")}`);
    }
  }
  // fallback: any line containing id
  if (!out.length) {
    for (const ln of lines) {
      if (ln.includes(id)) out.push(ln.trim());
    }
  }
  return out.slice(0, 12);
}

function extractPptxContext(reqExtracted, id) {
  const slides = reqExtracted?.files?.[0]?.slides || [];
  const out = [];
  for (const s of slides) {
    const slideIdx = s?.index;
    const t = String(s?.text || "");
    let hit = t.includes(id);
    const imgHits = [];
    for (const img of (s?.images || [])) {
      const ai = img?.ai;
      const et = String(ai?.extractedText || "");
      if (et.includes(id)) {
        hit = true;
        imgHits.push(et.split(/\r?\n/).filter((x) => x.includes(id)).slice(0, 6).join("\n"));
      }
    }
    if (!hit) continue;
    const head = `Slide ${slideIdx}: ${t.slice(0, 160).replace(/\s+/g, " ").trim()}`;
    out.push(head);
    for (const b of imgHits) if (b.trim()) out.push(b.trim());
    if (out.length >= 18) break;
  }
  return out.slice(0, 18);
}

function summarizeEvidence(it) {
  const st = it?.evidence?.appStats || null;
  const sc = it?.evidence?.serverCheck || null;
  return {
    id: it?.id,
    title: it?.title,
    verifiedAt: it?.verifiedAt,
    nav: it?.evidence?.screenshotNav || null,
    appStats: st
      ? {
        currentRoute: st.currentRoute,
        language: st.language,
        timeFormat: st.timeFormat,
        glucoseUnit: st.glucoseUnit,
        accHighContrast: st.accHighContrast,
        accLargerFont: st.accLargerFont,
        accColorblind: st.accColorblind,
        sc0106WarmupActive: st.sc0106WarmupActive,
        sc0106WarmupRemainingSec: st.sc0106WarmupRemainingSec,
        sc0701LastSharedOk: st.sc0701LastSharedOk,
        sc0701LastNote: st.sc0701LastNote,
        lastAlert: st.lastAlert ? { alarmType: st.lastAlert.alarmType, reason: st.lastAlert.reason, time: st.lastAlert.time } : null,
      }
      : null,
    serverCheck: sc
      ? {
        ok: sc.ok === true,
        checks: sc.checks
          ? {
            sensors: sc.checks.sensors?.ok === true ? sc.checks.sensors.result : { ok: false },
            alarms: sc.checks.alarms?.ok === true ? sc.checks.alarms.result : { ok: false },
            logTx: sc.checks.logTx?.ok === true ? sc.checks.logTx.result : { ok: false },
          }
          : null,
      }
      : null,
  };
}

function toRel(fromDir, absPath) {
  const rel = path.relative(fromDir, absPath).split(path.sep).join("/");
  return rel.startsWith(".") ? rel : `./${rel}`;
}

function renderHtml({ title, rows }) {
  const body = rows.map((r) => {
    const v = r.verdict || {};
    const reasons = Array.isArray(v.reasons) ? v.reasons.join("\n") : (v.reasons || "");
    const missing = Array.isArray(v.missingEvidence) ? v.missingEvidence.join("\n") : (v.missingEvidence || "");
    const next = Array.isArray(v.nextSteps) ? v.nextSteps.join("\n") : (v.nextSteps || "");
    const conf = (typeof v.confidence === "number") ? v.confidence.toFixed(2) : "";
    const shot = r.screenshotRel ? `<a href="${esc(r.screenshotRel)}" target="_blank" rel="noopener">open</a>` : "";
    const raw = r.aiRaw ? `<details><summary>ai raw</summary><pre>${esc(r.aiRaw)}</pre></details>` : "";
    return `
      <tr>
        <td class="id">${esc(r.id)}</td>
        <td>${esc(r.title || "")}</td>
        <td>${esc(v.implemented || "")}</td>
        <td>${esc(conf)}</td>
        <td><pre>${esc(reasons)}</pre></td>
        <td><pre>${esc(missing)}</pre></td>
        <td><pre>${esc(next)}</pre></td>
        <td>${shot}</td>
        <td><details><summary>context</summary><pre>${esc(r.contextText || "")}</pre></details>${raw}</td>
      </tr>
    `;
  }).join("\n");

  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>${esc(title)}</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, "Noto Sans KR", Arial; margin: 16px; }
    h1 { margin: 0 0 10px; font-size: 18px; }
    .meta { color: #555; margin: 0 0 16px; font-size: 12px; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #e5e5e5; padding: 8px; vertical-align: top; }
    th { background: #fafafa; position: sticky; top: 0; z-index: 1; }
    pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-size: 12px; }
    .id { font-weight: 700; white-space: nowrap; }
    details pre { max-height: 260px; overflow: auto; }
  </style>
</head>
<body>
  <h1>${esc(title)}</h1>
  <div class="meta">generated: ${esc(new Date().toISOString())}</div>
  <table>
    <thead>
      <tr>
        <th>ID</th>
        <th>QA title</th>
        <th>구현판정</th>
        <th>신뢰도</th>
        <th>근거</th>
        <th>부족/미확인</th>
        <th>추가 QA 제안</th>
        <th>캡처</th>
        <th>원문</th>
      </tr>
    </thead>
    <tbody>
      ${body || "<tr><td colspan='9'>No rows.</td></tr>"}
    </tbody>
  </table>
</body>
</html>`;
}

async function main() {
  // Load local .env (do not print secrets)
  try {
    require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });
    if (!process.env.GEMINI_API_KEY && process.env.gemini_api_key) process.env.GEMINI_API_KEY = process.env.gemini_api_key;
    if (!process.env.GEMINI_IMAGE_GEN_MODEL && process.env.gemini_api_engine) process.env.GEMINI_IMAGE_GEN_MODEL = process.env.gemini_api_engine;
  } catch (_) {}

  const a = parseArgs(process.argv);
  const root = path.resolve(__dirname, "..", "..", ".."); // empecs_cgms

  const qaPath = path.resolve(root, a.qa || "req/req1/_qa/qa-results.json");
  const reqPath = path.resolve(root, a.req || "docs/req260305/_analysis_260306/req-extracted.json");
  const mdPath = path.resolve(root, a.md || "req260306.md");

  const outHtml = path.resolve(root, a.out || "req260306-qa-ai.html");
  const outJson = outHtml.replace(/\.html?$/i, ".json");
  const cachePath = path.resolve(root, a.cache || "docs/req260305/_analysis_260306/qa-ai-cache.json");

  const ids = (a.ids && a.ids.length) ? a.ids : defaultIds260306();
  const qaDb = readJson(qaPath);
  const reqExtracted = readJson(reqPath);
  const mdText = fs.readFileSync(mdPath, "utf8");

  const provider = "gemini";
  const geminiApiKey = process.env.GEMINI_API_KEY;
  const model = process.env.GEMINI_VISION_MODEL || process.env.GEMINI_MODEL || "gemini-2.5-flash-image";
  if (!geminiApiKey) {
    console.error("GEMINI_API_KEY(gemini_api_key) 없음: tools/req-analyzer/.env 확인 필요");
    process.exit(2);
  }

  let cacheJson = {};
  try { cacheJson = readJson(cachePath) || {}; } catch (_) { cacheJson = {}; }
  const cache = createAiCache(cacheJson);

  const picked = pickQaItems(qaDb, ids);
  const rows = [];

  for (const it of picked) {
    const id = normalizeKey(it.id);
    const shotAbs = it?.screenshot?.absPath ? String(it.screenshot.absPath) : "";
    if (!shotAbs || !fs.existsSync(shotAbs)) {
      rows.push({ id, title: it.title, verdict: { implemented: "uncertain", confidence: 0.0, reasons: ["스크린샷 파일이 없음"], missingEvidence: ["UI 캡처"], nextSteps: ["qa-bot --screenshot 재실행"] } });
      continue;
    }

    const imgBuf = fs.readFileSync(shotAbs);
    const ev = summarizeEvidence(it);
    const mdCtx = extractMdContextById(mdText, id);
    const pptxCtx = extractPptxContext(reqExtracted, id);

    const contextText = [
      `판정 목표: 아래 스크린샷(실기기 캡처) + 런타임 증거(appStats)를 바탕으로, Accessibility 토글(고대비/색각/큰 글씨)이 "실제로 시각적으로 반영"되는지 판정한다.`,
      `특히 appStats.accHighContrast / appStats.accColorblind / appStats.accLargerFont 값과 화면의 시각적 특징(색상 채도 감소, 대비 강화, 글자/컨트롤 크기 증가)이 일치하는지에 초점을 맞춰라.`,
      "",
      `요구사항/이슈 근거(req260306.md 요약):`,
      mdCtx.length ? mdCtx.map((x) => `- ${x}`).join("\n") : "- (해당 ID 직접 언급 없음)",
      "",
      `PPTX 근거(req-extracted.json에서 ID 힌트):`,
      pptxCtx.length ? pptxCtx.map((x) => `- ${x}`).join("\n") : "- (ID 힌트 없음)",
      "",
      `QA 런타임 증거(요약):`,
      JSON.stringify(ev, null, 2),
      "",
      `요청: 기존 JSON 필드(summary/extractedText/uiElements/flows/possibleScreenIds/uncertainties) 외에 다음 최상위 필드를 추가해라.`,
      `- verdict: {implemented: "yes"|"no"|"uncertain", confidence: 0~1, reasons: string[], missingEvidence: string[], nextSteps: string[] }`,
      `판정 규칙:`,
      `- appStats에서 토글이 OFF(false)면, 스크린샷이 "일반 UI(과도한 대비/탈채도/폰트 확대 없음)"으로 보이는 것이 정상이다. 이 경우 yes.`,
      `- appStats에서 특정 토글이 ON(true)이면, 해당 효과가 스크린샷에서 "눈에 띄게" 보여야 정상이다. 보이면 yes.`,
      `- ON인데 효과가 안 보이거나, OFF인데 효과가 보이면 no.`,
      `- 판단이 애매하면 uncertain.`,
    ].join("\n");

    const key = sha256(Buffer.from([sha256(imgBuf), sha256(Buffer.from(contextText, "utf8")), provider, model].join("|")));
    const cached = cache.get(key);
    let aiRes = cached;
    let aiRaw = null;
    if (!aiRes) {
      const r = await describeImage({
        provider,
        openaiApiKey: null,
        geminiApiKey,
        model,
        imageBuffer: imgBuf,
        imagePath: shotAbs,
        contextText,
      });
      aiRes = r;
      aiRaw = r?.raw || null;
      cache.set(key, aiRes);
      // be gentle to API
      await new Promise((r2) => setTimeout(r2, 250));
    }

    const data = aiRes?.data || {};
    const verdict = data?.verdict || { implemented: "uncertain", confidence: 0.1, reasons: ["AI JSON에서 verdict 누락"], missingEvidence: [], nextSteps: [] };
    rows.push({
      id,
      title: it.title,
      screenshotAbs: shotAbs,
      screenshotRel: toRel(path.dirname(outHtml), shotAbs),
      contextText,
      verdict,
      ai: data,
      aiRaw: aiRaw || aiRes?.raw || null,
    });
  }

  const title = "req260306 · QA 캡처 역분석(Gemini) · 구현 여부 판정";
  writeJson(cachePath, cache.toJSON());
  writeJson(outJson, { ok: true, generatedAt: new Date().toISOString(), qaPath, reqPath, mdPath, ids, rows });
  writeText(outHtml, renderHtml({ title, rows }));
  console.log(JSON.stringify({ ok: true, outHtml, outJson, cachePath, count: rows.length }, null, 2));
}

main().catch((e) => {
  console.error(e?.stack || String(e));
  process.exit(1);
});

