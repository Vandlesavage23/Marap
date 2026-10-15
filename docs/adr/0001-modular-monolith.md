# ADR-0001: Modular monolith

- Status: accepted
- Date: 2026-10-15
- Deciders: Tech lead (Bible §2.3, REJ-04)

## Problem
Choose a deployable architecture for a small team shipping a courtship app with strong consistency needs.

## Constraints
Small team; transactions spanning modules (block + cancel interests + end match); possible later extraction.

## Options considered
1. Modular monolith (one Django codebase, enforced module boundaries).
2. Microservices.

## Evaluation criteria and evidence
Team velocity, transactional simplicity, operational cost.

## Decision
Modular monolith. One image, four processes (api, ws, worker, beat). Boundaries enforced by `import-linter`:
cross-module calls only via `services.py` / `selectors.py` or domain events.

## Rejected alternatives and why
Microservices: operational overhead and distributed transactions with no v1 scale benefit.

## Trade-offs and risks
Boundary discipline relies on tooling; one deploy unit couples release cadence.

## Revisit if
A module needs independent scaling or a separate team owns it.
