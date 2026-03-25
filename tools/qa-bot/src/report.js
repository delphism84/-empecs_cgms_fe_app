const path = require("path");

function esc(s) {
  return String(s ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function renderHtml({ title, items }) {
  const rows = items
    .slice()
    .sort((a, b) => String(a.id).localeCompare(String(b.id)))
    .map((it) => {
      const result = (it.result || "").toUpperCase();
      const cls = result === "PASS" ? "pass" : result === "FAIL" ? "fail" : "na";
      const when = it.verifiedAt ? new Date(it.verifiedAt).toLocaleString() : "";
      const shot = it.screenshot?.relPath
        ? `<a href="${esc(it.screenshot.relPath)}" target="_blank" rel="noopener"><img class="shot" src="${esc(it.screenshot.relPath)}" alt="${esc(it.id)}"/></a>`
        : "";
      const steps = Array.isArray(it.verificationSteps) ? it.verificationSteps.join("\n") : (it.verificationSteps || "");
      const evidence = it.evidence ? `<details><summary>evidence</summary><pre>${esc(JSON.stringify(it.evidence, null, 2))}</pre></details>` : "";
      const sc = it?.evidence?.serverCheck;
      const scOk = sc ? (sc.ok === true) : null;
      const scText = sc ? (scOk ? "OK" : "FAIL") : "";
      const scDetail = sc
        ? `<details><summary>${esc(scText)}</summary><pre>${esc(JSON.stringify(sc, null, 2))}</pre></details>`
        : "";
      return `
        <tr class="${cls}">
          <td class="id">${esc(it.id)}</td>
          <td>${esc(it.title || "")}</td>
          <td><pre>${esc(steps)}</pre></td>
          <td class="result">${esc(result)}</td>
          <td>${esc(when)}</td>
          <td>${shot}</td>
          <td>${scDetail}</td>
          <td>${evidence}</td>
        </tr>
      `;
    })
    .join("\n");

  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>${esc(title)}</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, "Noto Sans KR", Arial; margin: 16px; }
    h1 { margin: 0 0 10px; font-size: 18px; }
    .meta { color: #555; margin: 0 0 16px; font-size: 12px; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #e5e5e5; padding: 8px; vertical-align: top; }
    th { background: #fafafa; position: sticky; top: 0; z-index: 1; }
    pre { margin: 0; white-space: pre-wrap; word-break: break-word; font-size: 12px; }
    .id { font-weight: 700; white-space: nowrap; }
    .result { font-weight: 800; }
    tr.pass td.result { color: #0a7a2f; }
    tr.fail td.result { color: #b00020; }
    tr.na td.result { color: #666; }
    .server details > summary { cursor: pointer; font-weight: 700; }
    .shot { width: 220px; border-radius: 8px; border: 1px solid #ddd; }
    details pre { max-height: 280px; overflow: auto; }
  </style>
</head>
<body>
  <h1>${esc(title)}</h1>
  <div class="meta">generated: ${esc(new Date().toISOString())}</div>
  <table>
    <thead>
      <tr>
        <th>요구항목</th>
        <th>설명</th>
        <th>검수(절차/명령)</th>
        <th>결과</th>
        <th>검수시각</th>
        <th>화면캡처(JPG)</th>
        <th>서버체크</th>
        <th>증거</th>
      </tr>
    </thead>
    <tbody>
      ${rows || "<tr><td colspan='8'>No items yet.</td></tr>"}
    </tbody>
  </table>
</body>
</html>`;
}

function makeRel(fromDir, absPath) {
  const rel = path.relative(fromDir, absPath).split(path.sep).join("/");
  return rel.startsWith(".") ? rel : `./${rel}`;
}

module.exports = { renderHtml, makeRel };

