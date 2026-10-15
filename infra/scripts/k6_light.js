// Light HTTP load check for staging (Bible 13.3). NOT the 2,000-socket chat test (loadtests/ws_chat.js).
//   k6 run -e BASE=https://api.<domain> infra/scripts/k6_light.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 20,
  duration: '60s',
  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(95)<1000'] },
};

export default function () {
  const res = http.get(`${__ENV.BASE}/ready`);
  check(res, { 'ready is 200': (r) => r.status === 200 });
  sleep(1);
}
