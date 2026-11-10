//  Grade.swift — the behavioral result of running a property against a corpus.
//
//  The grade is not a score against an answer key; it is a *behavioral* report:
//  which defects your property detected, which went undetected, and — for the
//  detections — the smallest input that did it. (planning/workbook-positioning-
//  spec.md — "the grade is behavioral: you detected 7/9 defects, here are the two
//  that went undetected and why".)

/// A defect your property caught, with the input that exposed it.
public struct DetectedDefect {
    /// The defect's stable identifier, e.g. `"rle.drops-singletons"`.
    public let id: String
    /// One line describing the injected bug.
    public let explanation: String
    /// A rendering of the falsifying input — the reproduction the reader reads.
    public let counterexample: String

    /// A detection record for one defect and the input that exposed it.
    public init(id: String, explanation: String, counterexample: String) {
        self.id = id
        self.explanation = explanation
        self.counterexample = counterexample
    }
}

/// A defect your property missed — the teaching moment.
public struct UndetectedDefect {
    /// The defect's stable identifier, e.g. `"rle.drops-singletons"`.
    public let id: String
    /// One line describing the injected bug — the "why" the reader is shown.
    public let explanation: String

    /// A record of one defect the property missed.
    public init(id: String, explanation: String) {
        self.id = id
        self.explanation = explanation
    }
}

/// The outcome of grading one property against one corpus: whether it held on
/// the reference, and which defects it detected and missed.
public struct Grade {
    /// The name of the corpus that was graded against.
    public let corpusName: String
    /// The name of the reader's property.
    public let propertyName: String

    /// Did the property hold on the *correct* implementation? A `false` here
    /// means the property is over-strong (it rejects correct code) — a
    /// different failure from a weak one, and reported first.
    public let referenceHeld: Bool
    /// If the reference failed, the input that broke it.
    public let referenceCounterexample: String?

    /// The defects the property broke on, each with its counterexample.
    public let detected: [DetectedDefect]
    /// The defects the property held on, so would still ship.
    public let undetected: [UndetectedDefect]
    /// How many inputs were drawn and tried against every subject.
    public let sampleCount: Int

    /// A grade assembled from the runner's results.
    public init(
        corpusName: String,
        propertyName: String,
        referenceHeld: Bool,
        referenceCounterexample: String?,
        detected: [DetectedDefect],
        undetected: [UndetectedDefect],
        sampleCount: Int
    ) {
        self.corpusName = corpusName
        self.propertyName = propertyName
        self.referenceHeld = referenceHeld
        self.referenceCounterexample = referenceCounterexample
        self.detected = detected
        self.undetected = undetected
        self.sampleCount = sampleCount
    }

    /// The number of defects in the corpus, detected or not.
    public var defectsTotal: Int { detected.count + undetected.count }

    /// Detection rate in `0...1`. An empty corpus rates 1 (nothing to detect)
    /// — the honest answer for a negative Capstone rep, not a bug.
    public var detectionRate: Double {
        defectsTotal == 0 ? 1 : Double(detected.count) / Double(defectsTotal)
    }

    /// The property passes only if it holds on the reference *and* detects every
    /// defect. An over-strong property (fails the reference) never passes, no
    /// matter how many defects it "detects".
    public var passed: Bool {
        referenceHeld && undetected.isEmpty && defectsTotal > 0
    }

    /// Where a property sits on the strength ratchet — the axis the workbook
    /// grades *beyond* pass/fail (planning/workbook-contracts-and-strength.md).
    /// A property can be *true* yet weak: it holds on correct code but lets some
    /// defects go undetected. Strength is how much of the corpus it
    /// characterizes.
    public enum Strength {
        /// Fails on the correct implementation — rejects valid code.
        case overStrong
        /// Holds, but the corpus has no defects to distinguish (a negative/honest
        /// rep — the trap is "detecting" a defect that isn't there).
        case noDefects
        /// Holds and never fails — detects nothing. Not yet refutable.
        case nonRefutable
        /// Holds and detects some, but some defects go undetected.
        case weak
        /// Holds and detects every defect — a characterizing property.
        case characterizing
    }

    /// This grade's place on the strength ratchet.
    public var strength: Strength {
        if !referenceHeld { return .overStrong }
        if defectsTotal == 0 { return .noDefects }
        if detected.isEmpty { return .nonRefutable }
        if undetected.isEmpty { return .characterizing }
        return .weak
    }

    /// The ratchet as one sentence — "true but weak, N undetected" and kin.
    public var strengthHeadline: String {
        switch strength {
        case .overStrong:
            return "over-strong — it rejects correct code"

        case .noDefects:
            return "no defects here — nothing to distinguish (an honest-silence rep)"

        case .nonRefutable:
            return "not yet refutable — it holds, but detects nothing"

        case .weak:
            let unit = undetected.count == 1 ? "defect" : "defects"
            return "true but weak — detected \(detected.count) of \(defectsTotal); "
                 + "\(undetected.count) \(unit) undetected"

        case .characterizing:
            return "characterizing — every defect detected; none went undetected"
        }
    }

    /// The reader-facing feedback string — the pedagogical payload. Leads with
    /// the strength verdict so the reader grades the *ratchet*, not a binary.
    public func render() -> String {
        var out = ""
        out += "\(corpusName) — property “\(propertyName)”\n"

        guard referenceHeld else {
            out += "  ✗ \(strengthHeadline).\n"
            if let referenceCounterexample {
                out += "    It rejects a valid input: \(referenceCounterexample)\n"
            }
            out += "    Loosen it before worrying about defects — a property that "
            out += "fails on correct code can't grade anything.\n"
            return out
        }

        let settled = strength == .characterizing || strength == .noDefects
        out += "  \(settled ? "✓" : "✗") \(strengthHeadline)"
        out += " (over \(sampleCount) inputs).\n"

        if !detected.isEmpty {
            out += "  detected:\n"
            for hit in detected {
                out += "      \(hit.id) — \(hit.explanation)\n"
                out += "        first caught on: \(hit.counterexample)\n"
            }
        }

        if !undetected.isEmpty {
            out += "  undetected (defects your property would still ship):\n"
            for miss in undetected {
                out += "      \(miss.id) — \(miss.explanation)\n"
            }
            out += "    Strengthen the law until none go undetected — that's the "
            out += "ratchet from a property that's merely true to one that characterizes.\n"
        }
        return out
    }
}
