//  Defect.swift — one buggy variant of a kernel; part of the grading contract.

/// One buggy variant of a kernel, plus the prose that explains it — the text a
/// reader sees when their property fails to detect it.
public struct Defect<Subject> {
    /// Stable identifier, e.g. `"rle.drops-singletons"`.
    public let id: String
    /// One line describing the injected bug — the "…and why" in the undetected
    /// feedback. Never leaked until the grade is rendered.
    public let explanation: String
    /// The buggy implementation the property should break on.
    public let subject: Subject

    /// A defect with its identifier, explanation and buggy subject.
    public init(id: String, explanation: String, subject: Subject) {
        self.id = id
        self.explanation = explanation
        self.subject = subject
    }
}
