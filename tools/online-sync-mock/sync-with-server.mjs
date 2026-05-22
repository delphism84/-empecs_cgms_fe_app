#!/usr/bin/env node
/**
 * BE 동기화 플로우 검증 (OnlineMonitor와 유사). 실패 시 exit 1.
 *
 *   cd tools/online-sync-mock && npm run sync
 *
 * Env: API_BASE, SKIP_REGISTER, LOGIN_EMAIL, LOGIN_PASSWORD
 */

const base = (process.env.API_BASE || 'https://empecs.lunarsystem.co.kr').replace(/\/$/, '');

function fail(msg) {
  console.error(`[sync-mock] FAIL: ${msg}`);
  process.exit(1);
}

function ok(cond, msg) {
  if (!cond) fail(msg);
}

async function http(method, path, { token, json } = {}) {
  const url = `${base}${path.startsWith('/') ? path : `/${path}`}`;
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

function log(step, msg, extra) {
  const line = `[sync-mock] ${step}: ${msg}`;
  if (extra !== undefined) console.log(line, extra);
  else console.log(line);
}

function is2xx(s) {
  return s >= 200 && s < 300;
}

async function main() {
  log('base', base);

  const probe = await http('GET', '/api/settings/app');
  ok(
    probe.status === 401 || probe.status === 403,
    `GET /api/settings/app without token expected 401/403, got ${probe.status}`,
  );
  log('settings/app (no auth)', `${probe.status} in ${probe.ms}ms`);

  let token = null;

  if (process.env.SKIP_REGISTER === '1') {
    const email = process.env.LOGIN_EMAIL;
    const password = process.env.LOGIN_PASSWORD;
    if (!email || !password) {
      fail('SKIP_REGISTER=1 requires LOGIN_EMAIL and LOGIN_PASSWORD');
    }
    const r = await http('POST', '/api/auth/login', {
      json: { email, password },
    });
    log('login', `${r.status} in ${r.ms}ms`);
    ok(is2xx(r.status), `login expected 2xx, got ${r.status}`);
    token = r.body?.token;
  } else {
    const id = `${Date.now()}`;
    const email = `sync_mock_${id}@lunarsystem.co.kr`;
    const password = 'TestPass123!';
    const reg = await http('POST', '/api/auth/register', {
      json: {
        email,
        password,
        firstName: 'Sync',
        lastName: 'Mock',
        dateOfBirth: '1990-01-01',
        agreeTerms: true,
      },
    });
    log('register', `${reg.status} in ${reg.ms}ms email=${email}`);
    ok(reg.status === 201, `register expected 201, got ${reg.status}`);
    token = reg.body?.token;
    log('credentials', `email=${email} password=${password}`);
  }

  ok(token && typeof token === 'string', 'missing JWT token');

  const app = await http('GET', '/api/settings/app', { token });
  log('settings/app', `${app.status} in ${app.ms}ms`);
  ok(app.status === 200, `settings/app with token expected 200, got ${app.status}`);

  const eqsn = 'NODE_SYNC_DUMMY_01';
  const t0 = Date.now();
  const tMs = [t0, t0 + 60_000].map((x) => x - 120_000);
  const batch = await http('POST', '/api/data/glucose/batch', {
    token,
    json: {
      eqsn,
      t: tMs,
      v: [105, 110],
      tr: [9001, 9002],
    },
  });
  log('glucose/batch', `${batch.status} in ${batch.ms}ms`, batch.body);
  ok(is2xx(batch.status), `glucose/batch expected 2xx, got ${batch.status}`);

  const eventsBody = {
    eqsn,
    events: [
      { type: 'memo', time: new Date(t0 - 60_000).toISOString(), memo: 'node sync batch a' },
      { type: 'memo', time: new Date(t0 - 30_000).toISOString(), memo: 'node sync batch b' },
    ],
  };

  let evBatch = await http('POST', '/api/data/events/batch', {
    token,
    json: eventsBody,
  });
  log('events/batch (events)', `${evBatch.status} in ${evBatch.ms}ms`);

  if (evBatch.status === 404) {
    const alt = await http('POST', '/api/data/events/batch', {
      token,
      json: { eqsn, items: eventsBody.events },
    });
    log('events/batch (items)', `${alt.status} in ${alt.ms}ms`);
    evBatch = alt;
  }

  const createdIds = [];

  if (is2xx(evBatch.status)) {
    ok(
      typeof evBatch.body === 'object' && evBatch.body !== null,
      'events/batch body should be JSON object',
    );
    log('events/batch OK', evBatch.body);
  } else if (evBatch.status === 404) {
    log('fallback', 'POST /api/data/events single ×2');
    for (const ev of eventsBody.events) {
      const one = await http('POST', '/api/data/events', {
        token,
        json: { ...ev, eqsn },
      });
      log('events', `${one.status} in ${one.ms}ms`);
      ok(is2xx(one.status), `single event expected 2xx, got ${one.status}`);
      const id = one.body?._id;
      if (id) createdIds.push(id);
    }
  } else {
    fail(`events/batch unexpected ${evBatch.status}: ${String(evBatch.body).slice(0, 200)}`);
  }

  if (createdIds.length > 0) {
    const id = createdIds[0];
    const d1 = await http('DELETE', `/api/data/events/${id}`, { token });
    log('delete', `${d1.status} in ${d1.ms}ms`);
    ok(d1.status === 200, `delete expected 200, got ${d1.status}`);
    const d2 = await http('DELETE', `/api/data/events/${id}`, { token });
    log('delete (idempotent)', `${d2.status} in ${d2.ms}ms`);
    ok(d2.status === 200, `delete idempotent expected 200, got ${d2.status}`);
  }

  log('done', 'ALL OK');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
