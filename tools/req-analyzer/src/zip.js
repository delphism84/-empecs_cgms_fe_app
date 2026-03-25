const fs = require("fs");
const JSZip = require("jszip");

async function loadZip(fileAbs) {
  const buf = fs.readFileSync(fileAbs);
  const zip = await JSZip.loadAsync(buf);
  return zip;
}

async function readZipText(zip, entryPath) {
  const file = zip.file(entryPath);
  if (!file) return null;
  return await file.async("text");
}

async function readZipBuffer(zip, entryPath) {
  const file = zip.file(entryPath);
  if (!file) return null;
  return await file.async("nodebuffer");
}

function listZipPaths(zip, prefix) {
  const out = [];
  zip.forEach((relativePath) => {
    if (!prefix || relativePath.startsWith(prefix)) out.push(relativePath);
  });
  return out;
}

module.exports = { loadZip, readZipText, readZipBuffer, listZipPaths };

