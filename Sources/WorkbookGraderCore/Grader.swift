//  Grader.swift — the runner. Language-neutral; no engine, no test framework.
//
//  This is deliberately NOT built on `propertyCheck`: that function is bound to
//  Swift Testing (it requires a live test case and reports via `Issue.record`).
//  A grader must *count* detections and *return* a result, so it drives
//  generators itself through the `InputSource` contract.

extension Corpus {
    /// Grade a property against this corpus.
    ///
    /// The same `count` inputs are drawn once and reused across the reference
    /// and every defect, so the comparison is fair and — given a seeded source
    /// — reproducible. A defect is *detected* the first time the property fails
    /// on it; the reference is expected to hold over all inputs.
    public func grade<Input, Source: InputSource>(
        with property: Property<Input, Subject>,
        drawing source: inout Source,
        count: Int
    ) -> Grade where Source.Input == Input {
        precondition(count > 0, "count must be positive")

        var inputs: [Input] = []
        inputs.reserveCapacity(count)
        for _ in 0..<count { inputs.append(source.next()) }

        // Sanity gate: the property must hold on correct code.
        var referenceHeld = true
        var referenceCounterexample: String?
        for input in inputs where !property.holds(input, reference) {
            referenceHeld = false
            // Shrink here too — "your law rejects `[0]`" localizes an over-strong
            // property far faster than a six-element array does.
            let minimal = Self.reduce(input, using: source) { !property.holds($0, reference) }
            referenceCounterexample = String(describing: minimal)
            break
        }

        var detected: [DetectedDefect] = []
        var undetected: [UndetectedDefect] = []
        for defect in defects {
            var trigger: Input?
            for input in inputs where !property.holds(input, defect.subject) {
                trigger = input
                break
            }
            if let trigger {
                // Reduce before reporting: the reader should read the essence of
                // the bug, not the random input that happened to expose it.
                let minimal = Self.reduce(trigger, using: source) {
                    !property.holds($0, defect.subject)
                }
                detected.append(DetectedDefect(id: defect.id,
                                               explanation: defect.explanation,
                                               counterexample: String(describing: minimal)))
            } else {
                undetected.append(UndetectedDefect(id: defect.id, explanation: defect.explanation))
            }
        }

        return Grade(corpusName: name,
                     propertyName: property.name,
                     referenceHeld: referenceHeld,
                     referenceCounterexample: referenceCounterexample,
                     detected: detected,
                     undetected: undetected,
                     sampleCount: inputs.count)
    }

    /// Reduce a failing input to the simplest one that still fails.
    ///
    /// Greedy descent: repeatedly take the first candidate that still falsifies
    /// the property and start over from it, until no candidate does. Because
    /// `Shrinkers` yields candidates simplest-first, "first that still fails" is
    /// also the most aggressive reduction available at each step.
    ///
    /// - Note: A source with no shrinker returns no candidates, so this is a
    ///   single no-op pass and the original input is reported — the pre-shrinking
    ///   behavior, preserved exactly.
    static func reduce<Input, Source: InputSource>(
        _ input: Input,
        using source: Source,
        limit: Int = 500,
        stillFails: (Input) -> Bool
    ) -> Input where Source.Input == Input {
        var current = input
        var steps = 0

        while steps < limit {
            // `first(where:)` is lazy, so a candidate list is only materialized
            // as far as the first hit — the aggressive early reductions usually
            // mean we stop within the first few.
            guard let better = source.shrinkCandidates(from: current).first(where: stillFails)
            else { return current }
            current = better
            steps += 1
        }
        // Budget exhausted. `current` still fails — it's just not provably
        // minimal. Reporting a partially-reduced input beats hanging.
        return current
    }
}
