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
            referenceCounterexample = String(describing: input)
            break
        }

        var detected: [DetectedDefect] = []
        var undetected: [UndetectedDefect] = []
        for defect in defects {
            var trigger: String?
            for input in inputs where !property.holds(input, defect.subject) {
                trigger = String(describing: input)
                break
            }
            if let trigger {
                detected.append(DetectedDefect(id: defect.id,
                                               explanation: defect.explanation,
                                               counterexample: trigger))
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
}
