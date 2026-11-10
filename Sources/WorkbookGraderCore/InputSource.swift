//  InputSource.swift — the language-neutral grading contract.
//
//  The contract is this protocol plus `Property`, `Defect` and `Corpus`, one
//  file each.
//
//  Everything a grade needs, and nothing about any particular PBT engine:
//  a *source of inputs*, a *property*, and a *defect corpus*. A future port to
//  fast-check or Hypothesis reimplements the substrate behind `InputSource`;
//  the contract does not change. (planning/workbook-portability.md — "the grader
//  is a language-neutral contract".)

/// A stream of inputs to try a property against.
///
/// The Swift binding wraps an engine `Gen` + a seeded RNG in this protocol; a
/// port wraps whatever its own generators are. The core never sees either.
public protocol InputSource {
    /// The type of value the source produces and the property is checked on.
    associatedtype Input

    /// The next generated input. Called `count` times per grade.
    mutating func next() -> Input

    /// Simpler inputs derived from a failing one, simplest first.
    ///
    /// The grader uses this to reduce a counterexample to its essence before
    /// showing it to the reader: a random failure like `[2, 3, 3, 1, 2, 0]`
    /// teaches far less than the `[1, 0]` it shrinks to, because the shrunk
    /// version contains only the structure the bug actually needs.
    ///
    /// Returning `[]` — the default — disables shrinking and reports the first
    /// failing input as-is. Candidates must be strictly *simpler* than `input`
    /// (shorter, or closer to zero) or the reduction will not terminate; the
    /// grader caps the work regardless.
    func shrinkCandidates(from input: Input) -> [Input]
}

public extension InputSource {
    /// Default: no shrinking. A source that can't reduce its inputs still grades
    /// correctly — it just shows the first failure it found.
    func shrinkCandidates(from _: Input) -> [Input] { [] }
}
