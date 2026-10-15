// k6 script for MC-076 / MC-121: 2,000 concurrent chat sockets on dev/staging sizing.
//   k6 run -e BASE=wss://api.dev.example.ug -e TOKENS_FILE=tokens.json loadtests/ws_chat.js
// tokens.json: an array of {access, match_id} pairs created with `manage.py seed_demo` + login helper.
// NOT YET RUN: needs a deployed environment (MC-020). Targets: auth ≤ 5 s, p95 server→recipient < 1 s.
import ws from 'k6/ws';
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

const tokens = new SharedArray('tokens', () => JSON.parse(open(__ENV.TOKENS_FILE)));
const delivery = new Trend('msg_delivery_ms', true);

export const options = {
  scenarios: { sockets: { executor: 'ramping-vus', stages: [
    { duration: '2m', target: 2000 }, { duration: '5m', target: 2000 }, { duration: '1m', target: 0 } ] } },
  thresholds: { msg_delivery_ms: ['p(95)<1000'], ws_connecting: ['p(95)<2000'] },
};

export default function () {
  const t = tokens[(__VU - 1) % tokens.length];
  const res = ws.connect(`${__ENV.BASE}/ws/chat`, { headers: { Host: __ENV.HOST_HEADER || '' } }, (socket) => {
    socket.on('open', () => socket.send(JSON.stringify({ type: 'auth', token: t.access })));
    socket.on('message', (raw) => {
      const m = JSON.parse(raw);
      if (m.type === 'auth.ok') {
        socket.setInterval(() => {
          const sent = Date.now();
          socket.send(JSON.stringify({ type: 'msg.send', match_id: t.match_id,
            client_msg_id: `${__VU}-${sent}-${Math.random()}`, kind: 'text', body: 'ping ' + sent }));
        }, 20000 + Math.random() * 10000);
      } else if (m.type === 'msg.new' && m.message.body.startsWith('ping ')) {
        delivery.add(Date.now() - Number(m.message.body.slice(5)));
      } else if (m.type === 'ping') {
        socket.send(JSON.stringify({ type: 'pong' }));
      }
    });
    socket.setTimeout(() => socket.close(), 8 * 60 * 1000);
  });
  check(res, { 'upgraded': (r) => r && r.status === 101 });
}
