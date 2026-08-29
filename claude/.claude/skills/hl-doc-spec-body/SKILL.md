---
name: hl-doc-spec-body
description: >-
  Write or rewrite the Spec (consolidated spec body) section of a homelab
  spec note: subsection shape, terms to use, and the decision-log boundary.
  Used by hl-spec-init (initial write) and hl-spec-sync (rewrite to current
  truth) — not meant to be invoked on its own.
---

# Doc Spec Body (homelab) → shape of the Spec section

The shared rules for what `## Spec` is allowed to say, regardless of whether
it is being written for the first time (`hl-spec-init`) or rewritten to
current truth (`hl-spec-sync`). Both skills invoke this instead of restating
these rules.

## Language

Write in English. No PM audience, no reason to keep a translation
convention.

## Subsections

See `hl-doc-spec-schema` for the full template. What each one holds:

- **Goal / Motivation** — one or two sentences: what this unlocks, why now.
- **Components touched** — which compose service(s) get added or changed,
  which Caddy routes or Tailscale nodes are involved. Name real service
  names from `compose.yaml`, not invented ones.
- **Config & secrets** — new or changed env vars (and whether they need a
  `.env.example` entry), ports, volumes.
- **Data model / storage** — what gets persisted, where (bind mount vs
  named volume), and its shape if structured (e.g. a new SQLite table, a
  JSON file schema). Use `[MISSING]` for any value the source (the issue)
  does not state.
- **Operational concerns** — restart policy, resource limits, whether
  `restic` backup coverage needs to extend to a new path, health/monitoring.
- **Verification steps** — concrete and runnable: how you'll actually
  confirm this works (a curl against a healthcheck, a log line to grep for,
  a manual click-through). This is infra, not a test suite — no
  Precondition/Action/Expected-Result table.

## Terms to use

- **Show**: real compose service names, real env var names, real ports,
  real paths under the repo.
- **Avoid**: code-level implementation detail that belongs in the diff, not
  the spec — no line-by-line plan, no library choice (that's a Decision Log
  entry if it's worth recording at all).

## Decision-log boundary

If a decision is really about *how* to implement something — a library
choice, a code pattern, the shape of a Caddy directive — put it in the
Decision Log, not in `## Spec`. `## Spec` states the intended end state; the
Decision Log states why you got there.

## Formatting

Prefer short bullets over prose paragraphs. If a subsection has nothing to
say yet (e.g. no new secrets), write `- none` rather than omitting the
heading — an omitted heading reads as "forgot to check," not "checked, N/A."
