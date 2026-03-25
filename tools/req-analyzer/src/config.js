const fs = require("fs");
const path = require("path");

function stripJsonc(s) {
  const text = String(s || "");
  // remove /* ... */ then //... (best-effort)
  const noBlock = text.replace(/\/\*[\s\S]*?\*\//g, "");
  const noLine = noBlock.replace(/(^|\s)\/\/.*$/gm, "$1");
  return noLine;
}

function tryReadJsonc(fileAbs) {
  try {
    if (!fs.existsSync(fileAbs)) return null;
    const raw = fs.readFileSync(fileAbs, "utf8");
    const json = stripJsonc(raw);
    return JSON.parse(json);
  } catch {
    return null;
  }
}

function resolveConfigPath({ cwd, inputAbs, explicitConfigPath }) {
  if (explicitConfigPath) return path.resolve(cwd, explicitConfigPath);

  const candidates = [];
  // 1) 현재 작업 디렉토리
  candidates.push(path.join(cwd, "req-analyzer.config.local.jsonc"));
  candidates.push(path.join(cwd, "req-analyzer.config.local.json"));
  candidates.push(path.join(cwd, "req-analyzer.config.jsonc"));
  candidates.push(path.join(cwd, "req-analyzer.config.json"));

  // 2) 입력 폴더가 있으면 그 안
  if (inputAbs) {
    try {
      const stat = fs.existsSync(inputAbs) ? fs.statSync(inputAbs) : null;
      if (stat?.isDirectory()) {
        candidates.push(path.join(inputAbs, "req-analyzer.config.local.jsonc"));
        candidates.push(path.join(inputAbs, "req-analyzer.config.local.json"));
        candidates.push(path.join(inputAbs, "req-analyzer.config.jsonc"));
        candidates.push(path.join(inputAbs, "req-analyzer.config.json"));
      }
    } catch {
      // ignore
    }
  }

  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

function mergeDeep(base, patch) {
  if (!patch || typeof patch !== "object") return base;
  const out = Array.isArray(base) ? [...base] : { ...(base || {}) };
  for (const [k, v] of Object.entries(patch)) {
    if (v && typeof v === "object" && !Array.isArray(v) && base && typeof base[k] === "object" && !Array.isArray(base[k])) {
      out[k] = mergeDeep(base[k], v);
    } else {
      out[k] = v;
    }
  }
  return out;
}

module.exports = { tryReadJsonc, resolveConfigPath, mergeDeep };

