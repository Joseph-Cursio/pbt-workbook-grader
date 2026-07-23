//  GraderTests.swift — proves the language-neutral core with NO engine at all.
//
//  If these pass importing only WorkbookGraderCore, the pedagogy is genuinely
//  substrate-free — the portability claim, checked.

import Testing
@testable import WorkbookGraderCore

/// A trivial input source over a fixed list — the stand-in for "an engine's
/// generator" that a language port would replace.
private struct ListSource<Element>: InputSource {
    var values: [Element]
    var index = 0
    mutating func next() -> Element {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}

/// Subjects are plain closures here — the core doesn't care what a subject is.
private struct Doubler { let apply: (Int) -> Int }

@Suite("Core grader — engine-free")
struct GraderTests {

    private func doublingCorpus() -> Corpus<Doubler> {
        Corpus(
            name: "double",
            reference: Doubler { $0 * 2 },
            defects: [
                Defect(id: "off-by-one", explanation: "returns 2x+1",
                       subject: Doubler { $0 * 2 + 1 }),
                Defect(id: "identity", explanation: "returns x",
                       subject: Doubler { $0 })
            ]
        )
    }

    @Test("a correct property detects every defect and passes")
    func correctPropertyPasses() {
        let corpus = doublingCorpus()
        let property = Property<Int, Doubler>("f(x) == x + x") { input, subject in
            subject.apply(input) == input + input
        }
        var source = ListSource(values: [1, 2, 3, 4, 5])
        let grade = corpus.grade(with: property, drawing: &source, count: 20)

        #expect(grade.referenceHeld)
        #expect(grade.undetected.isEmpty)
        #expect(grade.detected.count == 2)
        #expect(grade.passed)
        #expect(grade.detectionRate == 1.0)
    }

    @Test("a non-refutable property leaves every defect undetected")
    func trivialPropertyLeavesDefectsUndetected() {
        let corpus = doublingCorpus()
        let property = Property<Int, Doubler>("true") { _, _ in true }
        var source = ListSource(values: [1, 2, 3])
        let grade = corpus.grade(with: property, drawing: &source, count: 10)

        #expect(grade.referenceHeld)
        #expect(grade.detected.isEmpty)
        #expect(grade.undetected.count == 2)
        #expect(!grade.passed)
        #expect(grade.detectionRate == 0.0)
    }

    @Test("an over-strong property is reported against the reference, not passed")
    func overStrongPropertyFailsReference() {
        let corpus = doublingCorpus()
        // Rejects correct code: claims f(x) == x (false for the reference).
        let property = Property<Int, Doubler>("f(x) == x") { input, subject in
            subject.apply(input) == input
        }
        var source = ListSource(values: [1, 2, 3])
        let grade = corpus.grade(with: property, drawing: &source, count: 10)

        #expect(!grade.referenceHeld)
        #expect(grade.referenceCounterexample != nil)
        #expect(!grade.passed)
        #expect(grade.render().contains("over-strong"))
    }

    @Test("strength classifies the ratchet: over-strong / non-refutable / weak / characterizing")
    func strengthClassification() {
        let corpus = doublingCorpus()
        var source = ListSource(values: [1, 2, 3])

        // Characterizing — detects the whole corpus.
        let full = Property<Int, Doubler>("f(x) == 2x") { $1.apply($0) == $0 * 2 }
        #expect(corpus.grade(with: full, drawing: &source, count: 9).strength == .characterizing)

        // Non-refutable — holds, detects nothing.
        var trivialSource = ListSource(values: [1, 2, 3])
        let trivial = Property<Int, Doubler>("true") { _, _ in true }
        #expect(corpus.grade(with: trivial, drawing: &trivialSource, count: 9).strength == .nonRefutable)

        // Weak — detects the identity defect (result != input) but not off-by-one.
        var weakSource = ListSource(values: [1, 2, 3])
        let weak = Property<Int, Doubler>("f(x) != x") { $1.apply($0) != $0 }
        let weakGrade = corpus.grade(with: weak, drawing: &weakSource, count: 9)
        #expect(weakGrade.strength == .weak)
        #expect(weakGrade.strengthHeadline.contains("true but weak"))

        // Over-strong — fails on the reference.
        var overStrongSource = ListSource(values: [1, 2, 3])
        let overStrong = Property<Int, Doubler>("f(x) == x") { $1.apply($0) == $0 }
        #expect(corpus.grade(with: overStrong, drawing: &overStrongSource, count: 9).strength == .overStrong)
    }

    @Test("detected defects carry a reproducing counterexample")
    func detectionsRecordCounterexample() {
        let corpus = doublingCorpus()
        let property = Property<Int, Doubler>("f(x) == 2x") { input, subject in
            subject.apply(input) == input * 2
        }
        var source = ListSource(values: [7])
        let grade = corpus.grade(with: property, drawing: &source, count: 3)
        #expect(grade.detected.allSatisfy { $0.counterexample == "7" })
    }
}

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
                Defect(id: "mangles-zero", explanation: "maps 0 to 1",
                       subject: ListSubject { $0.map { $0 == 0 ? 1 : $0 } })
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
        let reduced = Grader_reduce(10_000) { $0 >= 4_096 }
        #expect(reduced == 4_096)
    }

    /// Drives `Corpus.reduce` over plain integers via a minimal source.
    private func Grader_reduce(_ start: Int, stillFails: (Int) -> Bool) -> Int {
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
