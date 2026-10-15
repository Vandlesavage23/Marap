# ADR-0002: Coarse location as rounded lat/lng; defer PostGIS

- Status: accepted (revisit at MC-055 EXPLAIN review)
- Date: 2026-10-15
- Deciders: Tech lead

## Problem
Bible §7.3 specifies `location geography(Point)`; CLAUDE.md lists PostgreSQL 16 + PostGIS. The local and
CI-less development sandbox had no PostGIS, so spatial queries could not be tested.

## Constraints
Location is coarse (~1 km) and used only for a max-distance hard filter (Bible §10.6 step 1).

## Options considered
1. PostGIS `geography(Point)` + GiST index.
2. Two `DECIMAL(.,2)` columns (≈1.1 km granularity) with a bounding-box prefilter and haversine in SQL.

## Decision
Option 2 for now: `location_lat`/`location_lng` rounded to 2 dp at write time. Bounding box uses a
btree index; haversine refines. Docker compose and CI already ship `postgis/postgis:16`, so switching is a
single migration + selector change.

## Rejected alternatives and why
Option 1 now: untestable in the current environment; no accuracy benefit at 1 km granularity.

## Trade-offs and risks
Slightly slower at 100k+ profiles for wide radii; no spatial operators.

## Revisit if
MC-055 query plans at 100k synthetic profiles miss the p95 target, or a feature needs true geodesic ops.
