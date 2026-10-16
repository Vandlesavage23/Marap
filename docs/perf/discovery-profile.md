# Discovery latency profile (GET /api/v1/discovery)

Target (Bible §1.3): p95 < 500 ms at 3x launch load; engineering goal for this work: p95 < 300 ms for one
unloaded request on a 2,000 live-member database (k6 showed ~1.2-2.1 s single-request and timeouts at 150 VUs).

## Method

* Dataset: `mc_load` (2,000 live, verified members with photos and 25-30 answers each; pool cap 500).
* **cProfile** of one `GET /api/v1/discovery` through the Django test client (`settings.DEBUG=True` to count
  SQL), second call of a process so imports/connections are warm. cProfile roughly doubles pure-Python time, so
  use it for *where* time goes, not absolute latency.
* **Unprofiled wall clock**: 25 different viewers x 1 request each per mode (`perf_counter` around the
  client call), p50 / p95 / max. Impressions written by the run were deleted afterwards.
* Modes: `cold` = no Redis caches at all (first request after a deploy/flush; every candidate's answers come
  from PostgreSQL); `answers-warm` = scoring-vector cache warm, first-page pool snapshot cold (a member
  returning after > 60 s, or after editing profile/preferences/answers); `warm` = both warm (re-opening
  discovery within 60 s).
* Old code = `HEAD` before this change, same database, same Redis.
* Equivalence check: `build_ranked_pool` for 10 viewers (500 ranked entries each: ids, floats, why/discuss) was
  dumped from the old tree and the new tree and compared with `cmp`: **byte-identical** (1.28 MB each).
  The same property is a regression test (`test_cached_first_page_pool_is_identical_to_a_full_rebuild`).

## Before / after

cProfile, one page of 20 cards (2 photos each):

| | before | cold | answers-warm | warm |
| --- | --- | --- | --- | --- |
| SQL queries | **183** | 30 | 30 | 25 |
| time in SQL | 0.29 s | 0.09 s | 0.05 s | 0.03 s |
| total (profiled) | **2.12 s** | 0.54 s | 0.31 s | 0.12 s |
| `build_ranked_pool` / `first_page_pool` | 1.62 s | 0.46 s | 0.25 s | 0.06 s |
| `questionnaire.selectors.answers_for_scoring` | **1.43 s** | 0.29 s | 0.08 s | 0 (not called) |
| `profiles.selectors.card_data` | **0.46 s** | 0.04 s | 0.04 s | 0.04 s |
| pair scoring (`dimension_scores` x 500) | 0.08 s | 0.07 s | 0.07 s | 0 |

Unprofiled wall clock (what a client sees, server-side, no network):

| | before | cold | answers-warm | warm |
| --- | --- | --- | --- | --- |
| p50 | 1214 ms | 130 ms | 129 ms | 71 ms |
| p95 | 1251 ms | 231 ms | 147 ms | 77 ms |
| max | 1607 ms | 519 ms (very first viewer: 500 vectors from PostgreSQL) | 251 ms | 79 ms |

(before: n = 10 requests; after: n = 25 each.) The only path above 300 ms is the single very first request
after a cache flush, whose 500 candidate vectors come from the database (~0.5 s); every later viewer reuses
the candidates' vectors (cold p95 231 ms).

## What changed

1. **`answers_for_scoring` (1.43 s -> 0.08 s warm, 0.29 s cold).** No model instances and no `select_related`
   (the old code decoded each question's `options`/`scoring` JSON once per *answer row*: 37k decodes).
   Questions are read once (~30 rows); answers via `values_list`. Non-special answer vectors are cached per
   account in Redis (`mc/questionnaire/scoring_cache.py`): key `qa:<question-set signature>:<account>:<version>`,
   TTL 15 min (`QUESTIONNAIRE_SCORING_CACHE_SECONDS`, 0 disables). Rows keep answer-id order, which fixes the
   float summation order, so scores are bit-identical.
   * Invalidation: a per-account version counter is bumped by `post_save`/`post_delete` on `Answer` (covers
     `save_answers`, deal-breaker edits, consent-withdrawal deletes and the account-deletion cascade), once
     immediately and once on commit (closes the read-during-write race); bulk writers call
     `questionnaire.services.invalidate_scoring_cache` (the dev factory does). Readers fetch the version
     before reading the DB, so a slow reader can only fill an already-superseded key. A question re-seed or
     version bump changes the signature in the key. Redis errors fall back to PostgreSQL.
   * **No special data in the cache.** Only active, non-special questions are cached. The two faith questions
     (`special`, `scoring_allowed`) are decrypted from the database on every call and merged by answer id; the
     money question never leaves the database filter. Test: `test_special_answers_are_never_written_to_the_cache`.
   * What *is* cached: the member's non-special questionnaire answers (e.g. marriage timeline, children
     plans) under an opaque account-id key with a TTL, no phone/name/e-mail/free text. It is not logged.
     This is the same class of data that already sits in the 30-minute `disc:<token>` snapshot only in derived
     form, so it is a (small) widening: **flag for privacy review**; set the setting to 0 to turn it off.
2. **`card_data` (0.46 s -> 0.04 s).** One query for profiles, one for all approved photos + media, and the
   viewer-side policy facts (blocks, own gender, `browse` capability) read once via
   `profiles.policies.BatchedProfileAccess`. A photo the batched check does not clear falls back to the full
   per-media policy (interest/match grants still work). `media.selectors.signed_url_prechecked` signs a URL
   only after that check. Test: `test_card_photos_still_follow_the_media_policy`,
   `test_card_data_query_count_does_not_grow_with_cards`.
3. **First-page scored-pool reuse (answers-warm 0.31 s -> warm 0.12 s).** The scored pool (hard filter +
   deal-breakers + pair scores + explanations, before exposure caps/boost/interleave) is kept in Redis per
   viewer for 60 s (`DISCOVERY_SNAPSHOT_REUSE_SECONDS`, 0 disables). The key is a hash of the viewer's search
   context (profile fields + preferences used by the filter), their answers version and the discovery
   settings, so editing the profile, preferences or answers can never see a stale pool. On reuse, **blocks,
   pending interests, matches, `not_relevant` and recent impressions are re-read from the database and applied,
   exposure caps are re-queried, and boost + interleave re-run**; the cursor protocol (signed, 30 min) and the
   page snapshot are unchanged. A block therefore takes effect on the very next request
   (`test_block_removes_candidate_immediately_with_warm_pool_cache`).
   Trade-offs (ranking-affecting decisions): within the 60 s window (a) a candidate who just changed their own
   profile/answers/preferences or just went live is seen with their previous state (this is strictly fresher
   than pages 2+, which already read a 30-minute snapshot, and `card_data` still drops anyone no longer
   live+active at serve time); (b) after exclusions the reused pool can hold < 500 entries because it is not
   back-filled from beyond the cap (only until the 60 s expire); (c) if the reused pool is empty after
   exclusions it is rebuilt from scratch. A re-opened first page still moves on to new people because
   already-shown candidates are excluded exactly as before.
4. **Serve-time re-check** (`blocked_either_way_ids` + pending interests) is now done only for cursor pages;
   page 1 has just applied the same exclusions (saves 2 queries).
5. **Pool cap.** `DISCOVERY_POOL_SIZE=500` already bounds the pool: the hard filter keeps the 500 most recently
   seen eligible candidates (`ORDER BY account.last_seen_at DESC NULLS LAST LIMIT 500`) and only those are
   scored, so ranking quality for members with > 500 eligible candidates is "best of the 500 most recently
   active". Unchanged and not lowered. At 100k profiles the hard filter is 58-155 ms (MC-055 below); the
   answer fetch/scoring cost is linear in the cap.
6. **Indexes.** No migration: the remaining SQL is 25-30 point/small-range queries (1-2 ms each on this
   dataset; the 500-id exposure query is ~7 ms on `discovery_impression(candidate, shown_at)`, which exists).
   `makemigrations --check` is clean. See `docs/perf/mc-055-explain.md` for the hard-filter plan at 100k rows.

## Regression guards

`mc/discovery/tests/test_perf_cache.py`: cold page <= 34 queries and warm page <= 28 (measured 28 and 23; was
183), `card_data` query count independent of the number of cards, cached == reference ranking, answers change
re-orders results with warm caches, block (either direction) hides a candidate immediately with a warm pool,
preference change is not served from a stale pool, account deletion clears vectors, special data never cached.

## Remaining hot spots / next steps

* Pair scoring is pure Python (~65 ms profiled for 500 pairs). If the cap grows, memoise per-question
  similarity or move to numpy; keep float summation order identical.
* Per-request fixed cost (~25 queries): auth session join, three repeated entitlement/verification lookups
  (`browse` is evaluated in `next_candidates` and again for the photo policy) could share one
  `EntitlementState` per request; ~4 ms.
* Fully cold database fetch of 500 vectors is ~0.5 s once per flush; a Celery warm-up of live members' vectors
  after deploy would remove it.
* Re-run the k6 mix at 150 VUs against this build (the per-hour rate limit of 120 discovery requests per member
  and the 300 impressions/day cap apply to the load-test accounts).
