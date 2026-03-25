#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * full_auto_report.html → PDF / PPTX 변환
 * 사용: node src/export-pdf-pptx.js [--pdf] [--pptx] [--dir <path>]
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..", "..");
const DEFAULT_DIR = path.join(ROOT, "docs", "manual_result", "full_auto");

function parseArgs(argv) {
  const a = { pdf: false, pptx: false, dir: DEFAULT_DIR };
  for (let i = 2; i < argv.length; i++) {
    const x = argv[i];
    if (x === "--pdf") { a.pdf = true; continue; }
    if (x === "--pptx") { a.pptx = true; continue; }
    if (x === "--dir" && argv[i + 1]) { a.dir = path.resolve(argv[++i]); continue; }
  }
  if (!a.pdf && !a.pptx) {
    a.pdf = true;
    a.pptx = true;
  }
  return a;
}

async function exportPdf(dir) {
  const htmlPath = path.join(dir, "full_auto_report.html");
  const pdfPath = path.join(dir, "full_auto_report.pdf");
  if (!fs.existsSync(htmlPath)) {
    throw new Error(`HTML not found: ${htmlPath}`);
  }
  const puppeteer = require("puppeteer");
  const browser = await puppeteer.launch({ headless: "new" });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1200, height: 800 });
    await page.goto(`file://${htmlPath.replace(/\\/g, "/")}`, { waitUntil: "networkidle0", timeout: 10000 });
    await page.pdf({
      path: pdfPath,
      format: "A4",
      printBackground: true,
      margin: { top: "15mm", right: "15mm", bottom: "15mm", left: "15mm" },
    });
    console.log("[OK] PDF:", pdfPath);
  } finally {
    await browser.close();
  }
}

async function exportPptx(dir) {
  const jsonPath = path.join(dir, "full_auto_result.json");
  const shotDir = path.join(dir, "screenshots");
  const pptxPath = path.join(dir, "full_auto_report.pptx");
  if (!fs.existsSync(jsonPath)) {
    throw new Error(`JSON not found: ${jsonPath}`);
  }
  const pptxgen = require("pptxgenjs");
  const pres = new pptxgen();
  pres.title = "CGMS QA Full Auto Report";
  pres.author = "QA Bot";

  const data = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
  const items = data.items || [];

  // 표지 슬라이드
  const cover = pres.addSlide();
  cover.addText("CGMS QA Full Auto Report", { x: 0.5, y: 1, w: 9, h: 1.2, fontSize: 36, bold: true });
  cover.addText(`총 ${data.total}개 / 성공 ${data.success}개 / 실패 ${data.failed || 0}개`, {
    x: 0.5, y: 2.2, w: 9, h: 0.5, fontSize: 18, color: "666666",
  });

  for (const it of items) {
    const slide = pres.addSlide();
    const imgPath = path.resolve(dir, it.shot || "");
    slide.addText(`${it.id}  ${it.title}`, { x: 0.5, y: 0.15, w: 9, h: 0.35, fontSize: 20, bold: true });
    slide.addText(`라우트: ${it.route}`, { x: 0.5, y: 0.5, w: 9, h: 0.25, fontSize: 10, color: "666666" });
    slide.addText(`목적: ${it.purpose}`, { x: 0.5, y: 0.75, w: 9, h: 0.6, fontSize: 10 });
    if (it.req) {
      slide.addText(`[요구] ${it.req}`, { x: 0.5, y: 1.35, w: 9, h: 0.35, fontSize: 9, color: "555555", italic: true });
    }
    slide.addText(`화면: ${it.ui}`, { x: 0.5, y: it.req ? 1.7 : 1.35, w: 9, h: 0.4, fontSize: 10 });
    const elementsText = (it.elements || "").trim() || "(없음)";
    const elementsY = it.req ? 2.1 : 1.75;
    slide.addText(`UI요소:\n${elementsText}`, { x: 0.5, y: elementsY, w: 4.2, h: 2.2, fontSize: 8, valign: "top", shrinkText: true });
    if (it.shot && fs.existsSync(imgPath)) {
      slide.addImage({
        path: imgPath,
        x: 5.0,
        y: elementsY,
        w: 4.4,
        h: 2.8,
      });
    }
    slide.addText(`함수: ${it.fn}`, { x: 5.0, y: elementsY + 2.9, w: 4.4, h: 0.4, fontSize: 9, color: "444444" });
  }

  await pres.writeFile({ fileName: pptxPath });
  console.log("[OK] PPTX:", pptxPath);
}

async function main() {
  const a = parseArgs(process.argv);
  if (a.pdf) {
    try {
      await exportPdf(a.dir);
    } catch (e) {
      console.error("PDF export error:", e?.message || e);
      process.exitCode = 1;
    }
  }
  if (a.pptx) {
    try {
      await exportPptx(a.dir);
    } catch (e) {
      console.error("PPTX export error:", e?.message || e);
      process.exitCode = 1;
    }
  }
}

main().catch((e) => {
  console.error(e?.stack || e);
  process.exit(1);
});
