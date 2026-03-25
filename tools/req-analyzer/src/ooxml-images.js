const path = require("path");

const SUPPORTED_IMAGE_RE = /\.(png|jpe?g|webp|gif)$/i;

function normalizeTarget(baseDir, target) {
  // baseDir: 관계의 "Source Part" 디렉토리
  // 예) slide1.xml.rels 의 Source Part는 /ppt/slides/slide1.xml 이므로 baseDir은 "ppt/slides"
  //     drawing1.xml.rels 의 Source Part는 /xl/drawings/drawing1.xml 이므로 baseDir은 "xl/drawings"
  // target: e.g. "../media/image1.png"
  if (!target) return null;
  const t = String(target).replace(/\\/g, "/");
  if (t.startsWith("/")) return t.slice(1);
  const norm = path.posix.normalize(path.posix.join(baseDir, t));
  return norm;
}

function parseRelationshipsXml(relsXml) {
  const rels = new Map();
  if (!relsXml) return rels;
  const re = /<Relationship\b[^>]*\bId="([^"]+)"[^>]*\bTarget="([^"]+)"[^>]*>/g;
  let m;
  while ((m = re.exec(relsXml))) rels.set(m[1], m[2]);
  return rels;
}

function extractBlipEmbeds(xml) {
  if (!xml) return [];
  const embeds = [];
  const re = /<a:blip\b[^>]*\br:embed="([^"]+)"[^>]*\/?>/g;
  let m;
  while ((m = re.exec(xml))) embeds.push(m[1]);
  return embeds;
}

function extractImagesFromSlideXml({ slideXml, slideRelsXml, slideSourceDir }) {
  const rels = parseRelationshipsXml(slideRelsXml);
  const embeds = extractBlipEmbeds(slideXml);
  const out = [];
  for (const rid of embeds) {
    const target = rels.get(rid);
    const abs = normalizeTarget(slideSourceDir, target);
    if (abs && SUPPORTED_IMAGE_RE.test(abs)) out.push(abs);
  }
  return Array.from(new Set(out));
}

function extractDrawingTargetFromSheetRels(sheetRelsXml) {
  if (!sheetRelsXml) return null;
  const re = /<Relationship\b[^>]*\bType="[^"]*\/drawing"[^>]*\bTarget="([^"]+)"[^>]*>/i;
  return sheetRelsXml.match(re)?.[1] || null;
}

function extractImagesFromDrawingXml({ drawingXml, drawingRelsXml, drawingSourceDir }) {
  const rels = parseRelationshipsXml(drawingRelsXml);
  const embeds = extractBlipEmbeds(drawingXml);
  const out = [];
  for (const rid of embeds) {
    const target = rels.get(rid);
    const abs = normalizeTarget(drawingSourceDir, target);
    if (abs && SUPPORTED_IMAGE_RE.test(abs)) out.push(abs);
  }
  return Array.from(new Set(out));
}

module.exports = {
  SUPPORTED_IMAGE_RE,
  normalizeTarget,
  parseRelationshipsXml,
  extractBlipEmbeds,
  extractImagesFromSlideXml,
  extractDrawingTargetFromSheetRels,
  extractImagesFromDrawingXml,
};

