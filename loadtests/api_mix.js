// k6 mixed API load (MC-121): discovery, matches, chat history, entitlements, interests (idempotent), notifications.
//   k6 run -e BASE=http://127.0.0.1:8100 -e HOST=api.mc.test -e TOKENS_FILE=tokens.json -e VUS=150 -e DURATION=3m loadtests/api_mix.js
// Targets (Bible 1.3): p95 < 500 ms for discovery, interests and chat history; error rate < 1%.
import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';
import { Trend, Rate } from 'k6/metrics';

const tokens = new SharedArray('tokens', () => JSON.parse(open(__ENV.TOKENS_FILE)));
const discovery = new Trend('t_discovery', true), history = new Trend('t_history', true), interests = new Trend('t_interests', true);
const failed = new Rate('unexpected_status');

export const options = {
  scenarios: { mix: { executor: 'constant-vus', vus: Number(__ENV.VUS || 100), duration: __ENV.DURATION || '2m' } },
  thresholds: {
    t_discovery: ['p(95)<500'], t_history: ['p(95)<500'], t_interests: ['p(95)<500'],
    unexpected_status: ['rate<0.01'], http_req_failed: ['rate<0.01'],
  },
};

function call(method, path, body, trend, ok = [200, 201]) {
  const t = tokens[(__VU - 1) % tokens.length];
  const res = http.request(method, `${__ENV.BASE}/api/v1${path}`, body ? JSON.stringify(body) : null, {
    headers: {
      Host: __ENV.HOST, Authorization: `Bearer ${t.access}`, 'Content-Type': 'application/json',
      ...(method === 'POST' ? { 'Idempotency-Key': `${__VU}-${__ITER}-${Math.random()}` } : {}),
    },
  });
  if (trend) trend.add(res.timings.duration);
  failed.add(!ok.includes(res.status));
  return res;
}

export default function () {
  const t = tokens[(__VU - 1) % tokens.length];
  // per-account limit is 120 discovery requests/hour (by design), so each VU asks about every 12th iteration (~30 s)
  if (!__ENV.NO_DISCOVERY && (__ITER + __VU) % 12 === 0) call('GET', '/discovery', null, discovery, [200, 429]);
  call('GET', '/me/entitlements', null, null);
  call('GET', '/matches', null, null);
  if (t.match_id) call('GET', `/matches/${t.match_id}/messages?limit=30`, null, history);
  call('GET', '/notifications', null, null);
  if (__ITER % 5 === 0) {
    const other = tokens[(__VU * 7 + __ITER) % tokens.length];
    call('POST', '/interests', { recipient_id: other.profile_id }, interests, [200, 201, 403, 409, 422, 429]);
  }
  sleep(1 + Math.random());
}
