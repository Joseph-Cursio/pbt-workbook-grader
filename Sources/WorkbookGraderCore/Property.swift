//  Property.swift — the law a reader authors; part of the grading contract.

/// A candidate law the reader authored: does it hold for this input against
/// this subject?
///
/// `Subject` is the code under test — the reference implementation during the
/// sanity check, then each defect in turn. A round-trip law, for example, is
/// `{ input, codec in codec.decode(codec.encode(input)) == input }`; the grader
/// swaps `codec` for the reference and every defect.
public struct Property<Input, Subject> {
    /// The law's name, shown at the head of the grade.
    public let name: String
    /// Whether the law holds for one input against one subject.
    public let holds: (Input, Subject) -> Bool

    /// A law with a display name and its check.
    public init(
        _ name: String = "property",
        holds: @escaping (Input, Subject) -> Bool
    ) {
        self.name = name
        self.holds = holds
    }
}
