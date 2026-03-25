const path = require("path");
const { loadZip, readZipText, readZipBuffer, listZipPaths } = require("./zip");
const { decodeXmlEntities, normalizeWhitespace, safeSample } = require("./text");
const { extractImagesFromSlideXml } = require("./ooxml-images");
const { sha256, describeImage } = require("./ai");

function parseRelationshipsXml(relsXml) {
  const map = new Map();
  if (!relsXml) return map;
  const re = /<Relationship\b[^>]*\bId="([^"]+)"[^>]*\bTarget="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(relsXml))) map.set(m[1], m[2]);
  return map;
}

function parseSlideRidsFromPresentation(presentationXml) {
  const rids = [];
  if (!presentationXml) return rids;
  const re = /<p:sldId\b[^>]*\br:id="([^"]+)"[^>]*\/?>/g;
  let m;
  while ((m = re.exec(presentationXml))) rids.push(m[1]);
  return rids;
}

function extractAllAText(xml) {
  if (!xml) return "";
  const re = /<a:t\b[^>]*>([\s\S]*?)<\/a:t>/g;
  const parts = [];
  let m;
  while ((m = re.exec(xml))) parts.push(decodeXmlEntities(m[1]));
  return normalizeWhitespace(parts.join(" "));
}

function countPictures(xml) {
  if (!xml) return 0;
  const m1 = xml.match(/<[\w]+:pic\b/g) || [];
  const m2 = xml.match(/<pic\b/g) || [];
  return m1.length + m2.length;
}

function tryExtractTitle(xml) {
  if (!xml) return "";
  // Try to find a shape with placeholder type title/ctrTitle
  const spRe = /<p:sp\b[\s\S]*?<\/p:sp>/g;
  const phRe = /<p:ph\b[^>]*\btype="(title|ctrTitle)"/;
  const sps = xml.match(spRe) || [];
  for (const sp of sps) {
    if (!phRe.test(sp)) continue;
    const t = extractAllAText(sp);
    if (t) return t;
  }
  return "";
}

async function analyzePptx(fileAbs, opts) {
  const minTextCharsForReadable = opts?.minTextCharsForReadable ?? 20;
  const maxSampleCharsPerItem = opts?.maxSampleCharsPerItem ?? 1200;
  const ai = opts?.ai || { enabled: false };

  const zip = await loadZip(fileAbs);
  const errors = [];
  const manualReview = [];

  const presentationXml = await readZipText(zip, "ppt/presentation.xml");
  const presRelsXml = await readZipText(zip, "ppt/_rels/presentation.xml.rels");
  const relMap = parseRelationshipsXml(presRelsXml);
  const slideRids = parseSlideRidsFromPresentation(presentationXml);

  const mediaPaths = listZipPaths(zip, "ppt/media/");
  const mediaCount = mediaPaths.filter((p) => !p.endsWith("/")).length;

  const slides = [];
  for (let i = 0; i < slideRids.length; i++) {
    const rid = slideRids[i];
    const target = relMap.get(rid);
    if (!target) {
      errors.push({
        file: fileAbs,
        where: "pptx.presentation.rels",
        message: `슬라이드 대상 경로를 찾을 수 없음 (rid=${rid})`,
      });
      manualReview.push({
        file: fileAbs,
        type: "pptx-slide",
        name: `Slide ${i + 1}`,
        reason: "슬라이드 경로 매핑 실패(수동 확인 필요)",
      });
      continue;
    }

    const slidePath = "ppt/" + target.replace(/^\//, "");
    const slideXml = await readZipText(zip, slidePath);
    const slideRelsPath = slidePath.replace("ppt/slides/", "ppt/slides/_rels/") + ".rels";
    const slideRelsXml = await readZipText(zip, slideRelsPath);
    const slideImages = extractImagesFromSlideXml({
      slideXml,
      slideRelsXml,
      slideSourceDir: path.posix.dirname(slidePath),
    });

    const text = extractAllAText(slideXml);
    const textChars = text.replace(/\s+/g, "").length;
    const picCount = countPictures(slideXml);
    const title = tryExtractTitle(slideXml) || `Slide ${i + 1}`;

    const imageAnalyses = [];
    const flagged = (textChars < minTextCharsForReadable && picCount > 0) || (!slideXml || slideXml.length === 0);
    const shouldAiAnalyzeImages =
      !!ai?.enabled && (!ai.onlyManualReview || flagged) && Array.isArray(slideImages) && slideImages.length > 0;

    if (shouldAiAnalyzeImages) {
      const selected = slideImages.slice(0, Math.max(0, ai.maxImagesPerItem ?? 3));
      for (const imgPath of selected) {
        if (ai.usage && ai.usage.analyzedImages >= (ai.maxImagesTotal ?? 25)) {
          if (ai.usage) ai.usage.skippedImages += 1;
          imageAnalyses.push({ path: imgPath, skipped: true, reason: "AI 이미지 분석 최대치 초과(--ai-max-images)" });
          continue;
        }
        try {
          const buf = await readZipBuffer(zip, imgPath);
          if (!buf) {
            if (ai.usage) ai.usage.skippedImages += 1;
            imageAnalyses.push({ path: imgPath, skipped: true, reason: "이미지 엔트리를 읽을 수 없음" });
            continue;
          }
          if (buf.length > 5 * 1024 * 1024) {
            if (ai.usage) ai.usage.skippedImages += 1;
            imageAnalyses.push({ path: imgPath, skipped: true, reason: "이미지 용량이 큼(>5MB)" });
            continue;
          }
          const h = sha256(buf);
          const cached = ai.cache?.get(h);
          if (cached) {
            imageAnalyses.push({ path: imgPath, cached: true, hash: h, ai: cached });
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
            contextText: `파일: ${path.basename(fileAbs)} / 슬라이드: ${i + 1} (${title})`,
          });
          const payload = r.ok ? r.data : { summary: "(AI가 JSON으로 응답하지 않아 원문을 raw로 저장)", raw: r.raw };
          ai.cache?.set(h, payload);
          imageAnalyses.push({ path: imgPath, cached: false, hash: h, ai: payload });
          if (ai.usage) ai.usage.analyzedImages += 1;
        } catch (e) {
          errors.push({
            file: fileAbs,
            where: `pptx.ai(slide ${i + 1}, ${imgPath})`,
            message: e && e.message ? e.message : String(e),
          });
          imageAnalyses.push({ path: imgPath, skipped: true, reason: "AI 이미지 분석 중 예외" });
          if (ai.usage) ai.usage.skippedImages += 1;
        }
      }
    }
    if (flagged) {
      const parts = [];
      if (textChars < minTextCharsForReadable) parts.push(`텍스트가 매우 적음(${textChars}자)`);
      if (picCount > 0) parts.push(`이미지/그림 요소 ${picCount}개`);
      if (!slideXml) parts.push("슬라이드 XML 읽기 실패");
      const aiSummary = imageAnalyses.find((x) => x.ai?.summary)?.ai?.summary;
      if (aiSummary) parts.push(`AI 이미지 요약: ${String(aiSummary).slice(0, 200)}`);
      manualReview.push({
        file: fileAbs,
        type: "pptx-slide",
        name: title,
        reason: parts.join(", ") || "이미지 위주로 추정(수동 확인 필요)",
        stats: { textChars, picCount, slidePath, mediaCount, slideImages: slideImages.length },
      });
    }

    slides.push({
      index: i + 1,
      title,
      slidePath,
      stats: { textChars, picCount, mediaCount },
      text,
      images: imageAnalyses,
      sample: safeSample(text, maxSampleCharsPerItem),
    });
  }

  if (slides.length === 0) {
    manualReview.push({
      file: fileAbs,
      type: "pptx-file",
      name: path.basename(fileAbs),
      reason: "슬라이드 정보를 추출하지 못함(수동 확인 필요)",
    });
  }

  return {
    file: fileAbs,
    kind: "pptx",
    summary: {
      slideCount: slideRids.length,
      mediaCount,
    },
    slides,
    manualReview,
    errors,
  };
}

module.exports = { analyzePptx };

