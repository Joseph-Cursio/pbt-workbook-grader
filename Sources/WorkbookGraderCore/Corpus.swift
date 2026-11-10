//  Corpus.swift — a kernel's reference and its defect set; part of the grading
//  contract.

/// A kernel's correct reference plus its hidden defect set — the "answer key",
/// made executable. Grading a property means: it must hold on `reference` and
/// break on every `defect`.
public struct Corpus<Subject> {
    /// The kernel's name, shown at the head of the grade.
    public let name: String
    /// The correct implementation, which the property must hold on.
    public let reference: Subject
    /// The hidden buggy variants, each of which the property should break on.
    public let defects: [Defect<Subject>]

    /// A corpus of a reference implementation and its defects.
    public init(name: String, reference: Subject, defects: [Defect<Subject>]) {
        self.name = name
        self.reference = reference
        self.defects = defects
    }
}
