const crypto = require("crypto");
const OpenAI = require("openai");

function getMimeFromPath(p) {
  const ext = String(p || "").toLowerCase().split(".").pop();
  if (ext === "png") return "image/png";
  if (ext === "jpg" || ext === "jpeg") return "image/jpeg";
  if (ext === "webp") return "image/webp";
  if (ext === "gif") return "image/gif";
  return null;
}

function sha256(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function extractFirstJsonObject(text) {
  const s = String(text || "");
  // Prefer fenced JSON blocks if present (Gemini/OpenAI sometimes wrap output).
  const fence = s.match(/```json\s*([\s\S]*?)\s*```/i);
  if (fence && fence[1]) {
    const inside = fence[1].trim();
    if (inside.startsWith("{") && inside.endsWith("}")) return inside;
  }
  const start = s.indexOf("{");
  if (start < 0) return null;
  // naive brace match
  let depth = 0;
  for (let i = start; i < s.length; i++) {
    const ch = s[i];
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return s.slice(start, i + 1);
    }
  }
  return null;
}

async function describeImageWithOpenAI({ apiKey, model, imageBuffer, imagePath, contextText }) {
  const mime = getMimeFromPath(imagePath) || "image/png";
  const b64 = imageBuffer.toString("base64");
  const client = new OpenAI({ apiKey });

  const prompt = [
    "당신은 앱 요구사항 문서(엑셀/슬라이드) 이미지 분석가입니다.",
    "아래 이미지는 표/다이어그램/화면 캡처일 수 있습니다.",
    "가능한 한 상세하게(정확한 라벨/값/흐름/상태/조건/예외/버튼/필드명을 최대한 보존) 분석하세요.",
    "다음을 한국어 JSON으로만 답하세요(마크다운 금지).",
    "",
    "필드:",
    "- summary: 이미지 핵심 요약(5~12문장, 기능/화면/동작 중심)",
    "- extractedText: 이미지에서 읽힌 텍스트/라벨/필드명/버튼명/표 항목을 가능한 그대로 줄바꿈으로(추정은 표시)",
    "- uiElements: [{type,label,value,notes}] 형태로 버튼/입력필드/토글/탭/표열/경고문 등을 최대한 나열",
    "- flows: [\"사용자 액션 -> 시스템 반응 -> 다음 상태\"] 형태로 가능한 시나리오를 나열",
    "- possibleScreenIds: 화면/페이지 ID로 보이는 값들(예: SC_01_01) 배열",
    "- uncertainties: 애매하거나 판독 불가/가려진/저해상도 부분 배열",
    "",
    "추가 컨텍스트:",
    contextText ? contextText : "(없음)",
  ].join("\n");

  const resp = await client.responses.create({
    model: model || process.env.OPENAI_VISION_MODEL || "gpt-4o-mini",
    input: [
      {
        role: "user",
        content: [
          { type: "input_text", text: prompt },
          { type: "input_image", image_url: `data:${mime};base64,${b64}` },
        ],
      },
    ],
  });

  const outText =
    resp.output_text ||
    (resp.output && resp.output[0] && resp.output[0].content && resp.output[0].content[0] && resp.output[0].content[0].text) ||
    "";

  const jsonStr = extractFirstJsonObject(outText);
  if (jsonStr) {
    try {
      const obj = JSON.parse(jsonStr);
      return { ok: true, raw: outText, data: obj };
    } catch {
      // fallthrough
    }
  }
  return { ok: false, raw: outText, data: null };
}

async function describeImageWithGemini({ apiKey, model, imageBuffer, imagePath, contextText }) {
  const mime = getMimeFromPath(imagePath) || "image/png";
  const b64 = imageBuffer.toString("base64");

  const prompt = [
    "당신은 앱 요구사항 문서(엑셀/슬라이드) 이미지 분석가입니다.",
    "아래 이미지는 표/다이어그램/화면 캡처일 수 있습니다.",
    "가능한 한 상세하게(정확한 라벨/값/흐름/상태/조건/예외/버튼/필드명을 최대한 보존) 분석하세요.",
    "다음을 한국어 JSON으로만 답하세요(마크다운 금지).",
    "",
    "필드:",
    "- summary: 이미지 핵심 요약(5~12문장, 기능/화면/동작 중심)",
    "- extractedText: 이미지에서 읽힌 텍스트/라벨/필드명/버튼명/표 항목을 가능한 그대로 줄바꿈으로(추정은 표시)",
    "- uiElements: [{type,label,value,notes}] 형태로 버튼/입력필드/토글/탭/표열/경고문 등을 최대한 나열",
    "- flows: [\"사용자 액션 -> 시스템 반응 -> 다음 상태\"] 형태로 가능한 시나리오를 나열",
    "- possibleScreenIds: 화면/페이지 ID로 보이는 값들(예: SC_01_01) 배열",
    "- uncertainties: 애매하거나 판독 불가/가려진/저해상도 부분 배열",
    "",
    "추가 컨텍스트:",
    contextText ? contextText : "(없음)",
  ].join("\n");

  const useModel = model || process.env.GEMINI_MODEL || process.env.GEMINI_VISION_MODEL || "gemini-2.5-flash-image";
  if (typeof fetch !== "function") throw new Error("Node fetch가 없어 Gemini 호출을 수행할 수 없습니다.");

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(useModel)}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const body = {
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt },
          { inline_data: { mime_type: mime, data: b64 } },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 2048,
    },
  };

  // Gemini는 간헐적으로 5xx/429가 발생할 수 있어, 짧게 재시도한다.
  const maxAttempts = 4;
  let lastErr = null;
  let text = "";
  let resp = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      resp = await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      });
      text = await resp.text();
      if (resp.ok) break;
      const retryable = resp.status === 429 || (resp.status >= 500 && resp.status <= 599);
      if (!retryable) {
        throw new Error(`Gemini API error (${resp.status}): ${text.slice(0, 500)}`);
      }
      lastErr = new Error(`Gemini API error (${resp.status}): ${text.slice(0, 500)}`);
    } catch (e) {
      lastErr = e;
    }
    if (attempt < maxAttempts) {
      const backoffMs = Math.min(8000, 700 * (2 ** (attempt - 1))) + Math.floor(Math.random() * 200);
      await new Promise((r) => setTimeout(r, backoffMs));
    }
  }
  if (!resp || !resp.ok) {
    throw lastErr || new Error("Gemini API error: unknown");
  }

  let outText = "";
  try {
    const json = JSON.parse(text);
    outText =
      json?.candidates?.[0]?.content?.parts?.map((p) => p.text).filter(Boolean).join("\n") ||
      "";
  } catch {
    outText = text || "";
  }

  const jsonStr = extractFirstJsonObject(outText);
  if (jsonStr) {
    try {
      const obj = JSON.parse(jsonStr);
      return { ok: true, raw: outText, data: obj };
    } catch {
      // fallthrough
    }
  }
  return { ok: false, raw: outText, data: null };
}

async function describeImage({ provider, openaiApiKey, geminiApiKey, model, imageBuffer, imagePath, contextText }) {
  const p = (provider || "").toLowerCase().trim();
  if (p === "gemini") {
    return describeImageWithGemini({
      apiKey: geminiApiKey,
      model,
      imageBuffer,
      imagePath,
      contextText,
    });
  }
  return describeImageWithOpenAI({
    apiKey: openaiApiKey,
    model,
    imageBuffer,
    imagePath,
    contextText,
  });
}

/**
 * Simple in-memory + optional file-backed cache.
 */
function createAiCache(initial = {}) {
  const map = new Map(Object.entries(initial || {}));
  return {
    get: (key) => map.get(key),
    set: (key, val) => map.set(key, val),
    toJSON: () => Object.fromEntries(map.entries()),
  };
}

module.exports = { sha256, describeImageWithOpenAI, describeImageWithGemini, describeImage, createAiCache };

