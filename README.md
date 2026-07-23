# pbt-workbook-grader

The shared grader machinery for **Properties, Worked** — the auto-graded
property-based-testing exercise lab. It runs a reader's property against a
corpus of planted defects and reports a *behavioral* grade: which defects the
property detected, which went undetected, and how strong the property is.

This package is **infrastructure, not answer key** — it carries no defects. The
private grading corpora live in the consumers. That separation is why this repo
can be public (per the book's `workbook-repo-topology.md`).

## Products

| Product | Role |
|---|---|
| **`WorkbookGraderCore`** | The language-neutral contract: *a source of inputs + a property + a defect corpus → a grade*. No engine, no test framework. A language port reimplements only the binding, never this. |
| **`WorkbookGraderSwift`** | The Swift binding — wraps a `swift-property-based` `Gen` + seeded `Xoshiro` as a Core `InputSource`, and re-exports the contract. |

## What a grade reports

- **detection** — which planted defects the property caught, each with the
  smallest falsifying input.
- **undetected** — defects the property would still ship.
- **strength** — where the property sits on the ratchet: over-strong /
  non-refutable / weak / characterizing. A property can be *true* yet weak.

> The standard mutation-testing term for this is "kill/survive"; the lab uses
> "detect/undetected" instead — same idea, gentler vocabulary.

## Consumers

- `pbt-workbook` (private) — the full paid lab + its secret corpus.
- `pbt-workbook-sampler` (public) — the free Warm-up + Set 1 slice.

Both depend on this package, pinned by version, so the grader has one source of
truth. The engine (`swift-property-based`, 1.2.x) is pinned here and inherited.

## License

MIT — see [`LICENSE`](LICENSE). This package is infrastructure: the runner, the
schema, and the scoring. It carries no defect corpora, so it stays public and
permissively licensed, and the public sampler that depends on it is usable end
to end.
