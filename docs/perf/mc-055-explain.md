# MC-055 hard-filter EXPLAIN (100,000 synthetic live profiles)

**Review (tech lead sign-off pending):** local Postgres 16, 100k live profiles (all passing the status/gender
filters, i.e. a worst-case-ish dense pool), `ORDER BY last_seen_at DESC LIMIT 500`:

| Case | Rows | Execution |
| --- | --- | --- |
| No distance limit | 500 | ~58 ms |
| `max_distance_km=50` (haversine subquery) | 454 | ~155 ms |

Both are far inside the p95 < 500 ms API target (Bible §1.3) even before caching; the planner chooses parallel
seq scans because half the table matches. Re-run on staging sizing (RDS) before launch; if the haversine case
grows, add a lat/lng bounding-box prefilter (btree on `location_lat, location_lng`) or move to PostGIS (ADR-0002).
Reproduce: `DATABASE_URL=…/mc_bench uv run python manage.py bench_hard_filter --profiles 100000`.

## no distance limit: 500 rows, 61 ms wall

```
Limit  (cost=8109.65..8950.38 rows=500 width=55) (actual time=48.819..57.848 rows=500 loops=1)
  Buffers: shared hit=6117
  ->  Nested Loop  (cost=8109.65..25820.45 rows=10533 width=55) (actual time=48.817..57.792 rows=500 loops=1)
        Buffers: shared hit=6117
        ->  Gather Merge  (cost=8109.23..10498.05 rows=20960 width=55) (actual time=48.771..54.501 rows=602 loops=1)
              Workers Planned: 1
              Workers Launched: 1
              Buffers: shared hit=3709
              ->  Sort  (cost=7109.22..7140.04 rows=12329 width=55) (actual time=45.084..45.161 rows=618 loops=2)
                    Sort Key: accounts_account.last_seen_at DESC NULLS LAST, profiles_profile.id
                    Sort Method: quicksort  Memory: 1076kB
                    Buffers: shared hit=3709
                    Worker 0:  Sort Method: quicksort  Memory: 1383kB
                    ->  Parallel Hash Join  (cost=3952.76..6271.48 rows=12329 width=55) (actual time=18.293..39.458 rows=10521 loops=2)
                          Hash Cond: (accounts_account.id = profiles_profile.account_id)
                          Buffers: shared hit=3660
                          ->  Parallel Seq Scan on accounts_account  (cost=0.00..2164.29 rows=58824 width=24) (actual time=0.011..9.025 rows=50000 loops=2)
                                Filter: ((status)::text = 'active'::text)
                                Buffers: shared hit=1429
                          ->  Parallel Hash  (cost=3798.65..3798.65 rows=12329 width=47) (actual time=18.051..18.053 rows=10521 loops=2)
                                Buckets: 32768  Batches: 1  Memory Usage: 1984kB
                                Buffers: shared hit=2184
                                ->  Parallel Seq Scan on profiles_profile  (cost=0.00..3798.65 rows=12329 width=47) (actual time=0.017..14.265 rows=10521 loops=2)
                                      Filter: ((account_id <> '01a13ff5-1f00-7864-8370-b170a1821357'::uuid) AND ((gender)::text <> ''::text) AND ((gender)::text <> 'male'::text) AND (birth_date > '1977-10-15'::date) AND (birth_date <= '1995-10-15'::date) AND ((marital_status)::text <> ALL ('{married_customary,married_islamic}'::text[])) AND ((status)::text = 'live'::text))
                                      Rows Removed by Filter: 39479
                                      Buffers: shared hit=2184
        ->  Index Scan using profiles_preference_profile_id_key on profiles_preference  (cost=0.42..0.73 rows=1 width=16) (actual time=0.005..0.005 rows=1 loops=602)
              Index Cond: (profile_id = profiles_profile.id)
              Filter: ((id IS NOT NULL) AND accept_has_children AND (age_max >= 38) AND (age_min <= 38))
              Rows Removed by Filter: 0
              Buffers: shared hit=2408
Planning:
  Buffers: shared hit=108
Planning Time: 0.666 ms
Execution Time: 58.038 ms
```

## max_distance_km=50: 454 rows, 160 ms wall

```
Limit  (cost=15645.03..16771.07 rows=500 width=55) (actual time=149.761..155.011 rows=454 loops=1)
  Buffers: shared hit=10216
  ->  Nested Loop  (cost=15645.03..27592.32 rows=5305 width=55) (actual time=149.759..154.960 rows=454 loops=1)
        Buffers: shared hit=10216
        ->  Gather Merge  (cost=15644.61..16847.68 rows=10556 width=55) (actual time=149.716..152.129 rows=552 loops=1)
              Workers Planned: 1
              Workers Launched: 1
              Buffers: shared hit=8008
              ->  Sort  (cost=14644.60..14660.12 rows=6209 width=55) (actual time=146.415..146.459 rows=276 loops=2)
                    Sort Key: accounts_account.last_seen_at DESC NULLS LAST, profiles_profile.id
                    Sort Method: quicksort  Memory: 46kB
                    Buffers: shared hit=8008
                    Worker 0:  Sort Method: quicksort  Memory: 47kB
                    ->  Parallel Hash Join  (cost=11934.71..14253.43 rows=6209 width=55) (actual time=128.687..146.169 rows=276 loops=2)
                          Hash Cond: (accounts_account.id = profiles_profile.account_id)
                          Buffers: shared hit=7993
                          ->  Parallel Seq Scan on accounts_account  (cost=0.00..2164.29 rows=58824 width=24) (actual time=0.016..10.962 rows=50000 loops=2)
                                Filter: ((status)::text = 'active'::text)
                                Buffers: shared hit=1429
                          ->  Parallel Hash  (cost=11857.10..11857.10 rows=6209 width=47) (actual time=128.234..128.237 rows=276 loops=2)
                                Buckets: 16384  Batches: 1  Memory Usage: 224kB
                                Buffers: shared hit=6546
                                ->  Parallel Seq Scan on profiles_profile  (cost=7764.33..11857.10 rows=6209 width=47) (actual time=107.032..127.853 rows=276 loops=2)
                                      Filter: ((account_id <> '01a13ff5-1f00-7864-8370-b170a1821357'::uuid) AND ((gender)::text <> ''::text) AND ((gender)::text <> 'male'::text) AND (birth_date > '1977-10-15'::date) AND (birth_date <= '1995-10-15'::date) AND ((marital_status)::text <> ALL ('{married_customary,married_islamic}'::text[])) AND ((status)::text = 'live'::text) AND (((district)::text = 'abroad'::text) OR (location_lat IS NULL) OR (location_lng IS NULL) OR (hashed SubPlan 1)))
                                      Rows Removed by Filter: 49724
                                      Buffers: shared hit=6546
                                      SubPlan 1
                                        ->  Seq Scan on profiles_profile u0  (cost=0.00..7681.00 rows=33333 width=16) (actual time=0.179..104.007 rows=2667 loops=2)
                                              Filter: ((location_lat IS NOT NULL) AND (location_lng IS NOT NULL) AND (('6371'::double precision * acos(LEAST('1'::double precision, ((('0.9999813422410571'::double precision * cos(radians((location_lat)::double precision))) * cos((radians((location_lng)::double precision) - '0.5686282702997525'::double precision))) + ('0.006108614390678361'::double precision * sin(radians((location_lat)::double precision))))))) <= '50'::double precision))
                                              Rows Removed by Filter: 97333
                                              Buffers: shared hit=4362
        ->  Index Scan using profiles_preference_profile_id_key on profiles_preference  (cost=0.42..1.02 rows=1 width=16) (actual time=0.005..0.005 rows=1 loops=552)
              Index Cond: (profile_id = profiles_profile.id)
              Filter: ((id IS NOT NULL) AND accept_has_children AND (age_max >= 38) AND (age_min <= 38))
              Rows Removed by Filter: 0
              Buffers: shared hit=2208
Planning:
  Buffers: shared hit=32
Planning Time: 0.800 ms
Execution Time: 155.201 ms
```
