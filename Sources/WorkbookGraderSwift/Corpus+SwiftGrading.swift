//  Corpus+SwiftGrading.swift — grading through the `swift-property-based` engine.
//
//  Part of Layer 2 with SwiftInputSource.swift: the convenience a Swift reader
//  calls, built on the language-neutral runner in WorkbookGraderCore.

import PropertyBased
import WorkbookGraderCore

public extension Corpus {
    /// Grade a property against this corpus using an engine generator — the
    /// convenience the reader-facing loop calls. Deterministic given the seed.
    func grade<Value, Shrink: SendableSequenceType>(
        with property: Property<Value, Subject>,
        using generator: Generator<Value, Shrink>,
        count: Int = 200,
        seed: UInt64 = SwiftInputSource<Value, Shrink>.defaultSeed,
        shrink: @escaping (Value) -> [Value] = { _ in [] }
    ) -> Grade {
        var source = SwiftInputSource(generator, seed: seed, shrink: shrink)
        return grade(with: property, drawing: &source, count: count)
    }
}
