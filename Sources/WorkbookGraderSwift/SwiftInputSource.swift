//  SwiftInputSource.swift — Layer 2. Binds the language-neutral contract to the
//  `swift-property-based` engine, and nothing more.
//
//  This file and Corpus+SwiftGrading.swift are the only ones a Swift port would
//  throw away. `WorkbookGraderCore` (the pedagogy) stays; a fast-check port
//  writes its own binding here.

import PropertyBased
// Re-export the contract so downstream code imports one module and writes
// `Property`, `Corpus`, `Grade` unqualified.
@_exported import WorkbookGraderCore

/// Adapts an engine `Generator` (a.k.a. `Gen`) plus a seeded `Xoshiro` into the
/// core `InputSource`. The seed makes every grade reproducible: the same
/// submission always meets the same inputs, so a counterexample a reader sees is
/// the one they can reproduce.
public struct SwiftInputSource<Value, Shrink: SendableSequenceType>: InputSource {
    /// A fixed, arbitrary default seed. Grading is deterministic by default;
    /// pass a different seed to vary the input sample.
    public static var defaultSeed: UInt64 { 0xB00C_5EED_1DEA_0FF5 }

    private let generator: Generator<Value, Shrink>
    private let shrinker: (Value) -> [Value]
    private var rng: Xoshiro

    /// - Parameter shrink: how to simplify a failing input before showing it to
    ///   the reader. Defaults to no shrinking, which reports the first failure
    ///   as-is. Pass one of `Shrinkers`' strategies to get minimal
    ///   counterexamples — see `Shrinkers.array` / `Shrinkers.integer`.
    ///
    ///   The engine has its own shrinker, but it is `internal` and driven only by
    ///   `propertyCheck`, which reports through Swift Testing rather than
    ///   returning a result. A grader has to *return* a counterexample, so it
    ///   reduces the input itself through the Core contract.
    public init(
        _ generator: Generator<Value, Shrink>,
        seed: UInt64 = Self.defaultSeed,
        shrink: @escaping (Value) -> [Value] = { _ in [] }
    ) {
        self.generator = generator
        self.shrinker = shrink
        self.rng = Self.seededRNG(seed)
    }

    /// Draws the next input from the generator, advancing the seeded RNG.
    public mutating func next() -> Value {
        generator.run(using: &rng)
    }

    /// Simpler inputs for a failing one, from the `shrink` strategy given at init.
    public func shrinkCandidates(from input: Value) -> [Value] {
        shrinker(input)
    }

    /// A Xoshiro seeded from a single word: SplitMix64 disperses the seed into
    /// Xoshiro's 4-word state, so a small seed like `1` still gives a well-mixed
    /// starting state (a mostly-zero tuple would generate poorly).
    private static func seededRNG(_ seed: UInt64) -> Xoshiro {
        var state = seed
        func nextWord() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
        return Xoshiro(seed: (nextWord(), nextWord(), nextWord(), nextWord()))
    }
}
