function decodeXmlEntities(s) {
  if (!s) return "";
  return String(s)
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&");
}

function normalizeWhitespace(s) {
  return String(s || "")
    .replace(/\u00A0/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/\s*\n\s*/g, "\n")
    .trim();
}

function safeSample(s, maxChars) {
  const txt = normalizeWhitespace(s || "");
  if (txt.length <= maxChars) return txt;
  return txt.slice(0, Math.max(0, maxChars - 20)) + "\n…(truncated)…";
}

module.exports = { decodeXmlEntities, normalizeWhitespace, safeSample };

