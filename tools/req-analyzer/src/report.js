const path = require("path");

function toRel(p, base) {
  try {
    return path.relative(base, p) || p;
  } catch {
    return p;
  }
}

function renderMarkdownReport(extracted) {
  const base = extracted?.input || process.cwd();
  const lines = [];
  lines.push("# 요구사항 문서 분석 리포트");
  lines.push("");
  lines.push(`- 생성 시각: ${extracted.generatedAt}`);
  lines.push(`- 입력 경로: \`${extracted.input}\``);
  lines.push("");

  const files = extracted.files || [];
  const manual = extracted.manualReview || [];
  const errs = extracted.errors || [];

  lines.push("## 파일 요약");
  lines.push("");
  lines.push("| 파일 | 타입 | 시트/슬라이드 수 | 미디어 수 | 수동확인 항목 | 에러 |");
  lines.push("|---|---:|---:|---:|---:|---:|");
  for (const f of files) {
    const fileRel = toRel(f.file, base);
    const kind = f.kind || "unknown";
    const count = kind === "xlsx" ? (f.summary?.sheetCount ?? 0) : kind === "pptx" ? (f.summary?.slideCount ?? 0) : 0;
    const media = f.summary?.mediaCount ?? 0;
    const mr = (f.manualReview || []).length;
    const e = (f.errors || []).length;
    lines.push(`| \`${fileRel}\` | ${kind} | ${count} | ${media} | ${mr} | ${e} |`);
  }
  lines.push("");

  if (extracted.aiUsage?.enabled) {
    lines.push("## AI 이미지 분석 요약");
    lines.push("");
    lines.push(
      `- 모델: \`${extracted.aiUsage.model}\`\n- 최대 이미지(전체): ${extracted.aiUsage.maxImagesTotal}\n- 최대 이미지(항목당): ${extracted.aiUsage.maxImagesPerItem}\n- 분석한 이미지: ${extracted.aiUsage.analyzedImages}\n- 건너뜀: ${extracted.aiUsage.skippedImages}`
    );
    lines.push("");
  }

  lines.push("## 수동 확인 필요(중요)");
  lines.push("");
  lines.push("아래 항목들은 **텍스트가 매우 적거나(이미지/도형 위주로 추정), 관계 파일/시트 매핑 문제 등으로 자동 분석 정확도가 낮을 수 있어** 수동 확인이 필요합니다.");
  lines.push("");
  if (manual.length === 0) {
    lines.push("- (없음)");
  } else {
    for (const m of manual) {
      const fileRel = toRel(m.file, base);
      const name = m.name ? ` / ${m.name}` : "";
      lines.push(`- **${m.type || "item"}**: \`${fileRel}\`${name} — ${m.reason || "수동 확인 필요"}`);
    }
  }
  lines.push("");

  if (errs.length) {
    lines.push("## 파싱 에러");
    lines.push("");
    for (const e of errs) {
      const fileRel = toRel(e.file, base);
      lines.push(`- \`${fileRel}\` (${e.where || "unknown"}): ${e.message || ""}`.trim());
    }
    lines.push("");
  }

  lines.push("## 상세 추출 결과");
  lines.push("");

  for (const f of files) {
    const fileRel = toRel(f.file, base);
    lines.push(`### ${fileRel}`);
    lines.push("");

    if (f.kind === "xlsx") {
      lines.push(`- 타입: xlsx`);
      lines.push(`- 시트 수: ${f.summary?.sheetCount ?? 0}`);
      lines.push(`- 파일 내 미디어(xl/media) 수: ${f.summary?.mediaCount ?? 0}`);
      lines.push("");
      for (const s of f.sheets || []) {
        lines.push(`#### [시트] ${s.name}`);
        lines.push("");
        const st = s.stats || {};
        lines.push(`- 텍스트 항목 수: ${st.textItems ?? 0}`);
        lines.push(`- 텍스트 글자수(공백 제외): ${st.textChars ?? 0}`);
        lines.push(`- 드로잉/개체 포함: ${st.hasDrawing ? "예" : "아니오"} (드로잉 내 그림요소: ${st.drawingPicCount ?? 0})`);
        lines.push(`- 파일 내 미디어(xl/media) 수: ${st.mediaCount ?? 0}`);
        if (Array.isArray(s.images) && s.images.length) {
          const aiSummaries = s.images
            .map((img) => img.ai?.summary)
            .filter(Boolean)
            .slice(0, 2);
          if (aiSummaries.length) lines.push(`- AI 이미지 요약(일부): ${aiSummaries.map((x) => String(x).slice(0, 140)).join(" / ")}`);
        }
        lines.push("");
        lines.push("추출 텍스트(샘플):");
        lines.push("");
        lines.push("```");
        lines.push((s.sample || "").trim() || "(텍스트 없음)");
        lines.push("```");
        lines.push("");
      }
    } else if (f.kind === "pptx") {
      lines.push(`- 타입: pptx`);
      lines.push(`- 슬라이드 수: ${f.summary?.slideCount ?? 0}`);
      lines.push(`- 파일 내 미디어(ppt/media) 수: ${f.summary?.mediaCount ?? 0}`);
      lines.push("");
      for (const s of f.slides || []) {
        lines.push(`#### [슬라이드 ${s.index}] ${s.title}`);
        lines.push("");
        const st = s.stats || {};
        lines.push(`- 텍스트 글자수(공백 제외): ${st.textChars ?? 0}`);
        lines.push(`- 이미지/그림 요소 수(추정): ${st.picCount ?? 0}`);
        lines.push(`- 파일 내 미디어(ppt/media) 수: ${st.mediaCount ?? 0}`);
        if (Array.isArray(s.images) && s.images.length) {
          const aiSummaries = s.images
            .map((img) => img.ai?.summary)
            .filter(Boolean)
            .slice(0, 2);
          if (aiSummaries.length) lines.push(`- AI 이미지 요약(일부): ${aiSummaries.map((x) => String(x).slice(0, 140)).join(" / ")}`);
        }
        lines.push("");
        lines.push("추출 텍스트(샘플):");
        lines.push("");
        lines.push("```");
        lines.push((s.sample || "").trim() || "(텍스트 없음)");
        lines.push("```");
        lines.push("");
      }
    } else {
      lines.push("- (지원되지 않는 파일 타입)");
      lines.push("");
    }
  }

  lines.push("## 다음 단계(LLM 요약용 입력 예시)");
  lines.push("");
  lines.push("원하면 `req-extracted.json`의 텍스트를 기반으로 LLM에 아래 형태로 요약을 요청하세요(자동 추출이 어려운 항목은 위 '수동 확인 필요'를 먼저 보완).");
  lines.push("");
  lines.push("```");
  lines.push("당신은 앱 기획/요구사항 분석가입니다.");
  lines.push("다음 텍스트(엑셀/슬라이드 추출본)를 바탕으로:");
  lines.push("- 미완료 기능/화면 요구사항을 기능 단위로 정리");
  lines.push("- 화면(스크린)별 구성요소/동작/예외/문구를 표로 정리");
  lines.push("- 우선순위/의존성/미정사항/질문 리스트를 분리");
  lines.push("");
  lines.push("[추출 텍스트]");
  lines.push("...붙여넣기...");
  lines.push("```");
  lines.push("");

  return lines.join("\n");
}

module.exports = { renderMarkdownReport };

