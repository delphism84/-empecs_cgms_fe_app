const path = require("path");

function uniq(arr) {
  return Array.from(new Set(arr));
}

function toRel(p, base) {
  try {
    return path.relative(base, p) || p;
  } catch {
    return p;
  }
}

function extractPageIdsFromText(text) {
  const s = String(text || "");
  const re = /\b[A-Z]{2,3}_[0-9]{2}_[0-9]{2}\b/g;
  return s.match(re) || [];
}

function buildRequestDocument(extracted) {
  const base = extracted?.input || process.cwd();
  const files = extracted?.files || [];
  const manual = extracted?.manualReview || [];

  const allPageIds = [];
  for (const f of files) {
    if (f.kind === "xlsx") {
      for (const sh of f.sheets || []) allPageIds.push(...extractPageIdsFromText(sh.text));
    } else if (f.kind === "pptx") {
      for (const sl of f.slides || []) allPageIds.push(...extractPageIdsFromText(sl.text));
    }
  }

  const pageIds = uniq(allPageIds).sort();

  const lines = [];
  lines.push("# CGMS 앱 요구사항 프롬프트(자동 생성)");
  lines.push("");
  lines.push("> 이 문서는 `req-extracted.json`에서 추출한 텍스트를 바탕으로, LLM에 바로 넣을 수 있는 형태로 정리한 “요청문서/프롬프트”입니다.");
  lines.push("> 표/다이어그램/이미지 위주인 부분은 텍스트 추출이 불완전할 수 있으므로, 아래 '수동 확인 필요'를 먼저 보완하세요.");
  lines.push("");

  lines.push("## 입력 문서 인벤토리");
  lines.push("");
  for (const f of files) {
    const fileRel = toRel(f.file, base);
    if (f.kind === "xlsx") {
      lines.push(`- \`${fileRel}\` (xlsx, 시트 ${f.summary?.sheetCount ?? 0}개, 미디어 ${f.summary?.mediaCount ?? 0}개)`);
      const sheetNames = (f.sheets || []).map((s) => s.name);
      lines.push(`  - 시트: ${sheetNames.map((n) => `\`${n}\``).join(", ") || "(없음)"}`);
    } else if (f.kind === "pptx") {
      lines.push(`- \`${fileRel}\` (pptx, 슬라이드 ${f.summary?.slideCount ?? 0}장, 미디어 ${f.summary?.mediaCount ?? 0}개)`);
    } else {
      lines.push(`- \`${fileRel}\` (unknown)`);
    }
  }
  lines.push("");

  lines.push("## 수동 확인 필요(자동 분석 어려움)");
  lines.push("");
  if (!manual.length) {
    lines.push("- (없음)");
  } else {
    for (const m of manual) {
      const fileRel = toRel(m.file, base);
      const name = m.name ? ` / ${m.name}` : "";
      lines.push(`- **${m.type || "item"}**: \`${fileRel}\`${name} — ${m.reason || "수동 확인 필요"}`);
    }
  }
  lines.push("");

  lines.push("## 페이지/화면 ID 후보(텍스트에서 자동 검출)");
  lines.push("");
  lines.push("> 아래 목록은 문서 텍스트에서 패턴으로 검출한 값입니다. 누락/오검출 가능성이 있어 '후보'로만 사용하세요.");
  lines.push("");
  if (!pageIds.length) {
    lines.push("- (검출 없음)");
  } else {
    lines.push(pageIds.map((x) => `- \`${x}\``).join("\n"));
  }
  lines.push("");

  lines.push("## LLM 요청 프롬프트(그대로 복사해서 사용)");
  lines.push("");
  lines.push("```");
  lines.push("당신은 CGMS 앱의 기획/요구사항 분석가입니다.");
  lines.push("아래 [원문 추출 텍스트]를 근거로 다음 산출물을 작성하세요.");
  lines.push("");
  lines.push("1) 화면(페이지ID)별 요구사항 정리");
  lines.push("- 화면명, 목적, 주요 UI 구성요소, 입력/출력, 동작 시나리오, 예외/에러 케이스, 문구/라벨, 데이터 항목");
  lines.push("");
  lines.push("2) 미완료/오류/재확인 요청 목록");
  lines.push("- '구현 완료' 여부, 현재 문제, 재현 조건, 기대 동작, 관련 페이지ID/시트/슬라이드 출처 포함");
  lines.push("");
  lines.push("3) 질문 리스트");
  lines.push("- 요구사항이 모호하거나 서로 충돌하는 부분을 질문 형태로 정리");
  lines.push("");
  lines.push("4) 개발 티켓 초안");
  lines.push("- 기능 단위로 제목/설명/수용 기준(AC)/우선순위를 작성");
  lines.push("");
  lines.push("[원문 추출 텍스트]");
  lines.push("----");
  lines.push("```");
  lines.push("");

  lines.push("## 원문 추출 텍스트");
  lines.push("");

  for (const f of files) {
    const fileRel = toRel(f.file, base);
    lines.push(`### ${fileRel}`);
    lines.push("");

    if (f.kind === "xlsx") {
      for (const sh of f.sheets || []) {
        lines.push(`#### [xlsx 시트] ${sh.name}`);
        lines.push("");
        const aiSummaries = (sh.images || []).map((x) => x.ai?.summary).filter(Boolean);
        if (aiSummaries.length) {
          lines.push("AI 이미지 요약(있을 경우):");
          lines.push("");
          lines.push("```");
          lines.push(aiSummaries.slice(0, 3).join("\n\n---\n\n"));
          lines.push("```");
          lines.push("");
        }
        lines.push("```");
        lines.push((sh.text || "").trim() || "(텍스트 없음)");
        lines.push("```");
        lines.push("");
      }
    } else if (f.kind === "pptx") {
      for (const sl of f.slides || []) {
        lines.push(`#### [pptx 슬라이드 ${sl.index}] ${sl.title}`);
        lines.push("");
        const aiSummaries = (sl.images || []).map((x) => x.ai?.summary).filter(Boolean);
        if (aiSummaries.length) {
          lines.push("AI 이미지 요약(있을 경우):");
          lines.push("");
          lines.push("```");
          lines.push(aiSummaries.slice(0, 3).join("\n\n---\n\n"));
          lines.push("```");
          lines.push("");
        }
        lines.push("```");
        lines.push((sl.text || "").trim() || "(텍스트 없음)");
        lines.push("```");
        lines.push("");
      }
    }
  }

  return lines.join("\n");
}

module.exports = { buildRequestDocument };

