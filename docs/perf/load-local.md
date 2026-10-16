# Local load test results (MC-121, partial)

**Status: run on ONE shared 4-vCPU / 15 GB sandbox VM** (k6, gunicorn, uvicorn, PostgreSQL 16 and Redis all on the same
machine, fake vendors). This is NOT the staging-sized run the ticket asks for; it finds bugs and gives a single-box capacity
number. The staging run (k6 targets in Bible §1.3 on staging sizing) is still open (MC-124).

Method: `loadtests/run_local.sh` (migrate scratch DB → `manage.py load_fixture` 2,000 members / 400 matched pairs → gunicorn
gthread REST (3 workers × 8 threads) + uvicorn ASGI for WebSockets → `loadtests/api_mix.js` and `loadtests/ws_chat.js`).
k6 v0.54.0. Tokens are real sessions. Per-account rate limits stay on (so each VU asks for discovery about every 30 s).

## Bugs found by the load run (all fixed, with regression tests)
| # | Finding | Fix |
| --- | --- | --- |
| 1 | **Every idle chat WebSocket died within ~5 s** against the real Redis channel layer ("Timeout reading from redis", redis-py 8 default socket timeout vs channels_redis' 5 s blocking pop). The in-memory layer used by all tests hid it. | `CHANNEL_LAYERS` hosts now set `socket_timeout`; `mc/messaging/tests/test_websocket_real_redis.py` keeps sockets idle 7 s on real Redis. |
| 2 | GET /discovery took 1.2-2.1 s unloaded (183 SQL queries, answers decoded per request) and collapsed under load. | See docs/perf/discovery-profile.md: 130 ms cold / 70 ms warm p50, byte-identical ranking. |
| 3 | REST under ASGI runs every sync view on **one thread per worker** → throughput = number of workers. | API service now `gunicorn config.wsgi --worker-class gthread --workers 3 --threads 8` (Dockerfile, Terraform, Bible §2.2); WebSockets stay on ASGI. |
| 4 | Load-script bugs (non-UUID `client_msg_id`, digit-run bodies tripping the contact-details rule — which works as designed). | Fixed in `ws_chat.js`. |

## Results after the fixes
HTTP mix (discovery, entitlements, matches, history, notifications, interests; WSGI 3×8):

| VUs | req/s | history p95 | interests p95 | discovery p95 | verdict (<500 ms) |
| --- | --- | --- | --- | --- | --- |
| 30 | 75 | 101 ms | 36 ms | 425 ms | pass |
| 60 | 106 | 618 ms | 422 ms | 1.44 s | **fail** (CPU-bound) |
| 100 | 145 | 790 ms | 501 ms | 1.44 s | **fail** (CPU-bound) |

Single unloaded request p50/p95: entitlements 10/12 ms, matches 35/52 ms, notifications 8/10 ms, history 16/19 ms,
discovery (cold) 154/243 ms. So latency is fine until the machine saturates at roughly **100-145 requests/s** (all cores
busy, k6 and PostgreSQL included). Meeting the target at "3× launch load" is therefore a horizontal-scaling question: size
task counts from this number once launch load is known (OD in Bible §1.3 is still an assumption).

WebSockets (one uvicorn worker, 300 sockets, one message per socket every ~20 s ≈ 15 msg/s): delivery p50 38 ms,
p95 137 ms, connect p95 24 ms, no dropped sockets (target p95 < 1 s: pass). At 4 s per message (75 msg/s) a single worker
saturates (delivery p95 41 s) — run more `ws` tasks (ECS min 2) and re-test on staging.

## Not covered
Staging-sized 2,000-socket run; soak (hours); PostgreSQL on separate hardware; real vendors; mobile networks.
