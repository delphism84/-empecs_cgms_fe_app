const fs = require("fs");
const path = require("path");

function ensureDir(dirAbs) {
  fs.mkdirSync(dirAbs, { recursive: true });
}

function safeWriteFile(fileAbs, content) {
  ensureDir(path.dirname(fileAbs));
  fs.writeFileSync(fileAbs, content, "utf8");
}

module.exports = { ensureDir, safeWriteFile };

