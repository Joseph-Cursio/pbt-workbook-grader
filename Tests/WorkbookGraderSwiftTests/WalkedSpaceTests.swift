//  WalkedSpaceTests.swift — what a *walked* input space does to a grade, and
//  the first tests over the engine binding.
//
//  These pin the measurements behind pbt-book's
//  planning/workbook-enumeration-assessment.md, which asks whether the grader
//  should take its inputs from an enumerated space (SwiftPropertyLaws'
//  `Enumeration` / `Every`) as well as from a sampled generator.
//
//  The finding they exist to protect: `Grade.strength` reports `.weak` for two
//  different causes — the reader's property really is weak, or the generator
//  never drew an input that exposes the defect — and says the first. Over a
//  walked space the second cause is impossible by construction, so the verdict
//  becomes decidable.
//
//  No test here depends on a distribution. The defect densities are brute-forced
//  against the whole space so they cannot drift, and the one test that touches
//  sampling asserts only that the outcome *varies with the seed*, never a rate.

import Testing
import PropertyBased
@testable import WorkbookGraderSwift

// MARK: - A corpus in the shape of a workbook exercise

private struct Run: Equatable { let value: Int; let count: Int }

private struct Codec {
    let encode: ([Int]) -> [Run]
    let decode: ([Run]) -> [Int]
}

private func correctEncode(_ xs: [Int]) -> [Run] {
    var out: [Run] = []
    for x in xs {
        if let last = out.last, last.value == x {
            out[out.count - 1] = Run(value: x, count: last.count + 1)
        } else {
            out.append(Run(value: x, count: 1))
        }
    }
    return out
}

private func correctDecode(_ runs: [Run]) -> [Int] {
    runs.flatMap { Array(repeating: $0.value, count: $0.count) }
}

/// Three defects spanning three orders of density — the point of the fixture is
/// that the rarest one is the one sampling cannot be trusted to find.
private func rleCorpus() -> Corpus<Codec> {
    Corpus(
        name: "run-length encoding",
        reference: Codec(encode: correctEncode, decode: correctDecode),
        defects: [
            Defect(id: "rle.drops-trailing-singleton",
                   explanation: "a final run of length 1 is dropped by the encoder",
                   subject: Codec(encode: { xs in
                       var runs = correctEncode(xs)
                       if let last = runs.last, last.count == 1 { runs.removeLast() }
                       return runs
                   }, decode: correctDecode)),
            Defect(id: "rle.miscounts-run-of-three",
                   explanation: "a run of exactly 3 encodes as a count of 2",
                   subject: Codec(encode: { xs in
                       correctEncode(xs).map {
                           $0.count == 3 ? Run(value: $0.value, count: 2) : $0
                       }
                   }, decode: correctDecode)),
            Defect(id: "rle.miscounts-run-of-five",
                   explanation: "a run of exactly 5 encodes as a count of 4",
                   subject: Codec(encode: { xs in
                       correctEncode(xs).map {
                           $0.count == 5 ? Run(value: $0.value, count: 4) : $0
                       }
                   }, decode: correctDecode)),
        ]
    )
}

private func roundTrip() -> Property<[Int], Codec> {
    Property("decode(encode(xs)) == xs") { xs, codec in
        codec.decode(codec.encode(xs)) == xs
    }
}

// MARK: - The space, and a source that walks it

/// Every array over `0..<alphabet` of length `0...maxLength`, smallest-first:
/// length ascending, then lexicographic within a length.
///
/// This is the ordering contract `EnumerationBucket` states in the kit —
/// contiguous runs of equal size, ascending — written out by hand so these
/// tests need no dependency on it. Everything below about minimality rests on
/// this order, which is why `theSpaceIsOrderedSmallestFirst` checks it directly.
private func everyArray(alphabet: Int, maxLength: Int) -> [[Int]] {
    var cases: [[Int]] = []
    for length in 0...maxLength {
        var total = 1
        for _ in 0..<length { total *= alphabet }
        for index in 0..<total {
            var digits: [Int] = []
            var rest = index
            for _ in 0..<length {
                digits.append(rest % alphabet)
                rest /= alphabet
            }
            cases.append(digits.reversed())
        }
    }
    return cases
}

/// The walked counterpart to `SwiftInputSource`: hands back the cases of a space
/// in order instead of drawing from a generator.
///
/// Deliberately ships no shrinker. Smallest-first ordering makes the first
/// failing case the smallest failing case, so there is nothing left to reduce —
/// which is the claim `theFirstWalkedFailureIsTheSmallestOneInTheSpace` checks
/// rather than assumes.
private struct WalkedSource: InputSource {
    let cases: [[Int]]
    var index = 0

    mutating func next() -> [Int] {
        defer { index += 1 }
        return cases[min(index, cases.count - 1)]
    }
}

// MARK: - Tests

@Suite("Walked input spaces — sampling misses what a walk decides")
struct WalkedSpaceTests {

    /// The generator the sampler ships for this exercise shape
    /// (`WorkbookExercises.Workbook.repeatyList`), narrowed to the alphabet the
    /// space below enumerates.
    private var sampledGenerator: Generator<[Int], some SendableSequenceType> {
        Gen.int(in: 0...2).array(of: 0...6)
    }

    private var space: [[Int]] { everyArray(alphabet: 3, maxLength: 6) }

    @Test("the space is 1093 cases, ordered smallest-first")
    func theSpaceIsOrderedSmallestFirst() {
        let space = space
        #expect(space.count == 1_093)          // 3^0 + 3^1 + ... + 3^6
        #expect(space.first == [])
        #expect(space.map(\.count) == space.map(\.count).sorted())
    }

    @Test("defect densities, brute-forced over the whole space so they cannot drift")
    func defectDensitiesArePinned() {
        let space = space
        let property = roundTrip()
        let triggers = rleCorpus().defects.map { defect in
            space.filter { !property.holds($0, defect.subject) }.count
        }
        // 66.7%, 21.7%, 1.37% of 1093.
        #expect(triggers == [729, 237, 15])
    }

    /// The finding the assessment leads with. Sampling is *reproducible* — the
    /// seed is fixed — but which answer it reproduces is decided by the seed an
    /// exercise author happened to pick. Measured on 2026-09-08 with engine
    /// 1.2.x: the rare defect is detected on exactly 100 of these 200 seeds, and
    /// `strength` splits 100 `characterizing` / 100 `weak`.
    ///
    /// Only the *variation* is asserted. The rate is a property of one engine's
    /// RNG and one generator's distribution, and a test that pinned it would be
    /// a test that depends on a distribution.
    @Test("the rare defect's verdict is decided by the seed, not by the property")
    func theRareDefectIsSeedDependent() {
        let corpus = rleCorpus()
        let property = roundTrip()
        var detecting: [UInt64] = []
        var missing: [UInt64] = []

        for seed in UInt64(0)..<200 {
            let grade = corpus.grade(with: property, using: sampledGenerator,
                                     count: 200, seed: seed)
            if grade.undetected.contains(where: { $0.id == "rle.miscounts-run-of-five" }) {
                missing.append(seed)
            } else {
                detecting.append(seed)
            }
        }

        #expect(!detecting.isEmpty, "no seed detected it — the fixture has drifted")
        #expect(!missing.isEmpty,
                "every seed detected it; the defect is no longer rare enough to make the point")
    }

    /// The equal-budget result: the same 200 inputs the sampled default draws,
    /// taken as the first 200 cases of the space instead.
    @Test("a walked prefix detects every defect on the sampled budget")
    func aWalkedPrefixDetectsEveryDefectAtTheSameBudget() {
        let corpus = rleCorpus()
        var source = WalkedSource(cases: Array(space.prefix(200)))
        let grade = corpus.grade(with: roundTrip(), drawing: &source, count: 200)

        #expect(grade.referenceHeld)
        #expect(grade.undetected.isEmpty)
        #expect(grade.strength == .characterizing)
    }

    @Test("the full walk detects every defect")
    func theFullWalkDetectsEveryDefect() {
        let corpus = rleCorpus()
        let space = space
        var source = WalkedSource(cases: space)
        let grade = corpus.grade(with: roundTrip(), drawing: &source, count: space.count)

        #expect(grade.referenceHeld)
        #expect(grade.strength == .characterizing)
        #expect(grade.detected.count == corpus.defects.count)
    }

    /// Minimality without a shrinker: `WalkedSource` supplies no
    /// `shrinkCandidates`, so `Grader.reduce` is a no-op and the reported
    /// counterexample is simply the first case the walk reached. That it is also
    /// the *smallest* failing case is a consequence of the ordering, checked
    /// here against a brute-force minimum rather than asserted.
    @Test("the first walked failure is the smallest failing case in the space")
    func theFirstWalkedFailureIsTheSmallestOneInTheSpace() {
        let space = space
        let property = roundTrip()

        for defect in rleCorpus().defects {
            let failing = space.filter { !property.holds($0, defect.subject) }
            let firstWalked = try! #require(failing.first)
            let smallest = try! #require(failing.map(\.count).min())
            #expect(firstWalked.count == smallest,
                    "\(defect.id): walk reported \(firstWalked), but a length-\(smallest) case also fails")
        }

        // The concrete witnesses, so a change of ordering is legible in the diff.
        var source = WalkedSource(cases: space)
        let grade = rleCorpus().grade(with: property, drawing: &source, count: space.count)
        #expect(grade.detected.map(\.counterexample)
                == ["[0]", "[0, 0, 0]", "[0, 0, 0, 0, 0]"])
    }

    /// Pins the gap, not a feature. `Grade` has denominators over *defects*
    /// (`defectsTotal`, `detectionRate`) and none over *inputs*: on a complete
    /// walk of 1 093 cases, `sampleCount` reports the draw count and nothing
    /// distinguishes it from 1 093 sampled draws that saw ~10% of the space.
    ///
    /// This is the grader's instance of the defect the kit's note names in
    /// `TrialBudget.exhaustive(10_000)` — a number that reads like coverage and
    /// is not. Slice 1 of the assessment closes it with `Grade.coverage`, and
    /// this test is expected to change when it does.
    @Test("sampleCount is a draw count, not a coverage denominator")
    func sampleCountIsADrawCountNotACoverageDenominator() {
        let space = space
        var walked = WalkedSource(cases: space)
        let walkedGrade = rleCorpus().grade(with: roundTrip(), drawing: &walked,
                                            count: space.count)
        let sampledGrade = rleCorpus().grade(with: roundTrip(), using: sampledGenerator,
                                             count: space.count, seed: 0)

        #expect(walkedGrade.sampleCount == sampledGrade.sampleCount)
        #expect(walkedGrade.sampleCount == 1_093)
    }
}
