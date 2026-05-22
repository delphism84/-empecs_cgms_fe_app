#!/usr/bin/env node
import fs from 'node:fs';

/**
 * CGMS Flutter 앱이 사용하는 BE API 전체 스모크 + 계약 검증.
 *
 *   cd tools/api-qa-bot && npm run qa
 *   API_BASE=https://staging.example.com npm run qa
 *   SKIP_REGISTER=1 LOGIN_EMAIL=... LOGIN_PASSWORD=... npm run qa
 *   npm run qa:strict   # 옵션 엔드포인트 실패 시에도 exit 1
 *
 * 출력: 콘솔 요약 + --json-out=path 시 JSON
 */

const args = process.argv.slice(2);
const strict = args.includes('--strict');
const jsonOutArg = args.find((a) => a.startsWith('--json-out='));
const jsonOut = jsonOutArg ? jsonOutArg.split('=')[1] : null;

const base = (process.env.API_BASE || 'https://empecs.lunarsystem.co.kr').replace(/\/$/, '');

const results = { base, startedAt: new Date().toISOString(), steps: [], optionalFailed: [] };

function is2xx(s) {
  return s >= 200 && s < 300;
}

function fail(msg) {
  console.error(`[api-qa] FAIL: ${msg}`);
  results.failed = msg;
  writeJsonOut();
  process.exit(1);
}

function step(name, ok, detail = {}) {
  const row = { name, ok, ...detail };
  results.steps.push(row);
  const icon = ok ? '✓' : '✗';
  console.log(`[api-qa] ${icon} ${name}`, detail.ms != null ? `${detail.ms}ms` : '', detail.status != null ? `HTTP ${detail.status}` : '');
}

function warnOptional(name, msg) {
  results.optionalFailed.push({ name, msg });
  console.warn(`[api-qa] (optional) ${name}: ${msg}`);
}

async function http(method, path, { token, json, query } = {}) {
  let url = `${base}${path.startsWith('/') ? path : `/${path}`}`;
  if (query && Object.keys(query).length) {
    const u = new URL(url);
    for (const [k, v] of Object.entries(query)) {
      if (v != null) u.searchParams.set(k, String(v));
    }
    url = u.toString();
  }
  const headers = { Accept: 'application/json' };
  if (json !== undefined) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;
  const t0 = Date.now();
  const res = await fetch(url, {
    method,
    headers,
    body: json !== undefined ? JSON.stringify(json) : undefined,
  });
  const ms = Date.now() - t0;
  const text = await res.text();
  let body;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { status: res.status, ms, body, url };
}

function writeJsonOut() {
  if (!jsonOut) return;
  try {
    results.endedAt = new Date().toISOString();
    fs.writeFileSync(jsonOut, JSON.stringify(results, null, 2), 'utf8');
    console.log(`[api-qa] wrote ${jsonOut}`);
  } catch (e) {
    console.error('[api-qa] json-out error', e);
  }
}

async function optional(name, fn) {
  try {
    const r = await fn();
    step(name, true, r);
    return r;
  } catch (e) {
    const msg = e?.message || String(e);
    warnOptional(name, msg);
    step(name, false, { error: msg });
    if (strict) fail(`strict: optional ${name}: ${msg}`);
    return null;
  }
}

async function main() {
  console.log(`[api-qa] API_BASE=${base} strict=${strict}`);

  // --- Unauthenticated probe (OnlineMonitor) ---
  const probe = await http('GET', '/api/settings/app');
  const probeOk = probe.status === 401 || probe.status === 403;
  step('GET /api/settings/app (no auth → 401/403)', probeOk, { status: probe.status, ms: probe.ms });
  if (!probeOk) fail(`expected 401/403, got ${probe.status}`);

  // --- Auth ---
  let token;
  let testEmail;
  let testPassword;

  if (process.env.SKIP_REGISTER === '1') {
    testEmail = process.env.LOGIN_EMAIL;
    testPassword = process.env.LOGIN_PASSWORD;
    if (!testEmail || !testPassword) fail('SKIP_REGISTER=1 needs LOGIN_EMAIL, LOGIN_PASSWORD');
    const r = await http('POST', '/api/auth/login', {
      json: { email: testEmail, password: testPassword },
    });
    step('POST /api/auth/login', is2xx(r.status), { status: r.status, ms: r.ms });
    if (!is2xx(r.status)) fail(`login ${r.status}`);
    token = r.body?.token;
  } else {
    const id = Date.now();
    testEmail = `api_qa_${id}@lunarsystem.co.kr`;
    testPassword = 'TestPass123!';
    const reg = await http('POST', '/api/auth/register', {
      json: {
        email: testEmail,
        password: testPassword,
        firstName: 'QA',
        lastName: 'Bot',
        dateOfBirth: '1990-01-01',
        agreeTerms: true,
      },
    });
    step('POST /api/auth/register', reg.status === 201, { status: reg.status, ms: reg.ms });
    if (reg.status !== 201) fail(`register expected 201, got ${reg.status}`);
    token = reg.body?.token;
    console.log(`[api-qa] test account: ${testEmail} / ${testPassword}`);
  }

  if (!token) fail('no JWT');

  // --- Profile ---
  const me = await http('GET', '/api/auth/me', { token });
  step('GET /api/auth/me', is2xx(me.status), { status: me.status, ms: me.ms });
  if (!is2xx(me.status)) fail(`auth/me ${me.status}`);

  const app = await http('GET', '/api/settings/app', { token });
  step('GET /api/settings/app (auth)', app.status === 200, { status: app.status, ms: app.ms });
  if (app.status !== 200) fail(`settings/app ${app.status}`);

  // --- Data read (DataService.fetch*) ---
  const now = new Date();
  const from = new Date(now.getTime() - 7 * 86400000).toISOString();
  const to = now.toISOString();
  const gList = await http('GET', '/api/data/glucose', {
    token,
    query: { from, to, limit: 50 },
  });
  step('GET /api/data/glucose', is2xx(gList.status), { status: gList.status, ms: gList.ms });
  if (!is2xx(gList.status)) fail(`glucose list ${gList.status}`);

  const eList = await http('GET', '/api/data/events', {
    token,
    query: { from, to, limit: 50, sync: 'true' },
  });
  step('GET /api/data/events', is2xx(eList.status), { status: eList.status, ms: eList.ms });
  if (!is2xx(eList.status)) fail(`events list ${eList.status}`);

  // --- EQ registry (sensor flow) ---
  const eqsn = `APIQA_${Date.now().toString(36).toUpperCase()}`;
  const resolve = await http('GET', '/api/settings/eq-list/resolve', {
    token,
    query: { serial: eqsn },
  });
  const resolveOk = resolve.status === 200 || resolve.status === 404;
  step('GET /api/settings/eq-list/resolve', resolveOk, { status: resolve.status, ms: resolve.ms });
  if (!resolveOk) fail(`eq resolve ${resolve.status}`);

  const startAt = now.toISOString();
  const upsertEq = await http('POST', '/api/settings/eq-list', {
    token,
    json: { serial: eqsn, startAt },
  });
  const upsertOk = upsertEq.status === 200 || upsertEq.status === 201;
  step('POST /api/settings/eq-list', upsertOk, { status: upsertEq.status, ms: upsertEq.ms });
  if (!upsertOk) fail(`eq-list upsert ${upsertEq.status}`);

  const eqOne = await http('GET', `/api/settings/eq-list/${encodeURIComponent(eqsn)}`, { token });
  const eqOneOk = eqOne.status === 200 || eqOne.status === 404;
  step('GET /api/settings/eq-list/:serial', eqOneOk, { status: eqOne.status, ms: eqOne.ms });
  if (!eqOneOk) fail(`eq-list get ${eqOne.status}`);

  // --- Glucose write ---
  const tMs = [now.getTime() - 180000, now.getTime() - 120000];
  const batch = await http('POST', '/api/data/glucose/batch', {
    token,
    json: {
      eqsn,
      t: tMs,
      v: [100, 102],
      tr: [8001, 8002],
    },
  });
  step('POST /api/data/glucose/batch', is2xx(batch.status), { status: batch.status, ms: batch.ms });
  if (!is2xx(batch.status)) fail(`glucose batch ${batch.status}`);

  const oneG = await http('POST', '/api/data/glucose', {
    token,
    json: {
      time: new Date(now.getTime() - 60000).toISOString(),
      value: 105,
      trid: 8003,
      eqsn,
    },
  });
  step('POST /api/data/glucose (single)', is2xx(oneG.status), { status: oneG.status, ms: oneG.ms });
  if (!is2xx(oneG.status)) fail(`glucose single ${oneG.status}`);

  // --- Events write (batch or fallback) ---
  const evPayload = [
    { type: 'memo', time: new Date(now.getTime() - 90000).toISOString(), memo: 'api-qa batch a' },
    { type: 'memo', time: new Date(now.getTime() - 30000).toISOString(), memo: 'api-qa batch b' },
  ];
  let evBatch = await http('POST', '/api/data/events/batch', {
    token,
    json: { eqsn, events: evPayload },
  });
  if (evBatch.status === 404) {
    evBatch = await http('POST', '/api/data/events/batch', {
      token,
      json: { eqsn, items: evPayload },
    });
  }

  const createdIds = [];
  if (is2xx(evBatch.status)) {
    step('POST /api/data/events/batch', true, { status: evBatch.status, ms: evBatch.ms });
  } else if (evBatch.status === 404) {
    step('POST /api/data/events/batch', true, { status: 404, note: 'not deployed, using singles', ms: evBatch.ms });
    for (const ev of evPayload) {
      const one = await http('POST', '/api/data/events', { token, json: { ...ev, eqsn } });
      if (!is2xx(one.status)) fail(`event single ${one.status}`);
      if (one.body?._id) createdIds.push(one.body._id);
    }
  } else {
    fail(`events/batch unexpected ${evBatch.status}`);
  }

  if (createdIds.length === 0 && is2xx(evBatch.status) && Array.isArray(evBatch.body?.insertedIds)) {
    createdIds.push(...evBatch.body.insertedIds);
  }
  if (createdIds.length === 0 && is2xx(evBatch.status)) {
    // some BE return { ok, count } only
    const one = await http('POST', '/api/data/events', {
      token,
      json: { ...evPayload[0], eqsn },
    });
    if (is2xx(one.status) && one.body?._id) createdIds.push(one.body._id);
  }

  // --- Delete idempotent ---
  if (createdIds.length > 0) {
    const id = createdIds[0];
    const d1 = await http('DELETE', `/api/data/events/${id}`, { token });
    const d2 = await http('DELETE', `/api/data/events/${id}`, { token });
    step('DELETE /api/data/events/:id (×2 idempotent)', d1.status === 200 && d2.status === 200, {
      status: `${d1.status}/${d2.status}`,
      ms: d1.ms + d2.ms,
    });
    if (d1.status !== 200 || d2.status !== 200) fail(`delete idempotent ${d1.status} ${d2.status}`);
  } else {
    step('DELETE /api/data/events/:id', true, { note: 'skipped (no id from batch)' });
  }

  // --- Optional: app settings PUT ---
  await optional('PUT /api/settings/app', async () => {
    const r = await http('PUT', '/api/settings/app', {
      token,
      json: { language: 'en' },
    });
    if (!is2xx(r.status) && r.status !== 204) throw new Error(`HTTP ${r.status}`);
    return { status: r.status, ms: r.ms };
  });

  // --- Optional: alarm CRUD (minimal) ---
  await optional('POST /api/settings/alarms', async () => {
    const r = await http('POST', '/api/settings/alarms', {
      token,
      json: {
        type: 'high',
        enabled: true,
        threshold: 200,
        sound: true,
        vibrate: true,
        repeatMin: 10,
      },
    });
    if (!is2xx(r.status)) throw new Error(`HTTP ${r.status}`);
    const aid = r.body?._id;
    if (aid && /^[a-fA-F0-9]{24}$/.test(aid)) {
      const del = await http('DELETE', `/api/settings/alarms/${aid}`, { token });
      if (del.status !== 200) throw new Error(`alarm delete ${del.status}`);
    }
    return { status: r.status, ms: r.ms };
  });

  // --- Optional: destructive clears (dev) ---
  if (process.env.RUN_DESTRUCTIVE === '1') {
    await optional('DELETE /api/data/glucose/clear', async () => {
      const r = await http('DELETE', '/api/data/glucose/clear', { token });
      if (!is2xx(r.status)) throw new Error(`HTTP ${r.status}`);
      return { status: r.status, ms: r.ms };
    });
    await optional('DELETE /api/data/events/clear', async () => {
      const r = await http('DELETE', '/api/data/events/clear', { token });
      if (!is2xx(r.status)) throw new Error(`HTTP ${r.status}`);
      return { status: r.status, ms: r.ms };
    });
  }

  console.log('[api-qa] ALL REQUIRED CHECKS PASSED');
  results.passed = true;
  writeJsonOut();
}

main().catch((e) => {
  console.error(e);
  results.failed = String(e);
  writeJsonOut();
  process.exit(1);
});
