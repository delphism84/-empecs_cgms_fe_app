#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs");
const path = require("path");

// Load local .env (do not print secrets)
try {
  require("dotenv").config({ path: path.resolve(__dirname, "..", ".env") });
  // support legacy lowercase keys in .env
  if (!process.env.GEMINI_API_KEY && process.env.gemini_api_key) process.env.GEMINI_API_KEY = process.env.gemini_api_key;
  // gemini_api_engine은 이미지 "생성"용으로 쓰일 수 있어, 비전(분석) 모델로는 그대로 쓰지 않는다.
  if (!process.env.GEMINI_IMAGE_GEN_MODEL && process.env.gemini_api_engine) process.env.GEMINI_IMAGE_GEN_MODEL = process.env.gemini_api_engine;
} catch (_) {}

const { analyzeOfficeFile } = require("./office");
const { walkFiles } = require("./walk");
const { ensureDir, safeWriteFile } = require("./io");
const { renderMarkdownReport } = require("./report");
const { buildRequestDocument } = require("./requestdoc");
const { createAiCache } = require("./ai");
const { tryReadJsonc, resolveConfigPath, mergeDeep } = require("./config");

function redactSecrets(obj) {
  const seen = new WeakSet();
  const walk = (v) => {
    if (!v || typeof v !== "object") return v;
    if (seen.has(v)) return v;
    seen.add(v);
    if (Array.isArray(v)) return v.map(walk);
    const out = {};
    for (const [k, val] of Object.entries(v)) {
      const lk = k.toLowerCase();
      if (lk.includes("apikey") || lk.includes("api_key") || lk === "key" || lk.includes("token")) {
        out[k] = val ? "***redacted***" : val;
      } else {
        out[k] = walk(val);
      }
    }
    return out;
  };
  return walk(obj);
}

function parseArgs(argv) {
  const args = argv.slice(2);
  const out = {
    inputPath: null,
    outputDir: null,
    maxSampleCharsPerItem: 1200,
    minTextCharsForReadable: 20,
    ai: false,
    aiModel: process.env.OPENAI_VISION_MODEL || "gpt-4o-mini",
    aiMaxImagesTotal: 25,
    aiMaxImagesPerItem: 3,
    aiOnlyManual: false,
    configPath: null,
  };
  const provided = {};

  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (!a) continue;
    if (!out.inputPath && !a.startsWith("--")) {
      out.inputPath = a;
      provided.inputPath = true;
      continue;
    }
    if (a === "--config") {
      out.configPath = args[++i];
      provided.configPath = true;
    } else if (a === "--out") {
      out.outputDir = args[++i];
      provided.outputDir = true;
    } else if (a === "--max-sample-chars") {
      out.maxSampleCharsPerItem = Number(args[++i] || out.maxSampleCharsPerItem);
      provided.maxSampleCharsPerItem = true;
    } else if (a === "--min-text-chars") {
      out.minTextCharsForReadable = Number(args[++i] || out.minTextCharsForReadable);
      provided.minTextCharsForReadable = true;
    } else if (a === "--ai") {
      out.ai = true;
      provided.ai = true;
    } else if (a === "--ai-only-manual") {
      out.aiOnlyManual = true;
      provided.aiOnlyManual = true;
    } else if (a === "--ai-model") {
      out.aiModel = args[++i] || out.aiModel;
      provided.aiModel = true;
    } else if (a === "--ai-max-images") {
      out.aiMaxImagesTotal = Number(args[++i] || out.aiMaxImagesTotal);
      provided.aiMaxImagesTotal = true;
    } else if (a === "--ai-max-per-item") {
      out.aiMaxImagesPerItem = Number(args[++i] || out.aiMaxImagesPerItem);
      provided.aiMaxImagesPerItem = true;
    }
    else if (a === "--help" || a === "-h") out.help = true;
  }
  return { args: out, provided };
}

function usage() {
  return [
    "req-analyze <path-to-req-folder-or-file> [--config <path>] [--out <output-dir>] [--min-text-chars N] [--max-sample-chars N] [--ai] [--ai-only-manual] [--ai-model <model>] [--ai-max-images N] [--ai-max-per-item N]",
    "",
    "Examples:",
    "  req-analyze ../../req/req1",
    "  req-analyze ../../req/req1 --out ../../req/req1/_analysis",
    "  req-analyze ../../req/req1 --ai",
    "  req-analyze ../../req/req1 --ai-only-manual --ai-max-images 125",
    "  req-analyze ../../req/req1 --config req-analyzer.config.jsonc",
  ].join("\n");
}

async function main() {
  const parsed = parseArgs(process.argv);
  const cli = parsed.args;
  const provided = parsed.provided;
  if (cli.help || !cli.inputPath) {
    console.log(usage());
    process.exit(cli.help ? 0 : 1);
  }

  const inputAbs = path.resolve(process.cwd(), cli.inputPath);
  const inputStat = fs.existsSync(inputAbs) ? fs.statSync(inputAbs) : null;
  if (!inputStat) {
    console.error(`Input not found: ${inputAbs}`);
    process.exit(1);
  }

  // Load config (JSON/JSONC) if present.
  const configPath = resolveConfigPath({ cwd: process.cwd(), inputAbs, explicitConfigPath: cli.configPath });
  const fileConfig = configPath ? (tryReadJsonc(configPath) || {}) : {};

  const defaults = {
    outputDir: null,
    maxSampleCharsPerItem: 1200,
    minTextCharsForReadable: 20,
    ai: {
      enabled: false,
      model: process.env.OPENAI_VISION_MODEL || "gpt-4o-mini",
      maxImagesTotal: 25,
      maxImagesPerItem: 3,
      onlyManualReview: false,
    },
  };

  // Compose effective config: defaults <- fileConfig
  const merged = mergeDeep(defaults, fileConfig);

  // Apply CLI overrides if explicitly provided
  if (provided.outputDir) merged.outputDir = cli.outputDir;
  if (provided.maxSampleCharsPerItem) merged.maxSampleCharsPerItem = cli.maxSampleCharsPerItem;
  if (provided.minTextCharsForReadable) merged.minTextCharsForReadable = cli.minTextCharsForReadable;
  if (provided.ai) merged.ai.enabled = true;
  if (provided.aiOnlyManual) merged.ai.onlyManualReview = true;
  if (provided.aiModel) merged.ai.model = cli.aiModel;
  if (provided.aiMaxImagesTotal) merged.ai.maxImagesTotal = cli.aiMaxImagesTotal;
  if (provided.aiMaxImagesPerItem) merged.ai.maxImagesPerItem = cli.aiMaxImagesPerItem;

  const outputDirAbs = path.resolve(
    process.cwd(),
    merged.outputDir
      ? (inputStat.isDirectory() ? path.join(inputAbs, merged.outputDir) : merged.outputDir)
      : inputStat.isDirectory()
        ? path.join(inputAbs, "_analysis")
        : path.join(path.dirname(inputAbs), "_analysis")
  );
  ensureDir(outputDirAbs);

  const provider = (merged.ai?.provider || (process.env.GEMINI_API_KEY ? "gemini" : "openai")).toLowerCase();
  const openaiApiKey = merged.ai?.openaiApiKey || merged.ai?.apiKey || process.env.OPENAI_API_KEY;
  const geminiApiKey = merged.ai?.geminiApiKey || process.env.GEMINI_API_KEY;
  const modelFromConfig = merged.ai?.model;
  const model =
    provider === "gemini"
      ? (modelFromConfig && /^gpt-/i.test(modelFromConfig) ? undefined : modelFromConfig) ||
        process.env.GEMINI_VISION_MODEL ||
        process.env.GEMINI_MODEL ||
        "gemini-2.5-flash-image"
      : modelFromConfig || process.env.OPENAI_VISION_MODEL || "gpt-4o-mini";

  if (merged.ai?.enabled) {
    if (provider === "gemini" && !geminiApiKey) {
      console.error("AI가 활성화되어 있지만 Gemini API 키를 찾지 못했습니다. (.env의 gemini_api_key/GEMINI_API_KEY 또는 설정파일 ai.geminiApiKey 필요)");
      process.exit(2);
    }
    if (provider !== "gemini" && !openaiApiKey) {
      console.error("AI가 활성화되어 있지만 OpenAI API 키를 찾지 못했습니다. (설정파일 ai.apiKey 또는 환경변수 OPENAI_API_KEY 필요)");
      process.exit(2);
    }
  }

  // Very small cache for this run; if rerun you can keep req-ai-cache.json.
  const cachePath = path.join(outputDirAbs, "req-ai-cache.json");
  let cacheJson = {};
  try {
    if (fs.existsSync(cachePath)) cacheJson = JSON.parse(fs.readFileSync(cachePath, "utf8") || "{}");
  } catch {
    cacheJson = {};
  }
  const aiCache = createAiCache(cacheJson);

  const files = inputStat.isDirectory() ? walkFiles(inputAbs) : [inputAbs];
  const officeFiles = files.filter((p) => /\.(xlsx|xlsm|pptx)$/i.test(p));

  const results = [];
  const manualReview = [];
  const errors = [];
  const aiUsage = {
    enabled: !!merged.ai?.enabled,
    provider,
    model,
    maxImagesTotal: merged.ai?.maxImagesTotal,
    maxImagesPerItem: merged.ai?.maxImagesPerItem,
    onlyManualReview: !!merged.ai?.onlyManualReview,
    analyzedImages: 0,
    skippedImages: 0,
  };

  for (const filePath of officeFiles) {
    try {
      const res = await analyzeOfficeFile(filePath, {
        minTextCharsForReadable: merged.minTextCharsForReadable,
        maxSampleCharsPerItem: merged.maxSampleCharsPerItem,
        ai: {
          enabled: !!merged.ai?.enabled,
          provider,
          openaiApiKey,
          geminiApiKey,
          model,
          maxImagesTotal: merged.ai?.maxImagesTotal,
          maxImagesPerItem: merged.ai?.maxImagesPerItem,
          onlyManualReview: !!merged.ai?.onlyManualReview,
          usage: aiUsage,
          cache: aiCache,
        },
      });
      results.push(res);
      for (const item of res.manualReview || []) manualReview.push(item);
      for (const err of res.errors || []) errors.push(err);
    } catch (e) {
      errors.push({
        file: filePath,
        where: "analyzeOfficeFile",
        message: e && e.message ? e.message : String(e),
      });
      manualReview.push({
        file: filePath,
        type: "file",
        name: path.basename(filePath),
        reason: "파일 파싱 중 예외 발생(수동 확인 필요)",
      });
    }
  }

  const extracted = {
    generatedAt: new Date().toISOString(),
    input: inputAbs,
    files: results,
    manualReview,
    errors,
    aiUsage,
    config: {
      path: configPath,
      effective: redactSecrets(merged),
    },
  };

  const md = renderMarkdownReport(extracted);
  safeWriteFile(path.join(outputDirAbs, "req-analysis.md"), md);
  safeWriteFile(path.join(outputDirAbs, "req-requestdoc.md"), buildRequestDocument(extracted));
  safeWriteFile(path.join(outputDirAbs, "req-extracted.json"), JSON.stringify(extracted, null, 2));
  safeWriteFile(path.join(outputDirAbs, "req-manual-review.json"), JSON.stringify(manualReview, null, 2));
  safeWriteFile(path.join(outputDirAbs, "req-errors.json"), JSON.stringify(errors, null, 2));
  safeWriteFile(cachePath, JSON.stringify(aiCache.toJSON(), null, 2));

  console.log(`OK: analyzed ${officeFiles.length} file(s)`);
  console.log(`- report: ${path.join(outputDirAbs, "req-analysis.md")}`);
  console.log(`- requestdoc: ${path.join(outputDirAbs, "req-requestdoc.md")}`);
  console.log(`- manual review: ${path.join(outputDirAbs, "req-manual-review.json")}`);
  console.log(`- extracted: ${path.join(outputDirAbs, "req-extracted.json")}`);
  if (merged.ai?.enabled) console.log(`- ai cache: ${cachePath} (images analyzed=${aiUsage.analyzedImages}, skipped=${aiUsage.skippedImages})`);
  if (configPath) console.log(`- config: ${configPath}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

