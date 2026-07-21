# pbt-workbook-grader

The shared grader machinery for **Properties, Worked** — the auto-graded
property-based-testing exercise lab. It runs a reader's property against a mutant
corpus and reports a *behavioral* grade: which mutants the property killed, which
survived, and how strong the property is.

This package is **infrastructure, not answer key** — it carries no mutants. The
private grading corpora live in the consumers. That separation is why this repo
can be public (per the book's `workbook-repo-topology.md`).

## Products

| Product | Role |
|---|---|
| **`WorkbookGraderCore`** | The language-neutral contract: *a source of inputs + a property + a mutant corpus → a grade*. No engine, no test framework. A language port reimplements only the binding, never this. |
| **`WorkbookGraderSwift`** | The Swift binding — wraps a `swift-property-based` `Gen` + seeded `Xoshiro` as a Core `InputSource`, and re-exports the contract. |

## What a grade reports

- **mutant-kill** — which buggy variants the property caught, each with the
  smallest falsifying input.
- **survivors** — bugs the property would still ship.
- **strength** — where the property sits on the ratchet: over-strong /
  non-refutable / weak / characterizing. A property can be *true* yet weak.

## Consumers

- `pbt-workbook` (private) — the full paid lab + its secret corpus.
- `pbt-workbook-sampler` (public) — the free Warm-up + Set 1 slice.

Both depend on this package, pinned by version, so the grader has one source of
truth. The engine (`swift-property-based`, 1.2.x) is pinned here and inherited.
