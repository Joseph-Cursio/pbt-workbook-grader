//  ListSource.swift — an engine-free input source shared by the core suites.

@testable import WorkbookGraderCore

/// A trivial input source over a fixed list — the stand-in for "an engine's
/// generator" that a language port would replace.
struct ListSource<Element>: InputSource {
    var values: [Element]
    var index = 0

    mutating func next() -> Element {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}
