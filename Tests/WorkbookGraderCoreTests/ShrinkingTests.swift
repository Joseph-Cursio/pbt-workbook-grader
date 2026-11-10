//  ShrinkingTests.swift — counterexamples reduce to their essence, engine-free.

import Testing
@testable import WorkbookGraderCore

/// A source that shrinks — the same stand-in, now able to reduce a failure.
private struct ShrinkingListSource: InputSource {
    var values: [[Int]]
    var index = 0

    mutating func next() -> [Int] {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
    func shrinkCandidates(from input: [Int]) -> [[Int]] {
        Shrinkers.array(input, element: Shrinkers.integer)
    }
}

private struct ListSubject { let apply: ([Int]) -> [Int] }

@Suite("Shrinking — counterexamples reduce to their essence")
struct ShrinkingTests {

    /// The bug needs a zero *somewhere*; everything around it is noise.
    private func zeroHatingCorpus() -> Corpus<ListSubject> {
        Corpus(
            name: "identity",
            reference: ListSubject { $0 },
            defects: [
                Defect(
                    id: "mangles-zero", explanation: "maps 0 to 1",
                    subject: ListSubject { $0.map { $0 == 0 ? 1 : $0 } }
                ),
            ]
        )
    }

    @Test("a detected defect reports the shrunk input, not the one that happened to fail")
    func detectionShrinks() {
        let property = Property<[Int], ListSubject>("f(x) == x") { input, subject in
            subject.apply(input) == input
        }
        // The failing draw is noisy; only the 0 matters.
        var source = ShrinkingListSource(values: [[7, 3, 0, 9, 4]])
        let grade = zeroHatingCorpus().grade(with: property, drawing: &source, count: 1)

        #expect(grade.detected.count == 1)
        #expect(grade.detected[0].counterexample == "[0]")
    }

    @Test("without a shrinker the first failing input is reported unchanged")
    func defaultIsNoShrink() {
        let property = Property<[Int], ListSubject>("f(x) == x") { input, subject in
            subject.apply(input) == input
        }
        var source = ListSource(values: [[7, 3, 0, 9, 4]])
        let grade = zeroHatingCorpus().grade(with: property, drawing: &source, count: 1)

        #expect(grade.detected[0].counterexample == "[7, 3, 0, 9, 4]")
    }

    @Test("an over-strong property's rejected input is shrunk too")
    func referenceCounterexampleShrinks() {
        // Rejects any list containing a zero — including valid ones.
        let property = Property<[Int], ListSubject>("no zeroes") { input, _ in
            !input.contains(0)
        }
        var source = ShrinkingListSource(values: [[7, 3, 0, 9, 4]])
        let grade = zeroHatingCorpus().grade(with: property, drawing: &source, count: 1)

        #expect(!grade.referenceHeld)
        #expect(grade.referenceCounterexample == "[0]")
    }

    @Test("integer shrinking reaches zero by halving, not by counting down")
    func integerShrinksFast() {
        let reduced = reduceInteger(10_000) { $0 >= 4_096 }
        #expect(reduced == 4_096)
    }

    /// Drives `Corpus.reduce` over plain integers via a minimal source.
    private func reduceInteger(_ start: Int, stillFails: (Int) -> Bool) -> Int {
        struct IntSource: InputSource {
            mutating func next() -> Int { 0 }
            func shrinkCandidates(from input: Int) -> [Int] { Shrinkers.integer(input) }
        }
        return Corpus<Int>.reduce(start, using: IntSource(), stillFails: stillFails)
    }

    @Test("shrinking terminates on a property that always fails")
    func alwaysFailingTerminates() {
        let property = Property<[Int], ListSubject>("never holds") { _, _ in false }
        var source = ShrinkingListSource(values: [[5, 5, 5, 5, 5]])
        let grade = zeroHatingCorpus().grade(with: property, drawing: &source, count: 1)
        // Reduces all the way to the empty list and stops there.
        #expect(grade.referenceCounterexample == "[]")
    }
}
