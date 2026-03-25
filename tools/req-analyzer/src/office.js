const path = require("path");

const { analyzeXlsx } = require("./xlsx");
const { analyzePptx } = require("./pptx");

async function analyzeOfficeFile(fileAbs, opts) {
  const ext = path.extname(fileAbs).toLowerCase();
  if (ext === ".xlsx" || ext === ".xlsm") return analyzeXlsx(fileAbs, opts);
  if (ext === ".pptx") return analyzePptx(fileAbs, opts);
  return {
    file: fileAbs,
    kind: "unknown",
    manualReview: [
      {
        file: fileAbs,
        type: "file",
        name: path.basename(fileAbs),
        reason: `지원하지 않는 확장자: ${ext}`,
      },
    ],
    errors: [],
  };
}

module.exports = { analyzeOfficeFile };

