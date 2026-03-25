const path = require("path");
const { loadZip, readZipText, readZipBuffer, listZipPaths } = require("./zip");
const { decodeXmlEntities, normalizeWhitespace, safeSample } = require("./text");
const { extractDrawingTargetFromSheetRels, extractImagesFromDrawingXml } = require("./ooxml-images");
const { sha256, describeImage } = require("./ai");

function parseRelationshipsXml(relsXml) {
  const map = new Map();
  if (!relsXml) return map;
  const re = /<Relationship\b[^>]*\bId="([^"]+)"[^>]*\bTarget="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(relsXml))) {
    map.set(m[1], m[2]);
  }
  return map;
}

function parseWorkbookSheets(workbookXml) {
  const sheets = [];
  if (!workbookXml) return sheets;
  const re = /<sheet\b[^>]*\bname="([^"]+)"[^>]*\br:id="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(workbookXml))) {
    sheets.push({ name: decodeXmlEntities(m[1]), rid: m[2] });
  }
  return sheets;
}

function parseSharedStrings(sharedStringsXml) {
  const out = [];
  if (!sharedStringsXml) return out;
  const siRe = /<si\b[\s\S]*?<\/si>/g;
  const tRe = /<t\b[^>]*>([\s\S]*?)<\/t>/g;
  const sis = sharedStringsXml.match(siRe) || [];
  for (const si of sis) {
    const parts = [];
    let m;
    while ((m = tRe.exec(si))) parts.push(decodeXmlEntities(m[1]));
    out.push(normalizeWhitespace(parts.join("")));
  }
  return out;
}

function extractSheetTexts(sheetXml, sharedStrings) {
  const texts = [];
  if (!sheetXml) return texts;

  // inline strings
  const inlineRe = /<c\b[^>]*\bt="inlineStr"[^>]*>[\s\S]*?<t\b[^>]*>([\s\S]*?)<\/t>[\s\S]*?<\/c>/g;
  let m;
  while ((m = inlineRe.exec(sheetXml))) {
    const v = normalizeWhitespace(decodeXmlEntities(m[1]));
    if (v) texts.push(v);
  }

  // shared string or other v values
  const cellRe = /<c\b([^>]*)>[\s\S]*?<v\b[^>]*>([\s\S]*?)<\/v>[\s\S]*?<\/c>/g;
  while ((m = cellRe.exec(sheetXml))) {
    const attrs = m[1] || "";
    const rawV = decodeXmlEntities(m[2]);
    const t = /t="([^"]+)"/.exec(attrs)?.[1] || "";

    if (t === "s") {
      const idx = Number(rawV);
      const v = sharedStrings[idx] || "";
      if (v) texts.push(v);
    } else if (t === "str") {
      const v = normalizeWhitespace(rawV);
      if (v) texts.push(v);
    } else {
      const v = normalizeWhitespace(rawV);
      if (v) texts.push(v);
    }
  }

  return texts;
}

function sheetHasDrawing(sheetXml, sheetRelsXml) {
  if (sheetXml && /<drawing\b/i.test(sheetXml)) return true;
  if (sheetRelsXml && /\/drawing/i.test(sheetRelsXml)) return true;
  return false;
}

function countPicsInDrawingXml(drawingXml) {
  if (!drawingXml) return 0;
  const m1 = drawingXml.match(/<xdr:pic\b/g) || [];
  const m2 = drawingXml.match(/<pic\b/g) || [];
  // avoid double count if xdr:pic already matched as <pic (it won't because includes prefix)
  return m1.length + m2.length;
}

async function analyzeImagesForSheet({ zip, imageEntryPaths, ai, contextText, errors }) {
  const results = [];
  if (!ai?.enabled) return results;

  const maxPerItem = ai.maxImagesPerItem ?? 3;
  const selected = imageEntryPaths.slice(0, Math.max(0, maxPerItem));
  for (const imgPath of selected) {
    // global budget
    if (ai.usage && ai.usage.analyzedImages >= (ai.maxImagesTotal ?? 25)) {
      if (ai.usage) ai.usage.skippedImages += 1;
      results.push({ path: imgPath, skipped: true, reason: "AI 이미지 분석 최대치 초과(--ai-max-images)" });
      continue;
    }

    try {
      const buf = await readZipBuffer(zip, imgPath);
      if (!buf) {
        results.push({ path: imgPath, skipped: true, reason: "이미지 엔트리를 읽을 수 없음" });
        if (ai.usage) ai.usage.skippedImages += 1;
        continue;
      }
      if (buf.length > 5 * 1024 * 1024) {
        results.push({ path: imgPath, skipped: true, reason: "이미지 용량이 큼(>5MB)" });
        if (ai.usage) ai.usage.skippedImages += 1;
        continue;
      }

      const h = sha256(buf);
      const cached = ai.cache?.get(h);
      if (cached) {
        results.push({ path: imgPath, cached: true, hash: h, ai: cached });
        if (ai.usage) ai.usage.analyzedImages += 1;
        continue;
      }

      const r = await describeImage({
        provider: ai.provider,
        openaiApiKey: ai.openaiApiKey,
        geminiApiKey: ai.geminiApiKey,
        model: ai.model,
        imageBuffer: buf,
        imagePath: imgPath,
        contextText,
      });
      const payload = r.ok ? r.data : { summary: "(AI가 JSON으로 응답하지 않아 원문을 raw로 저장)", raw: r.raw };
      ai.cache?.set(h, payload);
      results.push({ path: imgPath, cached: false, hash: h, ai: payload });
      if (ai.usage) ai.usage.analyzedImages += 1;
    } catch (e) {
      errors.push({
        file: "(embedded)",
        where: `xlsx.ai(${imgPath})`,
        message: e && e.message ? e.message : String(e),
      });
      results.push({ path: imgPath, skipped: true, reason: "AI 이미지 분석 중 예외" });
      if (ai.usage) ai.usage.skippedImages += 1;
    }
  }
  return results;
}

async function analyzeXlsx(fileAbs, opts) {
  const minTextCharsForReadable = opts?.minTextCharsForReadable ?? 20;
  const maxSampleCharsPerItem = opts?.maxSampleCharsPerItem ?? 1200;
  const ai = opts?.ai || { enabled: false };

  const zip = await loadZip(fileAbs);
  const errors = [];
  const manualReview = [];

  const workbookXml = await readZipText(zip, "xl/workbook.xml");
  const workbookRelsXml = await readZipText(zip, "xl/_rels/workbook.xml.rels");
  const relMap = parseRelationshipsXml(workbookRelsXml);
  const sheets = parseWorkbookSheets(workbookXml);

  const sharedStringsXml = await readZipText(zip, "xl/sharedStrings.xml");
  const sharedStrings = parseSharedStrings(sharedStringsXml);

  const mediaPaths = listZipPaths(zip, "xl/media/");
  const mediaCount = mediaPaths.filter((p) => !p.endsWith("/")).length;

  const sheetResults = [];
  for (const sheet of sheets) {
    const target = relMap.get(sheet.rid);
    if (!target) {
      errors.push({
        file: fileAbs,
        where: "xlsx.workbook.rels",
        message: `시트 대상 경로를 찾을 수 없음 (rid=${sheet.rid}, name=${sheet.name})`,
      });
      manualReview.push({
        file: fileAbs,
        type: "xlsx-sheet",
        name: sheet.name,
        reason: "시트 경로 매핑 실패(수동 확인 필요)",
      });
      continue;
    }

    const sheetPath = "xl/" + target.replace(/^\//, "");
    const sheetXml = await readZipText(zip, sheetPath);
    const sheetRelsPath = sheetPath.replace("xl/worksheets/", "xl/worksheets/_rels/") + ".rels";
    const sheetRelsXml = await readZipText(zip, sheetRelsPath);

    const hasDrawing = sheetHasDrawing(sheetXml, sheetRelsXml);

    // If there's a drawing relationship, follow it to count pics and map image paths.
    let drawingPicCount = 0;
    let drawingImages = [];
    try {
      if (sheetRelsXml) {
        const drawTarget = extractDrawingTargetFromSheetRels(sheetRelsXml);
        if (drawTarget) {
          const drawingPath = "xl/" + drawTarget.replace(/^\.\.\//, "");
          const drawingXml = await readZipText(zip, drawingPath);
          drawingPicCount = countPicsInDrawingXml(drawingXml);

          const drawingRelsPath = drawingPath.replace("xl/drawings/", "xl/drawings/_rels/") + ".rels";
          const drawingRelsXml = await readZipText(zip, drawingRelsPath);
          drawingImages = extractImagesFromDrawingXml({
            drawingXml,
            drawingRelsXml,
            drawingSourceDir: path.posix.dirname(drawingPath),
          });
        }
      }
    } catch (e) {
      errors.push({
        file: fileAbs,
        where: `xlsx.drawing(${sheet.name})`,
        message: e && e.message ? e.message : String(e),
      });
    }

    const texts = extractSheetTexts(sheetXml, sharedStrings);
    const combined = normalizeWhitespace(texts.join("\n"));
    const textChars = combined.replace(/\s+/g, "").length;

    const flagged =
      (textChars < minTextCharsForReadable && (hasDrawing || drawingPicCount > 0 || mediaCount > 0)) ||
      (!sheetXml || sheetXml.length === 0);

    const shouldAiAnalyzeImages =
      !!ai?.enabled &&
      (!ai.onlyManualReview || flagged) &&
      Array.isArray(drawingImages) &&
      drawingImages.length > 0;

    const imageAnalyses = shouldAiAnalyzeImages
      ? await analyzeImagesForSheet({
          zip,
          imageEntryPaths: drawingImages,
          ai,
          contextText: `파일: ${path.basename(fileAbs)} / 시트: ${sheet.name}`,
          errors,
        })
      : [];

    if (flagged) {
      const parts = [];
      if (textChars < minTextCharsForReadable) parts.push(`텍스트가 매우 적음(${textChars}자)`);
      if (drawingPicCount > 0) parts.push(`그림 요소 ${drawingPicCount}개(드로잉)`);
      if (hasDrawing && drawingPicCount === 0) parts.push("드로잉/개체 포함 가능성");
      if (mediaCount > 0) parts.push(`파일 내 미디어 ${mediaCount}개(xl/media)`);
      if (!sheetXml) parts.push("시트 XML 읽기 실패");
      const aiSummary = imageAnalyses.find((x) => x.ai?.summary)?.ai?.summary;
      if (aiSummary) parts.push(`AI 이미지 요약: ${String(aiSummary).slice(0, 200)}`);
      manualReview.push({
        file: fileAbs,
        type: "xlsx-sheet",
        name: sheet.name,
        reason: parts.join(", ") || "이미지/도형 위주로 추정(수동 확인 필요)",
        stats: { textChars, hasDrawing, drawingPicCount, mediaCount, sheetPath, drawingImages: drawingImages.length },
      });
    }

    sheetResults.push({
      name: sheet.name,
      sheetPath,
      stats: { textChars, textItems: texts.length, hasDrawing, drawingPicCount, mediaCount },
      text: combined,
      images: imageAnalyses,
      sample: safeSample(combined, maxSampleCharsPerItem),
    });
  }

  // If there are no parsed sheets, force manual review.
  if (sheetResults.length === 0) {
    manualReview.push({
      file: fileAbs,
      type: "xlsx-file",
      name: path.basename(fileAbs),
      reason: "시트 정보를 추출하지 못함(수동 확인 필요)",
    });
  }

  return {
    file: fileAbs,
    kind: "xlsx",
    summary: {
      sheetCount: sheets.length,
      mediaCount,
    },
    sheets: sheetResults,
    manualReview,
    errors,
  };
}

module.exports = { analyzeXlsx };

