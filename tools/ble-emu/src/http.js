/* eslint-disable no-console */

async function requestJson(url, { method, body } = {}) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), 7000);
  const res = await fetch(url, {
    method: method || "GET",
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
    signal: ctrl.signal,
  }).finally(() => clearTimeout(t));
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  if (!res.ok) {
    const err = new Error(`HTTP ${res.status}`);
    err.status = res.status;
    err.body = json;
    throw err;
  }
  return json;
}

module.exports = { requestJson };

