// k6 script for MC-076 / MC-121: 2,000 concurrent chat sockets on dev/staging sizing.
//   k6 run -e BASE=wss://api.dev.example.ug -e TOKENS_FILE=tokens.json loadtests/ws_chat.js
// tokens.json: an array of {access, match_id} pairs created with `manage.py seed_demo` + login helper.
// Local single-machine run: loadtests/run_local.sh (RAMP/HOLD/SOCKETS/SEND_EVERY_MS env). Staging-size run still pending (MC-124). Targets: auth ≤ 5 s, p95 server→recipient < 1 s.
import ws from 'k6/ws';
import { check } from 'k6';
import { Trend, Counter } from 'k6/metrics';
import { SharedArray } from 'k6/data';

const tokens = new SharedArray('tokens', () => JSON.parse(open(__ENV.TOKENS_FILE)));
const delivery = new Trend('msg_delivery_ms', true);
const frames = new Counter('frames_by_type');
const errors = new Counter('ws_error_frames');

export const options = {
  scenarios: { sockets: { executor: 'ramping-vus', stages: [
    { duration: __ENV.RAMP || '2m', target: Number(__ENV.SOCKETS || 2000) },
    { duration: __ENV.HOLD || '5m', target: Number(__ENV.SOCKETS || 2000) },
    { duration: '30s', target: 0 } ] } },
  thresholds: { msg_delivery_ms: ['p(95)<1000'], ws_connecting: ['p(95)<2000'] },
};

function uuid4() {
  const h = () => Math.floor(Math.random() * 0x10000).toString(16).padStart(4, '0');
  return `${h()}${h()}-${h()}-4${h().slice(1)}-8${h().slice(1)}-${h()}${h()}${h()}`;
}

export default function () {
  const t = tokens[(__VU - 1) % tokens.length];
  const res = ws.connect(`${__ENV.BASE}/ws/chat`, { headers: { Host: __ENV.HOST_HEADER || '' } }, (socket) => {
    socket.on('open', () => socket.send(JSON.stringify({ type: 'auth', token: t.access })));
    socket.on('message', (raw) => {
      const m = JSON.parse(raw);
      frames.add(1, { type: m.type });
      if (m.type === 'msg.error' || m.type === 'error') { errors.add(1); if (__ENV.DEBUG) console.log(raw); }
      if (m.type === 'auth.ok') {
        socket.setInterval(() => {
          const sent = Date.now();
          socket.send(JSON.stringify({ type: 'msg.send', match_id: t.match_id,
            client_msg_id: uuid4(), kind: 'text', body: 'ping ' + sent.toString(36) })); // base36: a long digit run would trip the contact-details rule (by design)
        }, Number(__ENV.SEND_EVERY_MS || 20000) + Math.random() * 5000);
      } else if (m.type === 'msg.new' && m.message.body.startsWith('ping ')) {
        delivery.add(Date.now() - parseInt(m.message.body.slice(5), 36));
      } else if (m.type === 'ping') {
        socket.send(JSON.stringify({ type: 'pong' }));
      }
    });
    socket.setTimeout(() => socket.close(), Number(__ENV.SOCKET_LIFETIME_MS || 8 * 60 * 1000));
  });
  check(res, { 'upgraded': (r) => r && r.status === 101 });
}
