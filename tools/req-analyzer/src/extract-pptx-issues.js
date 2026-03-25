#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

function usage() {
  return [
    "node src/extract-pptx-issues.js <path-to-req-extracted.json> --out <md-path> [--file-substr <pptx-filename-substr>]",
  ].join("\n");
}

function pickArg(argv, name) {
  const i = argv.indexOf(name);
  if (i >= 0) return argv[i + 1];
  return null;
}

function extractScreenIds(s) {
  return Array.from(new Set((String(s || "").match(/\b[A-Z]{2,3}_[0-9]{2}_[0-9]{2}\b/g) || [])));
}

function splitSentences(text) {
  const s = String(text || "").replace(/\r/g, "\n");
  return s
    .split(/[\n]+/)
    .map((x) => x.trim())
    .filter(Boolean)
    .flatMap((line) => line.split(/(?<=[.!?])\s+/).map((x) => x.trim()).filter(Boolean));
}

function containsIssueKeyword(s) {
  const t = String(s || "");
  return /미구현|오류|에러|버그|문제|불가|안됨|안 됨|실패|누락|재현|재확인|수정|수정 필요|개선|개선 필요|안나옴|안 나옴|안보임|안 보임|깨짐|겹침|정렬|잘못|오동작|잡히지|잡히지 않|안 잡|맞지 않|불일치|차이|다름/i.test(t);
}

function mdEscape(s) {
  return String(s || "").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function main() {
  const argv = process.argv.slice(2);
  const inPath = argv[0];
  if (!inPath) {
    console.error(usage());
    process.exit(1);
  }
  const outPath = pickArg(argv, "--out");
  if (!outPath) {
    console.error("Missing --out");
    console.error(usage());
    process.exit(1);
  }
  const fileSubstr = pickArg(argv, "--file-substr");

  const absIn = path.resolve(process.cwd(), inPath);
  const absOut = path.resolve(process.cwd(), outPath);
  const raw = fs.readFileSync(absIn, "utf8");
  const extracted = JSON.parse(raw);

  const pptxFiles = (extracted.files || []).filter((f) => f && f.kind === "pptx");
  const picked =
    (fileSubstr
      ? pptxFiles.find((f) => String(f.file || "").toLowerCase().includes(String(fileSubstr).toLowerCase()))
      : null) ||
    pptxFiles[0];

  if (!picked) {
    console.error("No pptx files found in req-extracted.json");
    process.exit(2);
  }

  const slideItems = [];
  for (const sl of picked.slides || []) {
    const imgTexts = (sl.images || [])
      .map((x) => x && x.ai)
      .filter(Boolean)
      .flatMap((ai) => [ai.summary, ai.extractedText].filter(Boolean));
    const combined = [sl.title, sl.text, ...imgTexts].filter(Boolean).join("\n");
    const sentences = splitSentences(combined);
    const issues = sentences.filter(containsIssueKeyword);
    const screenIds = Array.from(
      new Set([
        ...extractScreenIds(combined),
        ...((sl.images || []).flatMap((x) => (x?.ai?.possibleScreenIds || [])).filter(Boolean)),
      ])
    ).sort();

    if (issues.length) {
      slideItems.push({
        index: sl.index,
        title: sl.title,
        slidePath: sl.slidePath,
        screenIds,
        issues: issues.slice(0, 40),
        images: (sl.images || []).map((x) => ({ path: x.path, skipped: !!x.skipped, cached: !!x.cached })),
      });
    }
  }

  const lines = [];
  lines.push(`# req260306 · PPTX 이슈/미구현/오류 후보 목록(자동 추출)`);
  lines.push("");
  lines.push(`- 원본: \`${path.relative(process.cwd(), picked.file) || picked.file}\``);
  lines.push(`- 슬라이드: ${picked.summary?.slideCount ?? (picked.slides || []).length}장`);
  lines.push(`- AI: ${extracted.aiUsage?.enabled ? `enabled (provider=${extracted.aiUsage?.provider || "?"}, model=${extracted.aiUsage?.model || "?"})` : "disabled"}`);
  lines.push("");
  lines.push("> 아래 내용은 슬라이드 텍스트 + 이미지에서 AI가 읽은 텍스트/요약에서 **키워드 기반으로 ‘문제/미구현/재확인’ 문장만 추린 것**입니다.");
  lines.push("> 실제 요구사항 확정은 각 슬라이드의 전체 맥락을 함께 확인해야 합니다.");
  lines.push("");

  if (!slideItems.length) {
    lines.push("- (키워드 기반으로 잡힌 이슈 문장이 없습니다)");
  } else {
    for (const it of slideItems) {
      lines.push(`## 슬라이드 ${it.index} · ${mdEscape(it.title || "")}`);
      lines.push("");
      if (it.screenIds.length) lines.push(`- 화면ID 후보: ${it.screenIds.map((x) => `\`${x}\``).join(", ")}`);
      if (it.images.length) {
        const imgs = it.images.slice(0, 6).map((x) => `\`${x.path}\``).join(", ");
        lines.push(`- 관련 이미지: ${imgs}${it.images.length > 6 ? " ..." : ""}`);
      }
      lines.push("");
      lines.push("### 이슈/요구 문장(발췌)");
      lines.push("");
      for (const s of it.issues) lines.push(`- ${mdEscape(s)}`);
      lines.push("");
    }
  }

  fs.mkdirSync(path.dirname(absOut), { recursive: true });
  fs.writeFileSync(absOut, lines.join("\n"), "utf8");
  console.log(`OK: wrote ${absOut}`);
}

main();

